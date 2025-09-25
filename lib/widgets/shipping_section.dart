import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:erp_painel/models/pedido_state.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ShippingSection extends StatefulWidget {
  final String cep;
  final Function(String, String) onStoreUpdated;
  final Function(String) onShippingMethodUpdated;
  final Function(double) onShippingCostUpdated;
  final PedidoState pedido;
  final Function() onSchedulingChanged;
  final Future<void> Function(PedidoState)? savePersistedData;

  const ShippingSection({
    Key? key,
    required this.cep,
    required this.onStoreUpdated,
    required this.onShippingMethodUpdated,
    required this.onShippingCostUpdated,
    required this.pedido,
    required this.onSchedulingChanged,
    this.savePersistedData,
  }) : super(key: key);

  @override
  State<ShippingSection> createState() => _ShippingSectionState();
}

class _ShippingSectionState extends State<ShippingSection> {
  String _shippingMethod = 'delivery';
  final primaryColor = const Color(0xFFF28C38);

  Future<void> logToFile(String message) async {
    // desativado
  }

  @override
  void initState() {
    super.initState();
    _shippingMethod = widget.pedido.shippingMethod.isNotEmpty ? widget.pedido.shippingMethod : 'delivery';
    if (_shippingMethod == 'pickup') {
      widget.pedido.shippingCost = 0.0;
      widget.pedido.shippingCostController.text = '0.00';
      widget.pedido.storeFinal = 'Unidade Barreiro';
      widget.pedido.pickupStoreId = '110727';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onShippingMethodUpdated(_shippingMethod);
        widget.onStoreUpdated(widget.pedido.storeFinal, widget.pedido.pickupStoreId);
        widget.onShippingCostUpdated(widget.pedido.shippingCost);
        _fetchStoreDecision(widget.cep);
        logToFile('initState: shippingMethod=$_shippingMethod, storeFinal=${widget.pedido.storeFinal}, pickupStoreId=${widget.pedido.pickupStoreId}, shippingCost=${widget.pedido.shippingCost}');
      }
    });
  }

  @override
  void didUpdateWidget(ShippingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cep != widget.cep || oldWidget.pedido.storeFinal != widget.pedido.storeFinal) {
      setState(() {
        _shippingMethod = widget.pedido.shippingMethod.isNotEmpty ? widget.pedido.shippingMethod : 'delivery';
        if (_shippingMethod == 'pickup') {
          widget.pedido.storeFinal = 'Unidade Barreiro';
          widget.pedido.pickupStoreId = '110727';
          widget.pedido.shippingCost = 0.0;
          widget.pedido.shippingCostController.text = '0.00';
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onStoreUpdated(widget.pedido.storeFinal, widget.pedido.pickupStoreId);
          widget.onShippingCostUpdated(widget.pedido.shippingCost);
          _fetchStoreDecision(widget.cep);
          logToFile('didUpdateWidget: cep=${widget.cep}, storeFinal=${widget.pedido.storeFinal}, pickupStoreId=${widget.pedido.pickupStoreId}, shippingCost=${widget.pedido.shippingCost}');
        }
      });
    }
  }

  Future<void> _fetchStoreDecision(String cep) async {
    await logToFile('Buscando decisão de loja para CEP: $cep, Método de entrega: $_shippingMethod');
    if (_shippingMethod == 'pickup') {
      setState(() {
        widget.pedido.storeFinal = 'Unidade Barreiro';
        widget.pedido.pickupStoreId = '110727';
        widget.pedido.shippingCost = 0.0;
        widget.pedido.shippingCostController.text = '0.00';
      });
      widget.onShippingCostUpdated(0.0);
      widget.onStoreUpdated('Unidade Barreiro', '110727');
      widget.pedido.notifyListeners();
      await logToFile('Modo pickup: Definido storeFinal=Unidade Barreiro, pickupStoreId=110727, shippingCost=0.0');
      widget.savePersistedData?.call(widget.pedido);
      return;
    }

    if (cep.length != 8) {
      await logToFile('CEP incompleto, redefinindo loja e custo.');
      setState(() {
        widget.pedido.storeFinal = '';
        widget.pedido.pickupStoreId = '';
        widget.pedido.availablePaymentMethods = [];
        widget.pedido.paymentAccounts = {'stripe': 'stripe', 'pagarme': 'central'};
        widget.pedido.shippingCost = 0.0;
        widget.pedido.shippingCostController.text = '0.00';
      });
      widget.onShippingCostUpdated(0.0);
      widget.onStoreUpdated('', '');
      widget.pedido.notifyListeners();
      widget.savePersistedData?.call(widget.pedido);
      return;
    }

    try {
      final normalizedDate = widget.pedido.schedulingDate.isEmpty
          ? DateFormat('yyyy-MM-dd').format(DateTime.now())
          : widget.pedido.schedulingDate;
      final requestBody = {
        'cep': cep,
        'shipping_method': _shippingMethod,
        'pickup_store': _shippingMethod == 'pickup' ? 'Unidade Barreiro' : '',
        'delivery_date': _shippingMethod == 'delivery' ? normalizedDate : '',
        'pickup_date': _shippingMethod == 'pickup' ? normalizedDate : '',
      };
      await logToFile('Enviando requisição para endpoint store-decision: ${jsonEncode(requestBody)}');
      final storeResponse = await http.post(
        Uri.parse('https://aogosto.com.br/delivery/wp-json/custom/v1/store-decision'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception('Timeout ao buscar opções de entrega');
      });

      await logToFile('Resposta store-decision: status=${storeResponse.statusCode}, body=${storeResponse.body}');

      double shippingCost = 0.0;
      if (_shippingMethod == 'delivery') {
        await logToFile('Buscando custo de frete para CEP: $cep');
        final costResponse = await http.get(
          Uri.parse('https://aogosto.com.br/delivery/wp-json/custom/v1/shipping-cost?cep=$cep'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 15), onTimeout: () {
          throw Exception('Timeout ao buscar custo de frete');
        });

        await logToFile('Resposta custo de frete: status=${costResponse.statusCode}, body=${costResponse.body}');

        if (costResponse.statusCode == 200) {
          final costData = jsonDecode(costResponse.body);
          if (costData['status'] == 'success' && costData['shipping_options'] != null && costData['shipping_options'].isNotEmpty) {
            shippingCost = double.tryParse(costData['shipping_options'][0]['cost']?.toString() ?? '0.0') ?? 0.0;
          } else {
            await logToFile('Nenhuma opção de frete válida retornada para CEP: $cep');
            shippingCost = 0.0;
          }
        } else {
          throw Exception('Erro ao buscar custo de frete: ${costResponse.statusCode} - ${costResponse.body}');
        }
      }

      if (storeResponse.statusCode == 200) {
        final storeDecision = jsonDecode(storeResponse.body);
        setState(() {
          widget.pedido.storeFinal = _shippingMethod == 'pickup' ? 'Unidade Barreiro' : (storeDecision['effective_store_final']?.toString() ?? storeDecision['store_final']?.toString() ?? '');
          widget.pedido.pickupStoreId = _shippingMethod == 'pickup' ? '110727' : (storeDecision['pickup_store_id']?.toString() ?? '');
          final rawPaymentMethods = List<Map>.from(storeDecision['payment_methods'] ?? []);
          widget.pedido.availablePaymentMethods = [];
          final seenTitles = <String>{};
          for (var m in rawPaymentMethods) {
            final id = m['id']?.toString() ?? '';
            final title = m['title']?.toString() ?? '';
            if (id == 'woo_payment_on_delivery' && !seenTitles.contains('Dinheiro na Entrega')) {
              widget.pedido.availablePaymentMethods.add({'id': 'cod', 'title': 'Dinheiro na Entrega'});
              seenTitles.add('Dinheiro na Entrega');
            } else if ((id == 'stripe' || id == 'stripe_cc' || id == 'eh_stripe_pay') &&
                !seenTitles.contains('Cartão de Crédito On-line')) {
              widget.pedido.availablePaymentMethods.add({
                'id': storeDecision['payment_accounts']['stripe'] ?? 'stripe',
                'title': 'Cartão de Crédito On-line'
              });
              seenTitles.add('Cartão de Crédito On-line');
            } else if (!seenTitles.contains(title)) {
              widget.pedido.availablePaymentMethods.add({'id': id, 'title': title});
              seenTitles.add(title);
            }
          }
          final paymentAccounts = storeDecision['payment_accounts'] as Map? ?? {'stripe': 'stripe', 'pagarme': 'central'};
          widget.pedido.paymentAccounts = paymentAccounts.map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''));
          if (!widget.pedido.availablePaymentMethods.any((m) => m['id'] == _paymentSlugFromLabel(widget.pedido.selectedPaymentMethod))) {
            widget.pedido.selectedPaymentMethod = widget.pedido.availablePaymentMethods.isNotEmpty
                ? widget.pedido.availablePaymentMethods.first['title'] ?? ''
                : '';
          }
          widget.pedido.shippingCost = _shippingMethod == 'pickup' ? 0.0 : shippingCost;
          widget.pedido.shippingCostController.text = widget.pedido.shippingCost.toStringAsFixed(2);
        });

        await logToFile('Estado atualizado: storeFinal=${widget.pedido.storeFinal}, pickupStoreId=${widget.pedido.pickupStoreId}, Payment Methods: ${widget.pedido.availablePaymentMethods}, Payment Accounts: ${widget.pedido.paymentAccounts}, Shipping Cost: ${widget.pedido.shippingCost}');

        widget.onStoreUpdated(widget.pedido.storeFinal, widget.pedido.pickupStoreId);
        widget.onShippingCostUpdated(widget.pedido.shippingCost);
        widget.pedido.notifyListeners();
        widget.savePersistedData?.call(widget.pedido);
      } else {
        throw Exception('Erro ao buscar opções de entrega: ${storeResponse.statusCode} - ${storeResponse.body}');
      }
    } catch (error, stackTrace) {
      await logToFile('Erro ao buscar decisão de loja: $error, StackTrace: $stackTrace');
      setState(() {
        widget.pedido.storeFinal = '';
        widget.pedido.pickupStoreId = '';
        widget.pedido.availablePaymentMethods = [
          {'id': 'pagarme_custom_pix', 'title': 'Pix'},
          {'id': 'stripe', 'title': 'Cartão de Crédito On-line'},
          {'id': 'cod', 'title': 'Dinheiro na Entrega'},
          {'id': 'custom_729b8aa9fc227ff', 'title': 'Cartão na Entrega'},
          {'id': 'custom_e876f567c151864', 'title': 'Vale Alimentação'},
        ];
        widget.pedido.paymentAccounts = {'stripe': 'stripe', 'pagarme': 'central'};
        widget.pedido.shippingCost = 0.0;
        widget.pedido.shippingCostController.text = '0.00';
      });
      widget.onStoreUpdated('', '');
      widget.onShippingCostUpdated(0.0);
      widget.pedido.notifyListeners();
      widget.savePersistedData?.call(widget.pedido);
    }
  }

  String _paymentSlugFromLabel(String uiLabel) {
    final n = uiLabel.toLowerCase().trim();
    if (n.contains('pix')) return 'pagarme_custom_pix';
    if (n.contains('cartao de credito on-line') ||
        n.contains('cartao de credito online') ||
        n == 'cartao de credito' ||
        n.contains('stripe')) {
      return widget.pedido.paymentAccounts['stripe'] ?? 'stripe';
    }
    if (n.contains('dinheiro')) return 'cod';
    if (n.contains('cartao na entrega') ||
        n.contains('cartao de debito ou credito') ||
        n.contains('maquininha') ||
        n.contains('pos')) return 'custom_729b8aa9fc227ff';
    if (n.contains('vale alimentacao') || n == 'va') return 'custom_e876f567c151864';
    return 'cod';
  }

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              'Método de Entrega',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              value: _shippingMethod,
              decoration: InputDecoration(
                labelText: 'Método de Entrega',
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
                prefixIcon: Icon(Icons.local_shipping, color: primaryColor),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
              items: [
                DropdownMenuItem(value: 'delivery', child: Text('Delivery', style: GoogleFonts.poppins(fontSize: 14))),
                DropdownMenuItem(value: 'pickup', child: Text('Retirada na Unidade Barreiro', style: GoogleFonts.poppins(fontSize: 14))),
              ],
              onChanged: (value) {
                if (value != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _shippingMethod = value;
                        if (_shippingMethod == 'pickup') {
                          widget.pedido.storeFinal = 'Unidade Barreiro';
                          widget.pedido.pickupStoreId = '110727';
                          widget.pedido.shippingCost = 0.0;
                          widget.pedido.shippingCostController.text = '0.00';
                        } else {
                          widget.pedido.storeFinal = '';
                          widget.pedido.pickupStoreId = '';
                          widget.pedido.shippingCost = 0.0;
                          widget.pedido.shippingCostController.text = '0.00';
                        }
                      });
                      widget.onShippingMethodUpdated(_shippingMethod);
                      widget.onStoreUpdated(widget.pedido.storeFinal, widget.pedido.pickupStoreId);
                      widget.onShippingCostUpdated(widget.pedido.shippingCost);
                      widget.pedido.notifyListeners();
                      logToFile('Método de entrega alterado para $_shippingMethod, storeFinal=${widget.pedido.storeFinal}, pickupStoreId=${widget.pedido.pickupStoreId}, shippingCost=${widget.pedido.shippingCost}');
                      widget.savePersistedData?.call(widget.pedido);
                    }
                  });
                }
              },
              validator: (value) => value == null ? 'Por favor, selecione o método de entrega' : null,
            ),
          ),
          if (_shippingMethod == 'pickup') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border(left: BorderSide(color: primaryColor, width: 4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.store, color: primaryColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Retirada na loja: Unidade Barreiro',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
}