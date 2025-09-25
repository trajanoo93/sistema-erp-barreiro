import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:erp_painel/models/pedido_state.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class SummarySection extends StatelessWidget {
  final double totalOriginal;
  final bool isCouponValid;
  final String couponCode;
  final double discountAmount;
  final double totalWithDiscount;
  final bool isLoading;
  final Future<void> Function() onCreateOrder;
  final PedidoState pedido;
  final String? paymentInstructions;
  final String? resultMessage;

  const SummarySection({
    Key? key,
    required this.totalOriginal,
    required this.isCouponValid,
    required this.couponCode,
    required this.discountAmount,
    required this.totalWithDiscount,
    required this.isLoading,
    required this.onCreateOrder,
    required this.pedido,
    this.paymentInstructions,
    this.resultMessage,
  }) : super(key: key);

  Future<void> logToFile(String message) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/sistema-erp-barreiro/app_logs.txt');
      await file.writeAsString('[${DateTime.now()}] $message\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Falha ao escrever log: $e');
    }
  }

  Future<void> _copyToClipboard(BuildContext context, String? text) async {
    if (text == null || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma instrução de pagamento disponível para copiar.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      await logToFile('Erro: text is null or empty in _copyToClipboard');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Instruções copiadas para a área de transferência!'),
        backgroundColor: Colors.green,
      ),
    );
    await logToFile('Texto copiado para a área de transferência: $text');
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFF28C38);
    final successColor = Colors.green.shade600;

    String? paymentText;
    bool isPix = false;
    if (paymentInstructions != null) {
      try {
        final paymentData = jsonDecode(paymentInstructions!);
        paymentText = paymentData['type'] == 'pix' ? paymentData['text'] : paymentData['url'];
        isPix = paymentData['type'] == 'pix';
        logToFile('Payment instructions parsed: type=${paymentData['type']}, text=${paymentData['text']}, url=${paymentData['url']}');
      } catch (e) {
        paymentText = paymentInstructions;
        isPix = !paymentInstructions!.contains('checkout.stripe.com');
        logToFile('Erro ao parsear paymentInstructions: $e, usando fallback: $paymentText, isPix: $isPix');
      }
    } else {
      logToFile('paymentInstructions is null in SummarySection');
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Resumo do Pedido',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            context,
            primaryColor: primaryColor,
            icon: Icons.location_on,
            label: 'Loja Selecionada',
            value: pedido.storeFinal.isNotEmpty ? '📍 ${pedido.storeFinal}' : 'Aguardando cálculo',
            valueStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            context,
            primaryColor: primaryColor,
            label: 'Total dos Produtos',
            value: 'R\$ ${totalOriginal.toStringAsFixed(2)}',
          ),
          _buildSummaryRow(
            context,
            primaryColor: primaryColor,
            label: 'Custo de Envio',
            value: 'R\$ ${pedido.shippingCost.toStringAsFixed(2)}',
          ),
          if (isCouponValid) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              context,
              primaryColor: primaryColor,
              icon: Icons.discount,
              label: 'Desconto ($couponCode)',
              value: '- R\$ ${discountAmount.toStringAsFixed(2)}',
              valueStyle: GoogleFonts.poppins(fontSize: 16, color: successColor, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 8),
          _buildSummaryRow(
            context,
            primaryColor: primaryColor,
            label: 'Total com Desconto',
            value: 'R\$ ${totalWithDiscount.toStringAsFixed(2)}',
            valueStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: pedido.availablePaymentMethods.isNotEmpty &&
                    pedido.availablePaymentMethods.any((m) => m['title'] == pedido.selectedPaymentMethod)
                ? pedido.selectedPaymentMethod
                : null,
            decoration: InputDecoration(
              labelText: 'Método de Pagamento',
              labelStyle: GoogleFonts.poppins(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              prefixIcon: Icon(Icons.payment, color: primaryColor),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            items: pedido.availablePaymentMethods.map((method) {
              return DropdownMenuItem<String>(
                value: method['title'],
                child: Text(
                  method['title'] ?? '',
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                pedido.selectedPaymentMethod = value;
                pedido.notifyListeners();
                logToFile('Método de pagamento selecionado: $value');
              }
            },
            validator: (value) => value == null ? 'Selecione um método de pagamento' : null,
            hint: Text(
              pedido.schedulingDate.isEmpty || pedido.schedulingTime.isEmpty
                  ? 'Selecione data e horário primeiro'
                  : 'Selecione o método de pagamento',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading || pedido.selectedPaymentMethod.isEmpty
                  ? null
                  : () async {
                      await onCreateOrder();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Criando pedido...',
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
                          ),
                          backgroundColor: primaryColor,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.2),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Criar Pedido',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          if (resultMessage != null) ...[
            const SizedBox(height: 16),
            AnimatedOpacity(
              opacity: resultMessage!.isNotEmpty ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: resultMessage!.contains('Erro') ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: resultMessage!.contains('Erro') ? Colors.red.shade200 : Colors.green.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      resultMessage!.contains('Erro') ? Icons.error : Icons.check_circle,
                      color: resultMessage!.contains('Erro') ? Colors.redAccent : successColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        resultMessage!,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: resultMessage!.contains('Erro') ? Colors.redAccent : Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (paymentInstructions != null && paymentText != null && paymentText.isNotEmpty) ...[
            const SizedBox(height: 16),
            AnimatedOpacity(
              opacity: paymentText!.isNotEmpty ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPix ? Icons.qr_code : Icons.credit_card,
                          color: successColor,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPix ? 'Pagamento via Pix' : 'Pagamento via Cartão de Crédito',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: successColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isPix ? 'Código Pix:' : 'Link de Pagamento:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            paymentText,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.copy, size: 20, color: primaryColor),
                          onPressed: () => _copyToClipboard(context, paymentText),
                          tooltip: isPix ? 'Copiar Código Pix' : 'Copiar Link de Pagamento',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required Color primaryColor,
    IconData? icon,
    required String label,
    required String value,
    TextStyle? valueStyle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: primaryColor, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        Flexible(
          child: Text(
            value,
            style: valueStyle ??
                GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}