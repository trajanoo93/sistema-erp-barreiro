import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show Printer, Printing;
import '../models/pedido_model.dart';
import '../services/gas_api.dart' as gas;

/// Dialog/Screen de detalhes do pedido + impressão
class PedidoDetailDialog extends StatelessWidget {
  final dynamic pedido; // normalmente é um Map<String, dynamic>
  final List<Map<String, String>> produtosParsed;

  /// API do GAS (com alias para evitar conflito de nomes)
  final gas.GasApi _gas = gas.GasApi();

  PedidoDetailDialog({
    Key? key,
    required this.pedido,
    required this.produtosParsed,
  }) : super(key: key);

  // Mapeia nomes de pagamento para exibição
  static const Map<String, String> _paymentDisplayMap = {
    'Crédito Site': 'Pago! (Cartão de Crédito)',
    'Pix': 'Pago! (Pix)',
  };

  // Mapeia tipo de entrega
  static const Map<String, String> _deliveryDisplayMap = {
    'delivery': 'Delivery',
    'pickup': 'Retirada na Loja',
  };

  String formatPaymentMethod(String? payment) {
    final p = (payment ?? '').trim();
    return _paymentDisplayMap[p] ?? p;
  }

  // Formata telefone brasileiro vindo em string longa (ex.: 55DDDNnnnnnn)
  String formatPhoneNumber(String phone) {
    final onlyDigits = phone.replaceAll(RegExp(r'\D'), '');
    // tenta formato 13 dígitos: 55 + DDD(2) + 9####-####
    if (onlyDigits.length >= 13) {
      final ddd = onlyDigits.substring(2, 4);
      final numberPart1 = onlyDigits.substring(4, 9);
      final numberPart2 = onlyDigits.substring(9, 13);
      return '($ddd) $numberPart1-$numberPart2';
    }
    return phone;
  }

  String formatDate(String? date) {
    if (date == null || date.trim().isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(date);
      return DateFormat('dd/MM').format(dt);
    } catch (_) {
      return date;
    }
  }

  String formatAgendamentoDate(String? date) {
    if (date == null || date.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(date);
      return DateFormat('dd/MM').format(dt);
    } catch (_) {
      return date;
    }
  }

