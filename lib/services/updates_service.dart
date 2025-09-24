// lib/services/updates_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// ====== MODELOS ======

class UpdateAsset {
  final String platform; // 'windows' | 'macos' | 'linux'
  final String url;
  final String? sha256; // opcional, mas recomendado
  final int? size;

  UpdateAsset({
    required this.platform,
    required this.url,
    this.sha256,
    this.size,
  });

  factory UpdateAsset.fromJson(Map<String, dynamic> j) => UpdateAsset(
        platform: (j['platform'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
        sha256: j['sha256']?.toString(),
        size: j['size'] is num ? (j['size'] as num).toInt() : null,
      );
}

class UpdateManifest {
  final String latest; // ex: "1.2.3"
  final String? notes; // release notes da última
  final Map<String, String> changelog; // { "1.2.3": "..." }
  final List<UpdateAsset> assets;

  UpdateManifest({
    required this.latest,
    required this.assets,
    this.notes,
    Map<String, String>? changelog,
  }) : changelog = changelog ?? const {};

  factory UpdateManifest.fromJson(Map<String, dynamic> j) {
    final assets = (j['assets'] as List? ?? [])
        .map((e) => UpdateAsset.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final changelogRaw = Map<String, dynamic>.from(j['changelog'] ?? {});
    final change = <String, String>{};
    for (final e in changelogRaw.entries) {
      change[e.key] = e.value?.toString() ?? '';
    }
    return UpdateManifest(
      latest: (j['latest'] ?? '').toString(),
      notes: j['notes']?.toString(),
      changelog: change,
      assets: assets,
    );
  }
}

class UpdateCheckResult {
  final String currentVersion;
  final String latestVersion;
  final bool updateAvailable;
  final String releaseNotes;
  final UpdateAsset? windowsAsset;

  UpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.updateAvailable,
    required this.releaseNotes,
    required this.windowsAsset,
  });
}

/// ====== SEMVER ======

class _SemVer implements Comparable<_SemVer> {
  final int major, minor, patch;
  const _SemVer(this.major, this.minor, this.patch);

  factory _SemVer.parse(String input) {
    final clean = input.trim();
    final only = clean.split(RegExp(r'[^0-9\.]')).first;
    final parts = only.split('.');
    int m = 0, n = 0, p2 = 0;
    if (parts.isNotEmpty) m = int.tryParse(parts[0]) ?? 0;
    if (parts.length > 1) n = int.tryParse(parts[1]) ?? 0;
    if (parts.length > 2) p2 = int.tryParse(parts[2]) ?? 0;
    return _SemVer(m, n, p2);
  }

  @override
  int compareTo(_SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}

/// ====== SERVICE ======

class UpdatesService {
  /// URL fixa do manifest hospedado no GitHub (raw.githubusercontent).
  static const String defaultManifestUrl =
      'https://raw.githubusercontent.com/trajanoo93/sistema-erp-barreiro/main/updates/manifest.json';

  final String manifestUrl;
  const UpdatesService({this.manifestUrl = defaultManifestUrl});

  /// --------- VERSÃO INSTANCE ----------
  Future<UpdateManifest> fetchManifest({String? url}) =>
      UpdatesService._fetchManifest(url ?? manifestUrl);

  Future<bool> hasUpdateAvailable(UpdateManifest m) =>
      UpdatesService._hasUpdateAvailable(m);

  UpdateAsset? pickPlatformAsset(UpdateManifest m) =>
      UpdatesService._pickPlatformAsset(m);

  Future<File> downloadUpdateZip(
    UpdateAsset asset, {
    String? fileName,
    void Function(double progress)? onProgress,
  }) =>
      UpdatesService._downloadUpdateZip(
        asset,
        fileName: fileName,
        onProgress: onProgress,
      );

  /// --------- VERSÃO STATIC ----------
  static Future<UpdateCheckResult> checkForUpdates({String? url}) async {
    final manifest = await _fetchManifest(url ?? defaultManifestUrl);
    final current = await _getCurrentVersion();
    final latest = manifest.latest;
    final updateAvail = await _hasUpdateAvailable(manifest);
    final winAsset = _pickAssetFor('windows', manifest);
    final releaseNotes =
        manifest.notes ?? (manifest.changelog[latest] ?? '');

    return UpdateCheckResult(
      currentVersion: current,
      latestVersion: latest,
      updateAvailable: updateAvail,
      releaseNotes: releaseNotes,
      windowsAsset: winAsset,
    );
  }

