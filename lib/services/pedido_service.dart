import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../models/pedido_model.dart';

class PedidoService {
  static Future<List<Pedido>> fetchPedidos() async {
    try {
      final data = await ApiService.fetchPedidos().timeout(const Duration(seconds: 60));
      return data.map((json) => Pedido.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Erro ao buscar pedidos: $e');
      return [];
    }
  }

  static Future<String> _appDirPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final appDir = Directory('${dir.path}/CDBarreiro');
    if (!appDir.existsSync()) appDir.createSync(recursive: true);
    return appDir.path;
  }

  static Future<void> writeLog(String message, BuildContext context) async {
    try {
      final appDirPath = await _appDirPath();
      final logFile = File('$appDirPath/app_logs.txt');
      final logSink = logFile.openWrite(mode: FileMode.append);
      logSink.write('[${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}] $message\n');
      await logSink.close();
    } catch (e) {
      debugPrint('Erro ao escrever log: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar log: $e')));
      }
    }
  }

  static Future<void> savePreviousPedidoIds(List<String> ids) async {
    try {
      final appDirPath = await _appDirPath();
      final file = File('$appDirPath/previous_pedido_ids.json');
      await file.writeAsString(jsonEncode(ids));
    } catch (e) {
      debugPrint('Erro ao salvar previous_pedido_ids: $e');
    }
  }

  static Future<List<String>> loadPreviousPedidoIds() async {
    try {
      final appDirPath = await _appDirPath();
      final file = File('$appDirPath/previous_pedido_ids.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return List<String>.from(jsonDecode(content));
      }
      return [];
    } catch (e) {
      debugPrint('Erro ao carregar previous_pedido_ids: $e');
      return [];
    }
  }

  static Future<List<String>> loadPrintedPedidoIds() async {
    try {
      final appDirPath = await _appDirPath();
      final file = File('$appDirPath/printed_pedido_ids.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return List<String>.from(jsonDecode(content));
      }
      return [];
    } catch (e) {
      debugPrint('Erro ao carregar printed_pedido_ids: $e');
      return [];
    }
  }

  static Future<void> savePrintedPedidoIds(List<String> ids) async {
    try {
      final appDirPath = await _appDirPath();
      final file = File('$appDirPath/printed_pedido_ids.json');
      await file.writeAsString(jsonEncode(ids));
    } catch (e) {
      debugPrint('Erro ao salvar printed_pedido_ids: $e');
    }
  }

  static Future<bool> updateStatusPedidoBarreiro(Pedido pedido, String novoStatus, BuildContext context) async {
    final scriptUrl = "https://script.google.com/macros/s/AKfycbz6zeRGzM5g-b3dxtppN7pwjZcfXhGTXk7aVtdV8TWjhnaqwjKy5N3CyjvhSc2L4RGL/exec";
    final idStr = pedido.id;
    final encodedStatus = Uri.encodeComponent(novoStatus);
    final fullUrl = "$scriptUrl?action=UpdateStatusPedidoBarreiro&id=$idStr&status=$encodedStatus";

    const validStatuses = [
      'Processando',
      'Aguardando-pgto',
      'Registrado',
      'Agendado',
      'Saiu pra Entrega',
      'Concluído',
      'Cancelado',
      'Publi',
      'Retirado',
      'Aguardando Retirada',
      '-',
      'Montando',
      'Aguardando',
      'Agendado | Registrado',
    ];

    if (!validStatuses.contains(novoStatus)) {
      await writeLog('Status inválido: $novoStatus. Status válidos: $validStatuses', context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: Status "$novoStatus" não é válido. Escolha um status válido.')),
        );
      }
      return false;
    }

    try {
      await writeLog('Enviando requisição para atualizar status: $fullUrl', context);
      final response = await http.get(Uri.parse(fullUrl));
      await writeLog('Resposta recebida: Status Code ${response.statusCode}, Body: ${response.body}', context);

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.startsWith('{') || body.startsWith('[')) {
          final respData = jsonDecode(body);
          if (respData['status'] == 'success') {
            await writeLog('Status atualizado com sucesso para $novoStatus', context);
            return true;
          } else {
            final errorMsg = respData['message'] ?? 'Erro desconhecido.';
            await writeLog('Erro na resposta do script: $errorMsg', context);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar status: $errorMsg')));
            }
            return false;
          }
        } else {
          await writeLog('Resposta não é um JSON válido: ${response.body}', context);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Resposta do servidor não é um JSON válido')));
          }
          return false;
        }
      } else {
        await writeLog('Erro HTTP: Status Code ${response.statusCode}', context);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro HTTP: ${response.statusCode}')));
        }
        return false;
      }
    } catch (e) {
      await writeLog('Erro ao fazer a chamada HTTP: $e', context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha na chamada HTTP: $e')));
      }
      return false;
    }
  }
}
