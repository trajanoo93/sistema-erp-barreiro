// lib/services/gas_api.dart
// Cliente HTTP para o seu Google Apps Script (GAS) Web App.
// 100% completo: leitura (CD Barreiro, com filtro de não-impressos),
// marcação de impressão (MarkPrintedBarreiro) e desmarcação (UnmarkPrintedBarreiro).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// >>> ATENÇÃO <<<
/// 1) Depois de publicar o seu Apps Script como "Web app",
///    cole aqui a URL de implantação *terminando em /exec*.
/// 2) Ex.: https://script.google.com/macros/s/AKfycbx.../exec
const String kGAppsBaseUrl = String.fromEnvironment(
  'GAS_BASE_URL',
  defaultValue: 'https://script.google.com/macros/s/AKfycbzqN8mU9Jf1lUmO_CT7IyqhMBT-vp99FyJ24RxIXP1dpCQMx5iu-e_YV27q9gOASDlY/exec',
);

/// Modelo do Pedido (campos conforme ReadCDBarreiro do Apps Script)
class Pedido {
  final String? id;
  final String? data; // pode vir como "dd/MM" ou ISO, depende da sua planilha
  final String? horario;
  final String? bairro;
  final String? nome;
  final String? pagamento;
  final num? subTotal;
  final num? total;
  final String? vendedor;
  final num? taxaEntrega;
  final String? status;
  final String? entregador;
  final String? rua;
  final String? numero;
  final String? cep;
  final String? complemento;
  final String? latitude;
  final String? longitude;
  final String? unidade;
  final String? hifen; // campo '-' vindo da planilha (evite usar se possível)
  final String? cidade;

  /// Coluna V (printed_at) – string ISO ou vazio
  final DateTime? printedAt;

  final String? tipoEntrega;
  final String? dataAgendamento;
  final String? horarioAgendamento;
  final String? telefone;
  final String? observacao;
  final String? produtos;
  final String? rastreio;

  /// Campos de cupom/gift card
  final String? cupomNome; // AG
  final num? cupomPercentual; // AH
  final num? giftDesconto; // AI

  Pedido({
    this.id,
    this.data,
    this.horario,
    this.bairro,
    this.nome,
    this.pagamento,
    this.subTotal,
    this.total,
    this.vendedor,
    this.taxaEntrega,
    this.status,
    this.entregador,
    this.rua,
    this.numero,
    this.cep,
    this.complemento,
    this.latitude,
    this.longitude,
    this.unidade,
    this.hifen,
    this.cidade,
    this.printedAt,
    this.tipoEntrega,
    this.dataAgendamento,
    this.horarioAgendamento,
    this.telefone,
    this.observacao,
    this.produtos,
    this.rastreio,
    this.cupomNome,
    this.cupomPercentual,
    this.giftDesconto,
  });

  factory Pedido.fromJson(Map<String, dynamic> json) {
    DateTime? parsePrinted(dynamic v) {
      if (v == null) return null;
      if (v is String && v.trim().isEmpty) return null;
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {
          return null;
        }
      }
      // Se vier número/Date serializado estranho, tente converter
      return null;
    }

    num? _toNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v;
      final asStr = v.toString().replaceAll(',', '.');
      return num.tryParse(asStr);
    }

    return Pedido(
      id: json['id']?.toString(),
      data: json['data']?.toString(),
      horario: json['horario']?.toString(),
      bairro: json['bairro']?.toString(),
      nome: json['nome']?.toString(),
      pagamento: json['pagamento']?.toString(),
      subTotal: _toNum(json['subTotal']),
      total: _toNum(json['total']),
      vendedor: json['vendedor']?.toString(),
      taxaEntrega: _toNum(json['taxa_entrega']),
      status: json['status']?.toString(),
      entregador: json['entregador']?.toString(),
      rua: json['rua']?.toString(),
      numero: json['numero']?.toString(),
      cep: json['cep']?.toString(),
      complemento: json['complemento']?.toString(),
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      unidade: json['unidade']?.toString(),
      hifen: json['-']?.toString(),
      cidade: json['cidade']?.toString(),
      printedAt: parsePrinted(json['printed_at']),
      tipoEntrega: json['tipo_entrega']?.toString(),
      dataAgendamento: json['data_agendamento']?.toString(),
      horarioAgendamento: json['horario_agendamento']?.toString(),
      telefone: json['telefone']?.toString(),
      observacao: json['observacao']?.toString(),
      produtos: json['produtos']?.toString(),
      rastreio: json['rastreio']?.toString(),
      cupomNome: json['AG']?.toString(),
      cupomPercentual: _toNum(json['AH']),
      giftDesconto: _toNum(json['AI']),
    );
  }

  bool get estaImpresso => printedAt != null;
}