  static Future<String> downloadAndPrepareWindowsUpdate({
    required UpdateAsset asset,
    required String latestVersion,
    void Function(double progress)? onProgressPercent,
  }) async {
    if (!Platform.isWindows) {
      throw 'Suportado apenas no Windows.';
    }

    final zipFile = await _downloadUpdateZip(
      asset,
      fileName: 'update_$latestVersion.zip',
      onProgress: onProgressPercent,
    );

    if ((asset.sha256 ?? '').trim().isNotEmpty) {
      final ok = await _verifySha256(zipFile, asset.sha256!.toLowerCase());
      if (!ok) throw 'SHA-256 não confere para ${zipFile.path}';
    }

    final exe = Platform.resolvedExecutable;
    final appDir = p.dirname(exe);
    final backupsDir = await _getBackupsDir();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final backupTarget = p.join(backupsDir.path, 'backup_$stamp');

    final batContent = '''
@echo off
setlocal
set APPDIR="$appDir"
set ZIPFILE="${zipFile.path}"
set BACKUPDIR="$backupTarget"

echo Criando backup em "%BACKUPDIR%"...
mkdir "%BACKUPDIR%"
xcopy "%APPDIR%\\*" "%BACKUPDIR%\\" /E /I /Y >nul

echo Extraindo pacote...
powershell -Command "Expand-Archive -Force \\"%ZIPFILE%\\" \\"%APPDIR%\\""

echo Relancando aplicacao...
start "" "${exe}"

exit
''';

    final tmpDir = await getTemporaryDirectory();
    final batPath = p.join(tmpDir.path, 'run_update_${_randId()}.bat');
    await File(batPath).writeAsString(batContent, flush: true);
    return batPath;
  }

  static Future<void> runUpdaterAndExit(String batPath) async {
    if (!Platform.isWindows) throw 'Apenas Windows.';
    await Process.start('cmd', ['/C', 'start', '', batPath],
        mode: ProcessStartMode.detached);
    await Future.delayed(const Duration(milliseconds: 300));
    exit(0);
  }

  static Future<void> openBackupsFolder() async {
    final dir = await _getBackupsDir();
    if (Platform.isWindows) {
      await Process.run('explorer', [dir.path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [dir.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [dir.path]);
    }
  }

  /// ====== IMPLEMENTAÇÃO INTERNA ======

  static Future<UpdateManifest> _fetchManifest(String url) async {
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) {
      throw 'Manifesto HTTP ${r.statusCode} em $url';
    }
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return UpdateManifest.fromJson(j);
  }

  static Future<String> _getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '0.0.0';
    }
  }

  static Future<bool> _hasUpdateAvailable(UpdateManifest m) async {
    final current = _SemVer.parse(await _getCurrentVersion());
    final latest = _SemVer.parse(m.latest);
    return latest.compareTo(current) > 0;
  }

  static UpdateAsset? _pickPlatformAsset(UpdateManifest m) {
    if (Platform.isWindows) return _pickAssetFor('windows', m);
    if (Platform.isMacOS) return _pickAssetFor('macos', m);
    if (Platform.isLinux) return _pickAssetFor('linux', m);
    return null;
  }

  static UpdateAsset? _pickAssetFor(String platform, UpdateManifest m) {
    final pLower = platform.toLowerCase();
    try {
      return m.assets.firstWhere((a) => a.platform.toLowerCase() == pLower);
    } catch (_) {
      return null;
    }
  }

  static Future<File> _downloadUpdateZip(
    UpdateAsset asset, {
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    final resp =
        await http.Client().send(http.Request('GET', Uri.parse(asset.url)));
    if (resp.statusCode != 200) {
      throw 'Falha ao baixar: HTTP ${resp.statusCode}';
    }

    final tmp = await getTemporaryDirectory();
    final name = (fileName?.trim().isNotEmpty ?? false)
        ? fileName!.trim()
        : p.basename(Uri.parse(asset.url).path);
    final outPath = p.join(tmp.path, name);
    final out = File(outPath).openWrite();

    final total = resp.contentLength ?? asset.size ?? 0;
    int downloaded = 0;

    await for (final chunk in resp.stream) {
      out.add(chunk);
      downloaded += chunk.length;
      if (total > 0 && onProgress != null) {
        onProgress(downloaded / total);
      }
    }
    await out.flush();
    await out.close();
    return File(outPath);
  }

  static Future<bool> _verifySha256(File file, String expectedLowerHex) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString() == expectedLowerHex;
  }

  static Future<Directory> _getBackupsDir() async {
    final base = await getApplicationSupportDirectory();
    final backups = Directory(p.join(base.path, 'backups'));
    if (!await backups.exists()) await backups.create(recursive: true);
    return backups;
  }

  static String _randId() {
    final r = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