  // Conversor robusto para double
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll('.', '').replaceAll(',', '.'); // tenta pt-BR
    return double.tryParse(s) ?? double.tryParse(v.toString()) ?? 0.0;
  }

  // Formata como moeda BR
  String _formatCurrency(dynamic v) {
    final d = _toDouble(v);
    return d.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final rua = (pedido['rua'] ?? '').toString();
    final numero = (pedido['numero'] ?? '').toString();
    final complemento = (pedido['complemento'] ?? '').toString();
    final bairro = (pedido['bairro'] ?? '').toString();
    final cidade = (pedido['cidade'] ?? '').toString();
    final cep = (pedido['cep'] ?? '').toString().trim();

    final enderecoCompleto = [
      if (rua.isNotEmpty) rua,
      if (numero.isNotEmpty) numero,
      if (complemento.isNotEmpty) complemento,
      if (bairro.isNotEmpty) bairro,
      if (cidade.isNotEmpty) cidade,
      if (cep.isNotEmpty) 'CEP: $cep',
      if (cep.isEmpty) 'CEP: N/A',
    ].join(', ');

    final telefoneFormatado = formatPhoneNumber((pedido['telefone'] ?? '').toString());
    final dataCriacaoFormatada = formatDate(pedido['data']?.toString());
    final pagamentoFormatado = formatPaymentMethod(pedido['pagamento']?.toString());
    final observacao = (pedido['observacao'] ?? '').toString().trim();
    final tipoEntrega = pedido['tipo_entrega']?.toString().toLowerCase();

    // Precisamos do modelo para ler descontoGiftCard
    final pedidoObj = Pedido.fromJson(Map<String, dynamic>.from(pedido));

    // Descontos (cupom e gift card)
double totalDesconto = 0.0;
String? descontoLabel;

final subTotalVal = _toDouble(pedido['subTotal']);
final cupomCodigo = pedido['AG']?.toString();
final cupomValor = _toDouble(pedido['AH']); // pode ser % ou valor fixo
final cupomTipo = pedido['AI']?.toString(); // "percent" ou "fixed_cart"

if (cupomCodigo != null && cupomCodigo.isNotEmpty && cupomValor > 0) {
  if (cupomTipo == 'percent') {
    // desconto percentual
    totalDesconto += subTotalVal * (cupomValor / 100.0);
    descontoLabel = 'Cupom ($cupomCodigo - ${cupomValor.toStringAsFixed(0)}%)';
  } else {
    // desconto fixo
    totalDesconto += cupomValor;
    descontoLabel = 'Cupom ($cupomCodigo - R\$ ${cupomValor.toStringAsFixed(2)})';
  }
}

// Gift Card (se vier negativo no backend, tratamos como desconto)
final giftCardDesconto = pedidoObj.descontoGiftCard;
if (giftCardDesconto != null && giftCardDesconto < 0) {
  totalDesconto += giftCardDesconto.abs();
  descontoLabel = (descontoLabel == null)
      ? 'Cartão Presente'
      : '$descontoLabel + Cartão Presente';
}


    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pedido #${pedido['id'] ?? 'N/A'}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade600, Colors.orange.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Ícone aparece SEMPRE; a função já bloqueia a impressão fora do Windows com um snackbar
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            tooltip: 'Imprimir',
            onPressed: () async {
              await printDirectly(context, pedido, produtosParsed); // manual => não marca no Sheets
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Detalhes do pedido
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Detalhes do Pedido',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                  const SizedBox(height: 12),
                  _buildDetailRow('Data de Criação', dataCriacaoFormatada),
                  _buildDetailRow('Cliente', (pedido['nome'] ?? 'N/A').toString().toUpperCase()),
                  _buildDetailRow('Telefone', telefoneFormatado),
                  _buildDetailRow('Pagamento', pagamentoFormatado),
                  _buildDetailRow('Endereço', enderecoCompleto.isNotEmpty ? enderecoCompleto : 'N/A'),
                  _buildDetailRow('Agendamento',
                      '${pedido['data_agendamento'] ?? ''} - ${pedido['horario_agendamento'] ?? ''}'),
                  _buildDetailRow('Tipo de Entrega', _deliveryDisplayMap[tipoEntrega] ?? (tipoEntrega ?? 'N/A')),
                  if (totalDesconto > 0)
                    _buildDetailRow('Desconto aplicado (${descontoLabel ?? ''})',
                        '-R\$ ${totalDesconto.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.green)),
                  if (observacao.isNotEmpty) _buildDetailRow('Observação', observacao),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            // Produtos
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Produtos',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                  const SizedBox(height: 8),
                  _buildProdutosTable(produtosParsed),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            // Totais
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade50, Colors.orange.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Subtotal: R\$ ${_formatCurrency(pedido['subTotal'])}',
                      style: const TextStyle(fontSize: 14, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text('Taxa de Entrega: R\$ ${_formatCurrency(pedido['taxa_entrega'])}',
                      style: const TextStyle(fontSize: 14, color: Colors.black87)),
                  if (totalDesconto > 0) ...[
                    const SizedBox(height: 4),
                    Text('Desconto Total: -R\$ ${totalDesconto.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, color: Colors.green)),
                  ],
                  const SizedBox(height: 8),
                  Text('Total: R\$ ${_formatCurrency(pedido['total'])}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox.shrink(),
        Text('$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
        Expanded(
          child: Text(value, style: style ?? TextStyle(fontSize: 14, color: Colors.black87.withOpacity(0.8))),
        ),
      ]),
    );
  }

  Widget _buildProdutosTable(List<Map<String, String>> produtos) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade200),
      columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1)},
      children: [
        TableRow(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.orange.shade100, Colors.orange.shade50]),
          ),
          children: const [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Produto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Qtd', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            ),
          ],
        ),
        ...produtos.asMap().entries.map((entry) {
          final index = entry.key;
          final produto = entry.value;
          return TableRow(
            decoration: BoxDecoration(color: index % 2 == 0 ? Colors.white : Colors.grey.shade50),
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(produto['nome'] ?? '',
                    style: TextStyle(fontSize: 14, color: Colors.black87.withOpacity(0.8))),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(produto['qtd'] ?? '',
                    style: TextStyle(fontSize: 14, color: Colors.black87.withOpacity(0.8))),
              ),
            ],
          );
        }),
      ],
    );
  }

  /// Envia o PDF direto pra impressora (Windows).
  /// Se [markSheets] for true, **marca no Google Sheets** após imprimir.
  Future<void> printDirectly(
    BuildContext context,
    dynamic pedido,
    List<Map<String, String>> produtosParsed, {
    bool markSheets = false,
  }) async {
    // Bloqueia a impressão em plataformas que não sejam Windows
    if (!Platform.isWindows) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impressão não suportada nesta plataforma.'), duration: Duration(seconds: 3)),
      );
      return;
    }

    final pdf = pw.Document();

    // Endereço e campos
    final rua = (pedido['rua'] ?? '').toString();
    final numero = (pedido['numero'] ?? '').toString();
    final complemento = (pedido['complemento'] ?? '').toString();
    final bairro = (pedido['bairro'] ?? '').toString();
    final cidade = (pedido['cidade'] ?? '').toString();
    final cep = (pedido['cep'] ?? '').toString().trim();

    final enderecoCompleto = [
      if (rua.isNotEmpty) rua,
      if (numero.isNotEmpty) numero,
      if (complemento.isNotEmpty) complemento,
      if (bairro.isNotEmpty) bairro,
      if (cidade.isNotEmpty) cidade,
      if (cep.isNotEmpty) 'CEP: $cep',
      if (cep.isEmpty) 'CEP: N/A',
    ].join(', ');

    final telefoneFormatado = formatPhoneNumber((pedido['telefone'] ?? '').toString());
    final dataCriacaoFormatada = formatDate(pedido['data']?.toString());
    final dataAgendamentoFormatada = formatAgendamentoDate(pedido['data_agendamento']?.toString());
    final horarioAgendamento = (pedido['horario_agendamento'] ?? '').toString();
    final observacao = (pedido['observacao'] ?? '').toString().trim();
    final pagamentoFormatado = formatPaymentMethod(pedido['pagamento']?.toString());
    final entregaFormatada =
        _deliveryDisplayMap[(pedido['tipo_entrega'] ?? '').toString().toLowerCase()] ??
            (pedido['tipo_entrega'] ?? '').toString();

    const double pageWidthMm = 80.0;
    const double pageWidthPoints = pageWidthMm * PdfPageFormat.mm;

    final now = DateTime.now();
    final printDateTime = DateFormat('dd/MM/yyyy HH:mm:ss').format(now);

    final pedidoObj = Pedido.fromJson(Map<String, dynamic>.from(pedido));

    // Header (com logo se existir)
    pw.Widget headerWidget;
    try {
      final logoBytes = await rootBundle.load('assets/icon/GO-logo.png');
      final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      headerWidget = pw.Column(
        children: [
          pw.Center(child: pw.Image(logoImage, width: 50, height: 50)),
          pw.SizedBox(height: 3),
          pw.Text('Comprovante de Pedido',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 3),
          pw.Divider(thickness: 1, color: PdfColors.black),
          pw.SizedBox(height: 3),
        ],
      );
    } catch (_) {
      headerWidget = pw.Column(
        children: [
          pw.Text('Ao Gosto Carnes | Barreiro',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 3),
          pw.Text('Comprovante de Pedido',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 3),
          pw.Divider(thickness: 1, color: PdfColors.black),
          pw.SizedBox(height: 3),
        ],
      );
    }

    // Descontos (cupom + gift card)
    double totalDesconto = 0.0;
    String? descontoLabel;
    final subTotalVal = _toDouble(pedido['subTotal']);
    final ahPercent = _toDouble(pedido['AH']); // %
    if (ahPercent > 0) {
      totalDesconto += subTotalVal * (ahPercent / 100.0);
      descontoLabel = 'Cupom (${pedido['AG'] ?? 'Desconhecido'} - ${ahPercent.toStringAsFixed(0)}%)';
    }
    if (pedidoObj.descontoGiftCard != null && pedidoObj.descontoGiftCard! < 0) {
      totalDesconto += pedidoObj.descontoGiftCard!.abs();
      descontoLabel = (descontoLabel == null) ? 'Cartão Presente' : '$descontoLabel + Cartão Presente';
    }

    // Página
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          pageWidthPoints,
          PdfPageFormat.a4.height,
          marginLeft: 5 * PdfPageFormat.mm,
          marginRight: 5 * PdfPageFormat.mm,
          marginTop: 5 * PdfPageFormat.mm,
          marginBottom: 5 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              headerWidget,
              pw.Text('Pedido #${pedido['id'] ?? 'N/A'}',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text('Detalhes do Pedido', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text('Data: $dataCriacaoFormatada', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Cliente: ${(pedido['nome'] ?? 'N/A').toString().toUpperCase()}',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Telefone: $telefoneFormatado', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Pagamento: $pagamentoFormatado', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Endereço: ${enderecoCompleto.isNotEmpty ? enderecoCompleto : 'N/A'}',
                  style: const pw.TextStyle(fontSize: 8),
                  maxLines: 2),
              pw.Text('Agendamento: $dataAgendamentoFormatada - $horarioAgendamento',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Entrega: $entregaFormatada', style: const pw.TextStyle(fontSize: 8)),
              if (observacao.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text('Observação: $observacao', style: const pw.TextStyle(fontSize: 8), maxLines: 2),
              ],
              if (totalDesconto > 0) ...[
                pw.SizedBox(height: 5),
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green100,
                    borderRadius: pw.BorderRadius.circular(5),
                    border: pw.Border.all(color: PdfColors.green300, width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Descontos Aplicados',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                      if (descontoLabel != null)
                        pw.Text(
                          'Desconto aplicado ($descontoLabel): -R\$ ${totalDesconto.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                        ),
                    ],
                  ),
                ),
              ],
              pw.SizedBox(height: 5),
              pw.Text('Produtos', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1)},
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('Produto',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('Qtd',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                      ),
                    ],
                  ),
                  ...produtosParsed.map(
                    (p) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text(p['nome'] ?? '', style: const pw.TextStyle(fontSize: 7), softWrap: true),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text(p['qtd'] ?? '', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Subtotal: R\$ ${_formatCurrency(pedido['subTotal'])}', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Taxa Entrega: R\$ ${_formatCurrency(pedido['taxa_entrega'])}', style: const pw.TextStyle(fontSize: 8)),
                    if (totalDesconto > 0)
                      pw.Text('Desconto Total: -R\$ ${totalDesconto.toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.green800)),
                    pw.SizedBox(height: 2),
                    pw.Text('Total: R\$ ${_formatCurrency(pedido['total'])}',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 1, color: PdfColors.black),
              pw.SizedBox(height: 2),
              pw.Text('Impresso em: $printDateTime',
                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.black),
                  textAlign: pw.TextAlign.center),
              pw.Text('Obrigado por sua preferência!',
                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.black),
                  textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 2),
              // tentativa de "cut" (não tem efeito em PDF, mas deixei caso precise)
              pw.Text('\x1D\x56\x00', style: const pw.TextStyle(fontSize: 0)),
            ],
          );
        },
      ),
    );

    try {
      final targetPrinter = await _findPrinter();
      await Printing.directPrintPdf(
        printer: targetPrinter,
        onLayout: (_) => pdf.save(),
      );

      // feedback de UI
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impressão enviada com sucesso!'), duration: Duration(seconds: 3)),
      );

      // Marca no Sheets somente se solicitado (para a sua lógica: automático = true / manual = false)
      if (markSheets) {
        final String id = (pedido['id'] ?? '').toString().trim();
        if (id.isNotEmpty) {
          try {
            await _gas.markPrintedBarreiro(id); // não retorna bool; apenas aguardamos
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Impressão OK, mas erro ao marcar no Sheets: $e'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao imprimir: $e'), duration: const Duration(seconds: 5)),
      );
    }
  }

  pw.TableRow _buildDetailTableRow(String label, String value, {int maxLines = 1}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 8), softWrap: true, maxLines: maxLines),
        ),
      ],
    );
  }

  Future<Printer> _findPrinter() async {
    if (!Platform.isWindows) {
      throw Exception('Impressão não suportada nesta plataforma.');
    }
    final printers = await Printing.listPrinters();
    if (printers.isEmpty) {
      throw Exception('Nenhuma impressora encontrada.');
    }
    // tenta achar EPSON/TM-T20X; se não achar, usa a primeira
    final epsonPrinter = printers.firstWhere(
      (p) => p.name.toLowerCase().contains('epson') || p.name.toLowerCase().contains('tm-t20x'),
      orElse: () => printers.first,
    );
    return epsonPrinter;
  }
}