/// Exceção específica para respostas do GAS (erro sem rede)
class GasResponseException implements Exception {
  final int? statusCode;
  final String message;
  GasResponseException(this.message, {this.statusCode});

  @override
  String toString() => 'GasResponseException($statusCode): $message';
}

/// Cliente principal
class GasApi {
  final String baseUrl;
  final http.Client _client;

  GasApi({String? baseUrl, http.Client? client})
      : baseUrl = (baseUrl ?? kGAppsBaseUrl).trim(),
        _client = client ?? http.Client();

  /// Monta uma URI com action e parâmetros.
  Uri _buildUri(String action, Map<String, String> params) {
    final uri = Uri.parse(baseUrl);
    // preserva query existente e acrescenta os novos parâmetros
    final mergedQuery = Map<String, String>.from(uri.queryParameters)
      ..addAll({'action': action})
      ..addAll(params);
    return uri.replace(queryParameters: mergedQuery);
    // Obs.: Apps Script aceita GET sem CORS para Flutter mobile/desktop.
    // Para Flutter Web, evite POST (preflight) e mantenha GET.
  }

  /// Faz GET e retorna um Map/List já decodificado.
  Future<dynamic> _get(String action, Map<String, String> params) async {
    final uri = _buildUri(action, params);
    if (kDebugMode) {
      // ignore: avoid_print
      print('[GAS] GET $uri');
    }

    late http.Response resp;
    try {
      resp = await _client
          .get(uri, headers: {HttpHeaders.acceptHeader: 'application/json'})
          .timeout(const Duration(seconds: 20));
    } on SocketException {
      throw GasResponseException('Sem conexão com a internet');
    } on HttpException {
      throw GasResponseException('Erro HTTP ao contatar o Web App');
    } on FormatException {
      throw GasResponseException('Resposta inválida do servidor');
    }

    if (resp.statusCode != 200) {
      throw GasResponseException(
        'HTTP ${resp.statusCode}: ${resp.reasonPhrase ?? 'Erro'}',
        statusCode: resp.statusCode,
      );
    }

    // Pode vir um array [] ou um objeto {status:..., message:...}
    final body = resp.body.trim();
    if (body.isEmpty) return null;
    final decoded = jsonDecode(body);
    // Se o Apps Script mandar {status:'error', message:'...'}
    if (decoded is Map &&
        decoded['status'] != null &&
        decoded['status'].toString().toLowerCase() == 'error') {
      throw GasResponseException(decoded['message']?.toString() ?? 'Erro');
    }
    return decoded;
  }

  /// Lê a aba "CD Barreiro".
  /// Se [onlyUnprinted] = true, o Apps Script filtra os que ainda não foram impressos (printed_at vazio).
  Future<List<Pedido>> readCDBarreiro({bool onlyUnprinted = false}) async {
    final decoded = await _get('ReadCDBarreiro', {
      'only_unprinted': onlyUnprinted.toString(),
    });

    if (decoded is List) {
      return decoded
          .map((e) => Pedido.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw GasResponseException('Formato inesperado em ReadCDBarreiro');
    }
  }

  /// Marca um pedido como impresso (coluna V recebe timestamp).
  Future<void> markPrintedBarreiro(String id) async {
    final decoded = await _get('MarkPrintedBarreiro', {'id': id});
    // Esperado: {status:'success', id:'...', printed_at:'...'}
    if (decoded is Map &&
        decoded['status']?.toString().toLowerCase() == 'success') {
      return;
    }
    throw GasResponseException(
      'Falha ao marcar impresso: ${decoded.toString()}',
    );
  }

  /// Desmarca (limpa coluna V).
  Future<void> unmarkPrintedBarreiro(String id) async {
    final decoded = await _get('UnmarkPrintedBarreiro', {'id': id});
    if (decoded is Map &&
        decoded['status']?.toString().toLowerCase() == 'success') {
      return;
    }
    throw GasResponseException(
      'Falha ao desmarcar impresso: ${decoded.toString()}',
    );
  }

  /// Exemplo extra: atribuir entregador (já existe no seu GAS)
  Future<void> assignDelivery({
    required String id,
    required String entregador,
  }) async {
    final decoded =
        await _get('AssignDelivery', {'id': id, 'entregador': entregador});
    if (decoded is Map &&
        decoded['status']?.toString().toLowerCase() == 'success') {
      return;
    }
    throw GasResponseException(
      'Falha ao atribuir entregador: ${decoded.toString()}',
    );
  }

  /// Exemplo extra: remover entregador (colunas K/L viram "-")
  Future<void> removeEntregador(String id) async {
    final decoded = await _get('RemoveEntregador', {'id': id});
    if (decoded is Map &&
        decoded['status']?.toString().toLowerCase() == 'success') {
      return;
    }
    throw GasResponseException(
      'Falha ao remover entregador: ${decoded.toString()}',
    );
  }

  void dispose() {
    _client.close();
  }
}
