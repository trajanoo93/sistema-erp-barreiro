import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:erp_painel/models/pedido_state.dart';
import 'package:erp_painel/services/criar_pedido_service.dart';
import 'package:erp_painel/widgets/customer_section.dart';
import 'package:erp_painel/widgets/product_section.dart';
import 'package:erp_painel/widgets/address_section.dart';
import 'package:erp_painel/widgets/scheduling_section.dart';
import 'package:erp_painel/widgets/summary_section.dart';
import 'package:erp_painel/widgets/product_selection_dialog.dart';

// Normaliza data para YYYY-MM-DD
String normalizeYmd(String dateStr) {
  final s = dateStr.trim();
  if (s.isEmpty) return DateFormat('yyyy-MM-dd').format(DateTime.now());
  try {
    DateTime d;
    try {
      d = DateFormat('yyyy-MM-dd').parseStrict(s);
    } catch (_) {
      try {
        d = DateFormat('dd/MM/yyyy').parseStrict(s);
      } catch (_) {
        d = DateFormat('MMMM d, yyyy', 'en_US').parseStrict(s);
      }
    }
    return DateFormat('yyyy-MM-dd').format(d);
  } catch (_) {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }
}

// Garante sempre um intervalo "HH:mm - HH:mm" a partir de "HH:mm"
String ensureTimeRange(String time) {
  final t = time.trim();
  if (t.isEmpty) return '09:00 - 12:00';
  if (t.contains(' - ')) return t;
  final parts = t.split(':');
  if (parts.length != 2) return '09:00 - 12:00';
  final hour = int.tryParse(parts[0]) ?? 0;
  final min = int.tryParse(parts[1]) ?? 0;
  final endHour = (hour + 3).clamp(0, 23);
  final start = '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  final end = '${endHour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  return '$start - $end';
}

class CriarPedidoPage extends StatefulWidget {
  const CriarPedidoPage({Key? key}) : super(key: key);

  @override
  State<CriarPedidoPage> createState() => _CriarPedidoPageState();
}

class _CriarPedidoPageState extends State<CriarPedidoPage> {
  final primaryColor = const Color(0xFFF28C38);
  final _formKey = GlobalKey<FormState>();
  late PedidoState _pedido;
  bool _isLoading = false;
  String? _resultMessage;
  Timer? _debounce;
  late Future<void> _initFuture;

  static const List<String> _validPaymentMethods = [
    'Pix',
    'Cartão de Crédito On-line',
    'Dinheiro na Entrega',
    'Cartão na Entrega',
    'Vale Alimentação',
  ];

  @override
  void initState() {
    super.initState();
    _initFuture = _initializePedido();
  }

  Future<void> _initializePedido() async {
    _pedido = PedidoState(onCouponValidated: _onCouponValidated);
    _pedido.schedulingDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _pedido.shippingMethod = 'delivery';
    _pedido.schedulingTime = '09:00 - 12:00';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pedido.dispose();
    super.dispose();
  }

  String _normalizeLabel(String s) {
    final lower = s.toLowerCase().trim();
    return lower
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _paymentSlugFromLabel(String uiLabel) {
    final n = _normalizeLabel(uiLabel);
    if (n.contains('pix')) return 'pagarme_custom_pix';
    if (n.contains('cartao de credito on-line') ||
        n.contains('cartao de credito online') ||
        n == 'cartao de credito' ||
        n.contains('stripe')) {
      return _pedido.paymentAccounts['stripe'] ?? 'stripe';
    }
    if (n.contains('dinheiro')) {
      return 'cod';
    }
    if (n.contains('cartao na entrega') ||
        n.contains('cartao de debito ou credito') ||
        n.contains('maquininha') ||
        n.contains('pos')) {
      return 'custom_729b8aa9fc227ff';
    }
    if (n.contains('vale alimentacao') || n == 'va') {
      return 'custom_e876f567c151864';
    }
    return 'cod';
  }

  Future<void> _fetchCustomer() async {
    if (_debounce?.isActive ?? false) return;
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final phone = _pedido.phoneController.text.replaceAll(RegExp(r'\D'), '').trim();
      if (phone.length != 11) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, insira um número de telefone válido (11 dígitos com DDD)'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (mounted) setState(() => _isLoading = true);
      try {
        final service = CriarPedidoService();
        final customer = await service.fetchCustomerByPhone(phone);
        if (customer != null && mounted) {
          setState(() {
            _pedido.nameController.text = customer['first_name'] + ' ' + (customer['last_name'] ?? '');
            _pedido.emailController.text = customer['email'] ?? '';
            _pedido.cepController.text = customer['billing']['postcode'] ?? '';
            _pedido.addressController.text = customer['billing']['address_1'] ?? '';
            _pedido.numberController.text = customer['billing']['number'] ?? '';
            _pedido.complementController.text = customer['billing']['address_2'] ?? '';
            _pedido.neighborhoodController.text = customer['billing']['neighborhood'] ?? '';
            _pedido.cityController.text = customer['billing']['city'] ?? '';
          });
          final cleanCep = _pedido.cepController.text.replaceAll(RegExp(r'\D'), '');
          if (cleanCep.length == 8 && cleanCep != _pedido.lastCep) {
            _pedido.lastCep = cleanCep;
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cliente não encontrado. Preencha os dados manualmente.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao buscar cliente: $error'), backgroundColor: Colors.redAccent),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }


  Future<void> _checkStoreByCep() async {
    final cep = _pedido.cepController.text.replaceAll(RegExp(r'\D'), '').trim();
    if (cep.length != 8 && _pedido.shippingMethod != 'pickup') {
      if (mounted) {
        setState(() {
          _pedido.shippingCost = 0.0;
          _pedido.shippingCostController.text = '0.00';
          _pedido.storeFinal = '';
          _pedido.pickupStoreId = '';
          _pedido.availablePaymentMethods = [];
          _pedido.paymentAccounts = {'stripe': 'stripe', 'pagarme': 'central'};
        });
      }
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    try {
      final normalizedDate = normalizeYmd(_pedido.schedulingDate);
      final requestBody = {
        'cep': cep,
        'shipping_method': _pedido.shippingMethod,
        'pickup_store': _pedido.shippingMethod == 'pickup' ? 'Unidade Barreiro' : '',
        'delivery_date': _pedido.shippingMethod == 'delivery' ? normalizedDate : '',
        'pickup_date': _pedido.shippingMethod == 'pickup' ? normalizedDate : '',
      };
      final storeResponse = await http.post(
        Uri.parse('https://aogosto.com.br/delivery/wp-json/custom/v1/store-decision'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception('Timeout ao buscar opções de entrega');
      });
      double shippingCost = 0.0;
      if (_pedido.shippingMethod == 'delivery') {
        final costResponse = await http.get(
          Uri.parse('https://aogosto.com.br/delivery/wp-json/custom/v1/shipping-cost?cep=$cep'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 15), onTimeout: () {
          throw Exception('Timeout ao buscar custo de frete');
        });
        if (costResponse.statusCode == 200) {
          final costData = jsonDecode(costResponse.body);
          if (costData['status'] == 'success' && costData['shipping_options'] != null && costData['shipping_options'].isNotEmpty) {
            shippingCost = double.tryParse(costData['shipping_options'][0]['cost']?.toString() ?? '0.0') ?? 0.0;
          } else {
            shippingCost = 0.0;
          }
        } else {
          throw Exception('Erro ao buscar custo de frete: ${costResponse.statusCode} - ${costResponse.body}');
        }
      }
      if (storeResponse.statusCode == 200) {
        final data = jsonDecode(storeResponse.body);
        final newStoreFinal = data['effective_store_final']?.toString() ?? data['store_final']?.toString() ?? 'Unidade Barreiro';
        if (mounted) {
          setState(() {
            _pedido.storeFinal = _pedido.shippingMethod == 'pickup' ? 'Unidade Barreiro' : newStoreFinal;
            _pedido.pickupStoreId = _pedido.shippingMethod == 'pickup' ? '110727' : data['pickup_store_id']?.toString() ?? '110727';
            _pedido.shippingCost = _pedido.shippingMethod == 'pickup' ? 0.0 : shippingCost;
            _pedido.shippingCostController.text = _pedido.shippingCost.toStringAsFixed(2);
            final rawPaymentMethods = List<Map<String, dynamic>>.from(data['payment_methods'] ?? []);
            _pedido.availablePaymentMethods = [];
            final seenTitles = <String>{};
            for (var m in rawPaymentMethods) {
              final id = m['id']?.toString() ?? '';
              final title = m['title']?.toString() ?? '';
              if (id == 'woo_payment_on_delivery' && !seenTitles.contains('Dinheiro na Entrega')) {
                _pedido.availablePaymentMethods.add({'id': 'cod', 'title': 'Dinheiro na Entrega'});
                seenTitles.add('Dinheiro na Entrega');
              } else if ((id == 'stripe' || id == 'stripe_cc' || id == 'eh_stripe_pay') && !seenTitles.contains('Cartão de Crédito On-line')) {
                _pedido.availablePaymentMethods.add({
                  'id': data['payment_accounts']['stripe'] ?? 'stripe',
                  'title': 'Cartão de Crédito On-line'
                });
                seenTitles.add('Cartão de Crédito On-line');
              } else if (!seenTitles.contains(title)) {
                _pedido.availablePaymentMethods.add({'id': id, 'title': title});
                seenTitles.add(title);
              }
            }
            final paymentAccounts = (data['payment_accounts'] as Map?)?.map((key, value) => MapEntry(key.toString(), value?.toString() ?? '')) ?? {'stripe': 'stripe', 'pagarme': 'central'};
            _pedido.paymentAccounts = paymentAccounts;
            if (_pedido.selectedPaymentMethod.isNotEmpty &&
                !_pedido.availablePaymentMethods.any((m) => m['title'] == _pedido.selectedPaymentMethod)) {
              _pedido.selectedPaymentMethod = _pedido.availablePaymentMethods.isNotEmpty
                  ? _pedido.availablePaymentMethods.first['title'] ?? ''
                  : '';
            }
          });
        }
      } else {
        throw Exception('Erro ao buscar opções de entrega: ${storeResponse.statusCode} - ${storeResponse.body}');
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _pedido.shippingCost = 0.0;
          _pedido.shippingCostController.text = '0.00';
          _pedido.storeFinal = _pedido.shippingMethod == 'pickup' ? 'Unidade Barreiro' : '';
          _pedido.pickupStoreId = _pedido.shippingMethod == 'pickup' ? '110727' : '';
          _pedido.availablePaymentMethods = [
            {'id': 'pagarme_custom_pix', 'title': 'Pix'},
            {'id': 'stripe', 'title': 'Cartão de Crédito On-line'},
            {'id': 'cod', 'title': 'Dinheiro na Entrega'},
            {'id': 'custom_729b8aa9fc227ff', 'title': 'Cartão na Entrega'},
            {'id': 'custom_e876f567c151864', 'title': 'Vale Alimentação'},
          ];
          _pedido.paymentAccounts = {'stripe': 'stripe', 'pagarme': 'central'};
          if (_pedido.selectedPaymentMethod.isNotEmpty &&
              !_pedido.availablePaymentMethods.any((m) => m['title'] == _pedido.selectedPaymentMethod)) {
            _pedido.selectedPaymentMethod = _pedido.availablePaymentMethods.isNotEmpty
                ? _pedido.availablePaymentMethods.first['title'] ?? ''
                : '';
          }
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createOrder() async {
    final errors = <String>[];
    final normalizedDate = normalizeYmd(_pedido.schedulingDate);
    final normalizedTime = ensureTimeRange(_pedido.schedulingTime);
    final phone = _pedido.phoneController.text.replaceAll(RegExp(r'\D'), '').trim();
    if (phone.length != 11) errors.add('Insira um número de telefone válido (11 dígitos com DDD)');
    if (_pedido.nameController.text.isEmpty) errors.add('O nome do cliente é obrigatório');
    if (_pedido.shippingMethod == 'delivery' && _pedido.cepController.text.replaceAll(RegExp(r'\D'), '').length != 8) {
      errors.add('Digite um CEP válido (8 dígitos) para entrega');
    }
    if (_pedido.shippingMethod == 'delivery' && _pedido.addressController.text.isEmpty) {
      errors.add('O endereço é obrigatório para entrega');
    }
    if (_pedido.shippingMethod == 'delivery' && _pedido.numberController.text.isEmpty) {
      errors.add('O número do endereço é obrigatório para entrega');
    }
    if (_pedido.shippingMethod == 'delivery' && _pedido.neighborhoodController.text.isEmpty) {
      errors.add('O bairro é obrigatório para entrega');
    }
    if (_pedido.shippingMethod == 'delivery' && _pedido.cityController.text.isEmpty) {
      errors.add('A cidade é obrigatória para entrega');
    }
    if (_pedido.shippingMethod == 'pickup' && _pedido.pickupStoreId.isEmpty) {
      errors.add('Loja de retirada não definida');
    }
    if (_pedido.products.isEmpty) errors.add('Adicione pelo menos um produto ao pedido');
    if (_pedido.shippingMethod.isEmpty) errors.add('Selecione o método de entrega');
    if (_pedido.selectedPaymentMethod.isEmpty) errors.add('Selecione um método de pagamento');
    if (normalizedDate.isEmpty || normalizedTime.isEmpty) errors.add('Selecione a data e o horário de entrega/retirada');
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errors.join('\n')), duration: const Duration(seconds: 5), backgroundColor: Colors.redAccent),
      );
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    try {
      final cep = _pedido.cepController.text.replaceAll(RegExp(r'\D'), '').trim();
      final storeFinal = _pedido.shippingMethod == 'pickup' ? 'Unidade Barreiro' : _pedido.storeFinal;
      final storeId = _pedido.shippingMethod == 'pickup' ? '110727' : _pedido.pickupStoreId;
      final service = CriarPedidoService();
      final billingCompany = '';
      final methodSlug = _paymentSlugFromLabel(_pedido.selectedPaymentMethod);
      final order = await service.createOrder(
        customerName: _pedido.nameController.text,
        customerEmail: _pedido.emailController.text,
        customerPhone: phone,
        billingCompany: billingCompany,
        products: _pedido.products,
        shippingMethod: _pedido.shippingMethod,
        storeFinal: storeFinal,
        pickupStoreId: storeId,
        billingPostcode: cep,
        billingAddress1: _pedido.addressController.text,
        billingNumber: _pedido.numberController.text,
        billingAddress2: _pedido.complementController.text,
        billingNeighborhood: _pedido.neighborhoodController.text,
        billingCity: _pedido.cityController.text,
        shippingCost: _pedido.shippingCost,
        paymentMethod: methodSlug,
        customerNotes: _pedido.showNotesField ? _pedido.notesController.text : '',
        schedulingDate: normalizedDate,
        schedulingTime: normalizedTime,
        couponCode: _pedido.showCouponField ? _pedido.couponController.text : '',
        paymentAccountStripe: _pedido.paymentAccounts['stripe'] ?? 'stripe',
        paymentAccountPagarme: _pedido.paymentAccounts['pagarme'] ?? 'central',
      );
      String? savedPaymentInstructions;
      if (methodSlug == 'pagarme_custom_pix' || methodSlug == _pedido.paymentAccounts['stripe']) {
        final totalBeforeDiscount = _pedido.products.fold<double>(
          0.0,
          (sum, product) => sum + (product['price'] * (product['quantity'] ?? 1)),
        ) + _pedido.shippingCost;
        final discountAmount = _pedido.isCouponValid ? _pedido.discountAmount : 0.0;
        final totalAmount = totalBeforeDiscount - discountAmount;
        final paymentLinkResult = await _generatePaymentLink(
          customerName: _pedido.nameController.text,
          phoneNumber: _pedido.phoneController.text,
          amount: totalAmount,
          storeUnit: storeFinal,
          paymentMethod: methodSlug == 'pagarme_custom_pix' ? 'Pix' : 'Stripe',
          orderId: order['id'].toString(),
        );
        if (paymentLinkResult != null) {
          savedPaymentInstructions = methodSlug == 'pagarme_custom_pix'
              ? jsonEncode({'type': 'pix', 'text': paymentLinkResult['text'] ?? ''})
              : jsonEncode({'type': 'stripe', 'url': paymentLinkResult['url'] ?? ''});
        }
      }
      if (mounted) {
        setState(() {
          _resultMessage = 'Pedido #${order['id']} criado com sucesso!${savedPaymentInstructions != null ? '\nInstruções de pagamento geradas.' : ''}';
          _pedido.paymentInstructions = savedPaymentInstructions;
          _pedido.resetControllers();
          _pedido.products.clear();
          _pedido.shippingMethod = 'delivery';
          _pedido.selectedPaymentMethod = '';
          _pedido.storeFinal = '';
          _pedido.pickupStoreId = '';
          _pedido.shippingCost = 0.0;
          _pedido.shippingCostController.text = '0.00';
          _pedido.showNotesField = false;
          _pedido.showCouponField = false;
          _pedido.schedulingDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
          _pedido.schedulingTime = '09:00 - 12:00';
          _pedido.isCouponValid = false;
          _pedido.discountAmount = 0.0;
          _pedido.couponErrorMessage = null;
          _pedido.availablePaymentMethods = [];
          _pedido.paymentAccounts = {'stripe': 'stripe', 'pagarme': 'central'};
        });
      }
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() => _resultMessage = 'Erro ao criar pedido: $error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<String, String>?> _generatePaymentLink({
    required String customerName,
    required String phoneNumber,
    required double amount,
    required String storeUnit,
    required String paymentMethod,
    required String orderId,
  }) async {
    final rawPhone = phoneNumber.replaceAll(RegExp(r'\D'), '').trim();
    final areaCode = rawPhone.length >= 2 ? rawPhone.substring(0, 2) : '31';
    final phone = rawPhone.length >= 9 ? rawPhone.substring(2) : rawPhone;
    if (amount < 0.50) {
      throw Exception('O valor total do pedido deve ser maior ou igual a R\$ 0,50.');
    }
    final amountInCents = (amount * 100).toInt();
    final proxyUnit = Uri.encodeComponent(storeUnit);
    final endpoint = 'https://aogosto.com.br/proxy/$proxyUnit/${paymentMethod == 'Pix' ? 'pagarme.php' : 'stripe.php'}';
    try {
      if (paymentMethod == 'Pix') {
        final payloadPagarMe = {
          'items': [
            {'amount': amountInCents, 'description': 'Produtos Ao Gosto Carnes', 'quantity': 1},
          ],
          'customer': {
            'name': customerName,
            'email': 'app+${DateTime.now().millisecondsSinceEpoch}@aogosto.com.br',
            'document': '06275992000570',
            'type': 'company',
            'phones': {
              'home_phone': {'country_code': '55', 'number': phone, 'area_code': areaCode}
            },
          },
          'payments': [
            {
              'payment_method': 'pix',
              'pix': {'expires_in': 3600}
            }
          ],
          'metadata': {'order_id': orderId, 'unidade': storeUnit},
        };
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payloadPagarMe),
        );
        if (response.statusCode != 200) {
          throw Exception('Erro ao criar pedido PIX: status ${response.statusCode} - ${response.body}');
        }
        if (response.body.startsWith('<!DOCTYPE') || response.body.contains('<html')) {
          throw Exception('Resposta inválida do servidor (HTML em vez de JSON): ${response.body}');
        }
        final data = jsonDecode(response.body);
        if (data['charges'] != null && data['charges'].isNotEmpty && data['charges'][0]['last_transaction'] != null) {
          final pixInfo = data['charges'][0]['last_transaction'];
          final pixText = pixInfo['text']?.toString() ?? '';
          if (pixText.isEmpty) {
            final fallbackText = pixInfo['qr_code']?.toString() ?? '';
            if (fallbackText.isEmpty) {
              throw Exception('Nenhuma linha digitável ou QR code retornado para Pix.');
            }
            return {'type': 'pix', 'text': fallbackText};
          }
          return {'type': 'pix', 'text': pixText};
        } else {
          throw Exception('Nenhuma transação PIX retornada ou estrutura de resposta inválida: ${jsonEncode(data)}');
        }
      } else {
        final payloadStripe = {
          'product_name': customerName,
          'product_description': 'Produtos Ao Gosto Carnes',
          'amount': amountInCents,
          'phone_number': '($areaCode) $phone',
          'metadata': {'order_id': orderId, 'unidade': storeUnit},
        };
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payloadStripe),
        );
        if (response.statusCode != 200) {
          throw Exception('Erro ao criar link Stripe: status ${response.statusCode} - ${response.body}');
        }
        if (response.body.startsWith('<!DOCTYPE') || response.body.contains('<html')) {
          throw Exception('Resposta inválida do servidor (HTML em vez de JSON): ${response.body}');
        }
        final data = jsonDecode(response.body);
        if (data['payment_link'] != null && data['payment_link']['url'] != null) {
          return {'type': 'stripe', 'url': data['payment_link']['url']};
        } else {
          throw Exception('Nenhuma URL de checkout retornada: ${jsonEncode(data)}');
        }
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar link de pagamento: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return null;
    }
  }

  void _onCouponValidated() {
    if (mounted) setState(() {});
  }

  DateTime? _parseInitialDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateFormat('yyyy-MM-dd').parse(dateString);
    } catch (e) {
      try {
        return DateFormat('dd/MM/yyyy').parse(dateString);
      } catch (e) {
        try {
          return DateFormat('MMMM d, yyyy', 'en_US').parse(dateString);
        } catch (e) {
          debugPrint('Erro ao parsear data: $dateString, erro: $e');
          return null;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalOriginal = _pedido.calculateTotal(applyDiscount: false);
    final totalWithDiscount = _pedido.calculateTotal(applyDiscount: true);
    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(
              backgroundColor: primaryColor.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          Expanded(
            child: FutureBuilder<void>(
              future: _initFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF28C38)),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erro ao inicializar: ${snapshot.error}',
                      style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 16),
                    ),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
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
                          child: CustomerSection(
                            phoneController: _pedido.phoneController,
                            onPhoneChanged: (_) {},
                            onFetchCustomer: _fetchCustomer,
                            nameController: _pedido.nameController,
                            onNameChanged: (_) {},
                            emailController: _pedido.emailController,
                            onEmailChanged: (_) {},
                            validator: (value) => null,
                            isLoading: _isLoading,
                          ),
                        ),
                        const SizedBox(height: 16),
                       ExpansionPanelList(
  elevation: 0,
  expandedHeaderPadding: EdgeInsets.zero,
  expansionCallback: (panelIndex, isExpanded) {
    if (mounted) {
      setState(() => _pedido.isAddressSectionExpanded = !isExpanded);
    }
  },
  children: [
    ExpansionPanel(
      headerBuilder: (context, isExpanded) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          'Endereço do Cliente',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        trailing: AnimatedRotation(
          turns: isExpanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 200),
          child: Icon(Icons.arrow_drop_down_rounded, color: primaryColor, size: 24),
        ),
      ),
      body: AddressSection(
        cepController: _pedido.cepController,
        addressController: _pedido.addressController,
        numberController: _pedido.numberController,
        complementController: _pedido.complementController,
        neighborhoodController: _pedido.neighborhoodController,
        cityController: _pedido.cityController,
        onChanged: (_) {},
        onShippingCostUpdated: (cost) {
  if (mounted) {
    setState(() {
      _pedido.shippingCost = cost;
      _pedido.shippingCostController.text = cost.toStringAsFixed(2);
    });
  }
},
        onStoreUpdated: (storeFinal, pickupStoreId) {
  if (mounted) {
    setState(() {
      _pedido.storeFinal = storeFinal;
      _pedido.pickupStoreId = pickupStoreId;
    });
  }
},
        externalShippingCost: _pedido.shippingCost,
        shippingMethod: _pedido.shippingMethod,
        setStateCallback: () {},
        checkStoreByCep: _checkStoreByCep,
        pedido: _pedido,
        onReset: () {
          _pedido.cepController.clear();
          _pedido.addressController.clear();
          _pedido.numberController.clear();
          _pedido.complementController.clear();
          _pedido.neighborhoodController.clear();
          _pedido.cityController.clear();
          if (mounted) setState(() {});
        },
      ),
      isExpanded: _pedido.isAddressSectionExpanded,
    ),
  ],
),                      const SizedBox(height: 16),
                        AnimatedContainer(
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
                          child: ProductSection(
                            products: _pedido.products,
                            onRemoveProduct: (index) {
                              if (index >= 0 && index < _pedido.products.length) {
                                if (mounted) {
                                  setState(() => _pedido.products.removeAt(index));
                                  _pedido.notifyListeners();
                                }
                              }
                            },
                            onAddProduct: () async {
                              final selectedProduct = await showDialog<Map<String, dynamic>>(
                                context: context,
                                builder: (context) => const ProductSelectionDialog(),
                              );
                              if (selectedProduct != null && mounted) {
                                setState(() {
                                  _pedido.products.add({
                                    'id': selectedProduct['id'],
                                    'name': selectedProduct['name'],
                                    'quantity': 1,
                                    'price': double.tryParse(selectedProduct['price'].toString()) ?? 0.0,
                                    'variation_id': selectedProduct['variation_id'],
                                    'variation_attributes': selectedProduct['variation_attributes'],
                                    'image': selectedProduct['image'],
                                  });
                                });
                                _pedido.notifyListeners();
                              }
                            },
                            onUpdateQuantity: (index, quantity) {
                              if (index >= 0 && index < _pedido.products.length) {
                                _pedido.updateProductQuantity(index, quantity);
                              }
                            },
                            onUpdatePrice: (index, price) {
                              if (index >= 0 && index < _pedido.products.length) {
                                _pedido.products[index]['price'] = price;
                                _pedido.notifyListeners();
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedContainer(
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
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.calendar_today, color: primaryColor),
                                  title: Text(
                                    'Data e Horário de Entrega/Retirada',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                SchedulingSection(
                                  shippingMethod: _pedido.shippingMethod,
                                  storeFinal: _pedido.storeFinal,
                                  onDateTimeUpdated: (date, time) {
                                    if (mounted) {
                                      setState(() {
                                        _pedido.schedulingDate = date;
                                        _pedido.schedulingTime = ensureTimeRange(time);
                                      });
                                    }
                                  },
                                  onSchedulingChanged: _checkStoreByCep,
                                  initialDate: _parseInitialDate(_pedido.schedulingDate),
                                  initialTimeSlot: _pedido.schedulingTime.isNotEmpty ? _pedido.schedulingTime : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.note, color: primaryColor),
                                title: Text(
                                  'Observações do Cliente',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                trailing: Checkbox(
                                  value: _pedido.showNotesField,
                                  onChanged: (value) {
                                    if (mounted) {
                                      setState(() {
                                        _pedido.showNotesField = value ?? false;
                                        if (!_pedido.showNotesField) _pedido.notesController.text = '';
                                      });
                                    }
                                  },
                                  activeColor: primaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              AnimatedCrossFade(
                                duration: const Duration(milliseconds: 200),
                                crossFadeState: _pedido.showNotesField ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                firstChild: const SizedBox.shrink(),
                                secondChild: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: TextFormField(
                                    controller: _pedido.notesController,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      labelText: 'Observações',
                                      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
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
                                      prefixIcon: Icon(Icons.note_alt, color: primaryColor),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.discount, color: primaryColor),
                                title: Text(
                                  'Cupom de Desconto',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                trailing: Checkbox(
                                  value: _pedido.showCouponField,
                                  onChanged: (value) {
                                    if (mounted) {
                                      setState(() {
                                        _pedido.showCouponField = value ?? false;
                                        if (!_pedido.showCouponField) {
                                          _pedido.couponController.text = '';
                                          _pedido.isCouponValid = false;
                                          _pedido.discountAmount = 0.0;
                                          _pedido.couponErrorMessage = null;
                                        }
                                      });
                                    }
                                  },
                                  activeColor: primaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              AnimatedCrossFade(
                                duration: const Duration(milliseconds: 200),
                                crossFadeState: _pedido.showCouponField ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                firstChild: const SizedBox.shrink(),
                                secondChild: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: TextFormField(
                                    controller: _pedido.couponController,
                                    decoration: InputDecoration(
                                      labelText: 'Código do Cupom',
                                      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
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
                                      prefixIcon: Icon(Icons.discount, color: primaryColor),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      suffixIcon: _pedido.isCouponValid
                                          ? Icon(Icons.check_circle, color: Colors.green.shade600)
                                          : _pedido.couponController.text.isNotEmpty
                                              ? Icon(Icons.error, color: Colors.red.shade600)
                                              : null,
                                    ),
                                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                                    validator: (value) => null,
                                  ),
                                ),
                              ),
                              if (_pedido.couponErrorMessage != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _pedido.couponErrorMessage!,
                                  style: GoogleFonts.poppins(
                                    color: Colors.red.shade600,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SummarySection(
                          totalOriginal: totalOriginal,
                          isCouponValid: _pedido.isCouponValid,
                          couponCode: _pedido.couponController.text,
                          discountAmount: _pedido.discountAmount,
                          totalWithDiscount: totalWithDiscount,
                          isLoading: _isLoading,
                          onCreateOrder: _createOrder,
                          pedido: _pedido,
                          paymentInstructions: _pedido.paymentInstructions,
                          resultMessage: _resultMessage,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}