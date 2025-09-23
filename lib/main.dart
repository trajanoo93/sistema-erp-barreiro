import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import 'pages/dashboard_page.dart';
import 'pages/pedidos_page.dart';
import 'pages/motoboys_page.dart';
import 'pages/atualizacoes_page.dart'; // <-- novo import
import 'widgets/sidebar_menu.dart';
import 'enums.dart';

/// Mantemos uma referência global ao arquivo travado para que o lock permaneça ativo
RandomAccessFile? _instanceLock;

/// Tenta adquirir um lock de instância única (apenas no Windows).
/// Retorna true se conseguiu o lock; false se já existe outra instância rodando.
Future<bool> _acquireSingleInstanceLock() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final appDir = Directory('${dir.path}/CDBarreiro');
    if (!appDir.existsSync()) appDir.createSync(recursive: true);

    final lockFile = File('${appDir.path}/app.lock');
    _instanceLock = await lockFile.open(mode: FileMode.write);

    try {
      // Tenta lock exclusivo; se falhar, já existe outra instância
      await _instanceLock!.lock(FileLock.exclusive);
      return true;
    } catch (_) {
      await _instanceLock?.close();
      _instanceLock = null;
      return false;
    }
  } catch (e) {
    // Se algo der errado ao tentar travar, não bloqueia a execução do app
    // (melhor deixar rodar do que falhar no start)
    debugPrint('Falha ao criar lock de instância: $e');
    return true;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    // Log de erros em tempo de execução
    print('Erro capturado: ${details.exception}, stack: ${details.stack}');
  };

  // Garante instância única no Windows (evita impressões duplicadas em caso de app aberto 2x)
  if (Platform.isWindows) {
    final ok = await _acquireSingleInstanceLock();
    if (!ok) {
      // Já existe outra instância; encerra silenciosamente
      exit(0);
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('Iniciando aplicativo com locale pt_BR'); // Log de depuração
    return MaterialApp(
      title: 'Meu Painel ERP - Barreiro',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'), // Força LTR
      theme: ThemeData(
        primarySwatch: Colors.orange,
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  MenuItem _selectedMenu = MenuItem.dashboard;

  void _onMenuItemSelected(MenuItem menuItem) {
    setState(() {
      _selectedMenu = menuItem;
    });
  }

  Widget _buildMainContent() {
    switch (_selectedMenu) {
      case MenuItem.dashboard:
        return const DashboardPage();
      case MenuItem.pedidos:
        return const PedidosPage();
      case MenuItem.motoboys:
        return const MotoboysPage();
      case MenuItem.atualizacoes:
        return const AtualizacoesPage(); // <-- nova aba
      default:
        return const DashboardPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SidebarMenu(
            selectedMenu: _selectedMenu,
            onMenuItemSelected: _onMenuItemSelected,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
    );
  }
}
