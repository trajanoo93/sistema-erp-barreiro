// lib/pages/atualizacoes_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/updates_service.dart';

class AtualizacoesPage extends StatefulWidget {
  const AtualizacoesPage({Key? key}) : super(key: key);

  @override
  State<AtualizacoesPage> createState() => _AtualizacoesPageState();
}

class _AtualizacoesPageState extends State<AtualizacoesPage> {
  bool _loading = false;
  String _current = '—';
  String _latest = '—';
  String? _notes;
  String? _status;
  double _progress = 0;
  bool _updateAvailable = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _status = 'Verificando atualizações...';
      _progress = 0;
      _updateAvailable = false;
    });
    try {
      final res = await UpdatesService.checkForUpdates();
      setState(() {
        _current = res.currentVersion;
        _latest = res.latestVersion;
        _notes = res.releaseNotes.isEmpty ? null : res.releaseNotes;
        _updateAvailable = res.updateAvailable;
        _status = res.updateAvailable
            ? 'Atualização disponível'
            : 'Você já está na última versão.';
      });
    } catch (e) {
      setState(() {
        _status = 'Erro ao verificar: $e';
        _updateAvailable = false;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateWindows() async {
    try {
      setState(() {
        _loading = true;
        _progress = 0;
        _status = 'Baixando pacote...';
      });
      final res = await UpdatesService.checkForUpdates();
      if (res.windowsAsset == null) {
        setState(() => _status = 'Nenhum pacote do Windows disponível.');
        return;
      }
      final bat = await UpdatesService.downloadAndPrepareWindowsUpdate(
        asset: res.windowsAsset!,
        latestVersion: res.latestVersion,
        onProgressPercent: (p) => setState(() => _progress = p.clamp(0.0, 1.0)),
      );
      setState(() => _status = 'Preparando instalação...');
      await Future.delayed(const Duration(milliseconds: 500));
      await UpdatesService.runUpdaterAndExit(bat);
    } catch (e) {
      setState(() => _status = 'Falha na atualização: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ---- UI helpers
  (Color bg, Color text, IconData icon) _statusStyle() {
    final s = (_status ?? '').toLowerCase();
    if (s.contains('erro')) {
      return (const Color(0xFFFFF1F2), const Color(0xFFB91C1C), Icons.error_outline_rounded);
    }
    if (s.contains('verificando')) {
      return (const Color(0xFFEFF6FF), const Color(0xFF1D4ED8), Icons.sync_rounded);
    }
    if (s.contains('atualização disponível')) {
      return (const Color(0xFFFFFBEB), const Color(0xFF92400E), Icons.system_update_alt_rounded);
    }
    if (s.contains('última versão')) {
      return (const Color(0xFFF0FDF4), const Color(0xFF166534), Icons.verified_rounded);
    }
    return (Colors.orange.shade50, Colors.orange.shade800, Icons.info_outline_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final canUpdate = Platform.isWindows;
    final (bg, fg, ic) = _statusStyle();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Atualizações', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          if (_status != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: fg.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Icon(ic, color: fg),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_status!, style: TextStyle(color: fg, fontWeight: FontWeight.w600))),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Versões em chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(label: 'Versão atual', value: _current),
              _chip(label: 'Última versão', value: _latest),
            ],
          ),

          const SizedBox(height: 12),

          if (_notes != null) ...[
            const Text('Novidades', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12.withOpacity(0.08)),
              ),
              padding: const EdgeInsets.all(12),
              child: Text(_notes!),
            ),
          ],

          const SizedBox(height: 16),

          // Progresso
          if (_loading && _progress > 0 && _progress < 1) ...[
            LinearProgressIndicator(value: _progress, minHeight: 8),
            const SizedBox(height: 8),
            Text('${(_progress * 100).toStringAsFixed(0)}%'),
            const SizedBox(height: 8),
          ],

          // Botão primário único
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _loading
                  ? null
                  : (_updateAvailable && canUpdate ? _updateWindows : _check),
              icon: Icon(_updateAvailable && canUpdate
                  ? Icons.download_rounded
                  : Icons.refresh_rounded),
              label: Text(_updateAvailable && canUpdate
                  ? 'Baixar e instalar'
                  : 'Verificar novamente'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            ),
          ),

          if (_updateAvailable && !canUpdate) ...[
            const SizedBox(height: 8),
            const Text(
              'Atualização disponível, mas a instalação automática só está habilitada no Windows.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip({required String label, required String value}) {
    final primary = const Color(0xFFF28C38);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(color: primary, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
