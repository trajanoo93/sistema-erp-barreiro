import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:erp_painel/models/pedido_state.dart';
import 'package:erp_painel/services/criar_pedido_service.dart';
import 'package:erp_painel/widgets/customer_section.dart';
import 'package:erp_painel/widgets/product_section.dart';
import 'package:erp_painel/widgets/address_section.dart';
import 'package:erp_painel/widgets/scheduling_section.dart';
import 'package:erp_painel/widgets/summary_section.dart';
import 'package:erp_painel/widgets/product_selection_dialog.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
  bool _isInitialized = false;

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
    _initializePedido();
  }

  Future<void> _initializePedido() async {
    _pedido = PedidoState(onCouponValidated: _onCouponValidated);
    _pedido.schedulingDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _pedido.shippingMethod = 'delivery';
    _pedido.schedulingTime = '09:00 - 12:00';
    await _loadPersistedData();
    if (mounted) {
      setState(() => _isInitialized = true);
    }
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

  Future<void> logToFile(String message) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/sistema-erp-barreiro/app_logs.txt');
      await file.writeAsString('[${DateTime.now()}] $message\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Falha ao escrever log: $e');
    }
  }

  Future<void> _loadPersistedData() async {
    final prefs = await SharedPreferences.getInstance();
    _pedido.phoneController.text = prefs.getString('phone') ?? '';
    _pedido.nameController.text = prefs.getString('name') ?? '';
    _pedido.emailController.text = prefs.getString('email') ?? '';
    _pedido.cepController.text = prefs.getString('cep') ?? '';
    _pedido.addressController.text = prefs.getString('address') ?? '';
    _pedido.numberController.text = prefs.getString('number') ?? '';
    _pedido.complementController.text = prefs.getString('complement') ?? '';
    _pedido.neighborhoodController.text = prefs.getString('neighborhood') ?? '';
    _pedido.cityController.text = prefs.getString('city') ?? '';
    _pedido.notesController.text = prefs.getString('notes') ?? '';
    _pedido.couponController.text = prefs.getString('coupon') ?? '';
    _pedido.products = (jsonDecode(prefs.getString('products') ?? '[]') as List).cast<Map<String, dynamic>>();
    _pedido.shippingMethod = prefs.getString('shippingMethod') ?? 'delivery';
    String? savedPaymentMethod = prefs.getString('paymentMethod');
    _pedido.selectedPaymentMethod = _validPaymentMethods.contains(savedPaymentMethod) ? savedPaymentMethod ?? '' : '';
    _pedido.availablePaymentMethods = List<Map<String, String>>.from(jsonDecode(prefs.getString('availablePaymentMethods') ?? '[]'));
    _pedido.paymentAccounts = Map<String, String>.from(jsonDecode(prefs.getString('paymentAccounts') ?? '{"stripe":"stripe","pagarme":"central"}'));
    _pedido.shippingCost = _pedido.shippingMethod == 'pickup' ? 0.0 : (prefs.getDouble('shippingCost') ?? 0.0);
    _pedido.shippingCostController.text = _pedido.shippingCost.toStringAsFixed(2);
    _pedido.storeFinal = _pedido.shippingMethod == 'pickup' ? 'Unidade Barreiro' : (prefs.getString('storeFinal') ?? '');
    _pedido.pickupStoreId = _pedido.shippingMethod == 'pickup' ? '110727' : (prefs.getString('pickupStoreId') ?? '');
    _pedido.showNotesField = prefs.getBool('showNotesField') ?? false;
    _pedido.showCouponField = prefs.getBool('showCouponField') ?? false;
    _pedido.schedulingDate = prefs.getString('schedulingDate') ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    _pedido.schedulingTime = ensureTimeRange(prefs.getString('schedulingTime') ?? '09:00 - 12:00');
    _pedido.isCustomerSectionExpanded = prefs.getBool('isCustomerSectionExpanded') ?? true;
    _pedido.isAddressSectionExpanded = prefs.getBool('isAddressSectionExpanded') ?? true;
    _pedido.isProductsSectionExpanded = prefs.getBool('isProductsSectionExpanded') ?? true;
    _pedido.isShippingSectionExpanded = prefs.getBool('isShippingSectionExpanded') ?? true;
    await logToFile('Dados persistidos carregados: shippingMethod=${_pedido.shippingMethod}, storeFinal=${_pedido.storeFinal}, pickupStoreId=${_pedido.pickupStoreId}, shippingCost=${_pedido.shippingCost}');
  }

  Future<void> _savePersistedData() async {
    final prefs = await SharedPreferences.getInstance();
    if (_pedido.shippingMethod == 'pickup') {
      _pedido.shippingCost = 0.0;
      _pedido.shippingCostController.text = '0.00';
      _pedido.storeFinal = 'Unidade Barreiro';
      _pedido.pickupStoreId = '110727';
    }
    await prefs.setString('phone', _pedido.phoneController.text);
    await prefs.setString('name', _pedido.nameController.text);
    await prefs.setString('email', _pedido.emailController.text);
    await prefs.setString('cep', _pedido.cepController.text);
    await prefs.setString('address', _pedido.addressController.text);
    await prefs.setString('number', _pedido.numberController.text);
    await prefs.setString('complement', _pedido.complementController.text);
    await prefs.setString('neighborhood', _pedido.neighborhoodController.text);
    await prefs.setString('city', _pedido.cityController.text);
    await prefs.setString('notes', _pedido.notesController.text);
    await prefs.setString('coupon', _pedido.couponController.text);
    await prefs.setString('products', jsonEncode(_pedido.products));
    await prefs.setString('shippingMethod', _pedido.shippingMethod);
    await prefs.setString('paymentMethod', _pedido.selectedPaymentMethod);
    await prefs.setString('availablePaymentMethods', jsonEncode(_pedido.availablePaymentMethods));
    await prefs.setString('paymentAccounts', jsonEncode(_pedido.paymentAccounts));
    await prefs.setDouble('shippingCost', _pedido.shippingCost);
    await prefs.setString('storeFinal', _pedido.storeFinal);
    await prefs.setString('pickupStoreId', _pedido.pickupStoreId);
    await prefs.setBool('showNotesField', _pedido.showNotesField);
    await prefs.setBool('showCouponField', _pedido.showCouponField);
    await prefs.setString('schedulingDate', _pedido.schedulingDate);
    await prefs.setString('schedulingTime', _pedido.schedulingTime);
    await prefs.setBool('isCustomerSectionExpanded', _pedido.isCustomerSectionExpanded);
    await prefs.setBool('isAddressSectionExpanded', _pedido.isAddressSectionExpanded);
    await prefs.setBool('isProductsSectionExpanded', _pedido.isProductsSectionExpanded);
    await prefs.setBool('isShippingSectionExpanded', _pedido.isShippingSectionExpanded);
    await logToFile('Dados persistidos salvos: shippingMethod=${_pedido.shippingMethod}, storeFinal=${_pedido.storeFinal}, pickupStoreId=${_pedido.pickupStoreId}, shippingCost=${_pedido.shippingCost}');
  }

  Future<void> _fetchCustomer() async {
    if (_debounce?.isActive ?? false) return;
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final phone = _pedido.phoneController.text.replaceAll(RegExp(r'\D'), '').trim();
      await logToFile('Buscando cliente: telefone=$phone, isPhoneValid=${phone.length == 11}');
      if (phone.length != 11) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, insira um número de telefone válido (11 dígitos com DDD)'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      setState(() => _isLoading = true);
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
          await _savePersistedData();
          final cleanCep = _pedido.cepController.text.replaceAll(RegExp(r'\D'), '');
          if (cleanCep.length == 8 && cleanCep != _pedido.lastCep) {
            _pedido.lastCep = cleanCep;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _checkStoreByCep();
            });
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
        await logToFile('Erro ao buscar cliente: $error');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _checkStoreByCep() async {
    final cep = _pedido.cepController.text.replaceAll(RegExp(r'\D'), '').trim();
    await logToFile('Verificando CEP: $cep, shippingMethod: ${_pedido.shippingMethod}, scheduling: ${_pedido.schedulingDate}/${_pedido.schedulingTime}');
    if (cep.length != 8 && _pedido.shippingMethod != 'pickup') {
      await logToFile('CEP incompleto, redefinindo loja e custo.');
      setState(() {
        _pedido.shippingCost = 0.0;
        _pedido.shippingCostController.text = '0.00';
        _pedido.storeFinal = '';
        _pedido.pickupStoreId = '';
        _pedido.availablePaymentMethods = [];
        _pedido.paymentAccounts = {'stripe': 'stripe', 'pagarme': 'central'};
      });
      await _savePersistedData();
      return;
    }
    setState(() => _isLoading = true);
    try {
      final normalizedDate = normalizeYmd(_pedido.schedulingDate);
      final requestBody = {
        'cep': cep,
        'shipping_method': _pedido.shippingMethod,
        'pickup_store': _pedido.shippingMethod == 'pickup' ? 'Unidade Barreiro' : '',
        'delivery_date': _pedido.shippingMethod == 'delivery' ? normalizedDate : '',
        'pickup_date': _pedido.shippingMethod == 'pickup' ? normalizedDate : '',
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
      if (_pedido.shippingMethod == 'delivery') {
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
        final data = jsonDecode(storeResponse.body);
        final newStoreFinal = data['effective_store_final']?.toString() ?? data['store_final']?.toString() ?? 'Unidade Barreiro';
        setState(() {
          _pedido.storeFinal = _pedido.shippingMethod == 'pickup' ? 'Unidade Barreiro' : newStoreFinal;
          _pedido.pickupStoreId = _pedido.shippingMethod == 'pickup' ? '110727' : data['pickup_store_id']?.toString() ?? '110727';
          _pedido.shippingCost = _pedido.shippingMethod == 'pickup' ? 0.0 : shippingCost;
          _pedido.shippingCostController.text = _pedido.shippingCost.toStringAsFixed(2);
          final rawPaymentMethods = List<Map>.from(data['payment_methods'] ?? []);
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
          final paymentAccounts = data['payment_accounts'] as Map? ?? {'stripe': 'stripe', 'pagarme': 'central'};
          _pedido.paymentAccounts = paymentAccounts.map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''));
          if (_pedido.selectedPaymentMethod.isNotEmpty &&
              !_pedido.availablePaymentMethods.any((m) => m['title'] == _pedido.selectedPaymentMethod)) {
            _pedido.selectedPaymentMethod = _pedido.availablePaymentMethods.isNotEmpty
                ? _pedido.availablePaymentMethods.first['title'] ?? ''
                : '';
          }
        });
        await _savePersistedData();
      } else {
        throw Exception('Erro ao buscar opções de entrega: ${storeResponse.statusCode} - ${storeResponse.body}');
      }
    } catch (e, stackTrace) {
      await logToFile('Erro em _checkStoreByCep: $e, StackTrace: $stackTrace');
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
    } finally {
      setState(() => _isLoading = false);
      await _savePersistedData();
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
      await logToFile('Erro de validação: ${errors.join(', ')}');
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final cep = _pedido.cepController.text.replaceAll(RegExp(r'\D'), '').trim();
      final storeFinal = _pedido.shippingMethod == 'pickup' ? 'Unidade Barreiro' : _pedido.storeFinal;
      final storeId = _pedido.shippingMethod == 'pickup' ? '110727' : _pedido.pickupStoreId;
      final service = CriarPedidoService();
      final billingCompany = '';
      final methodSlug = _paymentSlugFromLabel(_pedido.selectedPaymentMethod);
      await logToFile('Criando pedido: paymentMethod=${_pedido.selectedPaymentMethod}, slug=$methodSlug, storeFinal=$storeFinal, pickupStoreId=$storeId');
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
      await logToFile('Pedido criado: #${order['id']}, store: $storeFinal, payment: $methodSlug');
      _pedido.updateLastPhoneNumber(_pedido.phoneController.text);
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
          await logToFile('Instruções de pagamento geradas: $savedPaymentInstructions');
        } else {
          await logToFile('Erro: paymentLinkResult is null para paymentMethod: $methodSlug');
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
        await _savePersistedData();
      }
    } catch (error, stackTrace) {
      await logToFile('Erro ao criar pedido: $error, StackTrace: $stackTrace');
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
    final proxyUnit = Uri.encodeComponent(storeUnit); // Codifica 'Unidade Barreiro' como 'Unidade%20Barreiro'
    final endpoint = 'https://aogosto.com.br/proxy/$proxyUnit/${paymentMethod == 'Pix' ? 'pagarme.php' : 'stripe.php'}';
    await logToFile('Gerando link de pagamento: paymentMethod=$paymentMethod, storeUnit=$storeUnit, proxyUnit=$proxyUnit, endpoint=$endpoint, amountInCents=$amountInCents');
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
        await logToFile('Payload PagarMe: ${jsonEncode(payloadPagarMe)}');
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payloadPagarMe),
        );
        await logToFile('Resposta do proxy PagarMe: status=${response.statusCode}, body=${response.body}');
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
            await logToFile('Aviso: pixText vazio, usando qr_code como fallback: ${pixInfo['qr_code'] ?? 'null'}');
            final fallbackText = pixInfo['qr_code']?.toString() ?? '';
            if (fallbackText.isEmpty) {
              throw Exception('Nenhuma linha digitável ou QR code retornado para Pix.');
            }
            return {'type': 'pix', 'text': fallbackText};
          }
          await logToFile('Pix text extraído: $pixText');
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
        await logToFile('Payload Stripe: ${jsonEncode(payloadStripe)}');
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payloadStripe),
        );
        await logToFile('Resposta do proxy Stripe: status=${response.statusCode}, body=${response.body}');
        if (response.statusCode != 200) {
          throw Exception('Erro ao criar link Stripe: status ${response.statusCode} - ${response.body}');
        }
        if (response.body.startsWith('<!DOCTYPE') || response.body.contains('<html')) {
          throw Exception('Resposta inválida do servidor (HTML em vez de JSON): ${response.body}');
        }
        final data = jsonDecode(response.body);
        if (data['payment_link'] != null && data['payment_link']['url'] != null) {
          await logToFile('Stripe URL gerada: ${data['payment_link']['url']}');
          return {'type': 'stripe', 'url': data['payment_link']['url']};
        } else {
          throw Exception('Nenhuma URL de checkout retornada: ${jsonEncode(data)}');
        }
      }
    } catch (error) {
      await logToFile('Erro ao gerar link de pagamento: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar link de pagamento: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return null; // Fallback para continuar criando o pedido sem link
    }
  }

  Future<void> _clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
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
      _resultMessage = 'Dados locais limpos com sucesso';
    });
    await logToFile('Dados locais limpos pelo usuário');
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
            child: _isInitialized
                ? SingleChildScrollView(
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
                              onPhoneChanged: (value) => _savePersistedData(),
                              onFetchCustomer: _fetchCustomer,
                              nameController: _pedido.nameController,
                              onNameChanged: (value) => _savePersistedData(),
                              emailController: _pedido.emailController,
                              onEmailChanged: (value) => _savePersistedData(),
                              validator: (value) => null,
                              isLoading: _isLoading,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ExpansionPanelList(
                            elevation: 0,
                            expandedHeaderPadding: EdgeInsets.zero,
                            expansionCallback: (panelIndex, isExpanded) {
                              setState(() => _pedido.isAddressSectionExpanded = !isExpanded);
                              _savePersistedData();
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
                                  onChanged: (value) {
                                    setState(() {});
                                    _savePersistedData();
                                    if (_pedido.cepController.text.replaceAll(RegExp(r'\D'), '').length == 8) {
                                      _checkStoreByCep();
                                    }
                                  },
                                  onShippingCostUpdated: (cost) {
                                    setState(() {
                                      _pedido.shippingCost = cost;
                                      _pedido.shippingCostController.text = cost.toStringAsFixed(2);
                                    });
                                    _savePersistedData();
                                  },
                                  onStoreUpdated: (storeFinal, pickupStoreId) {
                                    setState(() {
                                      _pedido.storeFinal = storeFinal;
                                      _pedido.pickupStoreId = pickupStoreId;
                                    });
                                    _savePersistedData();
                                    _checkStoreByCep();
                                  },
                                  externalShippingCost: _pedido.shippingCost,
                                  shippingMethod: _pedido.shippingMethod,
                                  setStateCallback: () => setState(() {}),
                                  savePersistedData: _savePersistedData,
                                  checkStoreByCep: _checkStoreByCep,
                                  pedido: _pedido,
                                  onReset: () {
                                    _pedido.cepController.clear();
                                    _pedido.addressController.clear();
                                    _pedido.numberController.clear();
                                    _pedido.complementController.clear();
                                    _pedido.neighborhoodController.clear();
                                    _pedido.cityController.clear();
                                    setState(() {});
                                    _savePersistedData();
                                  },
                                ),
                                isExpanded: _pedido.isAddressSectionExpanded,
                              ),
                            ],
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
                            child: ProductSection(
                              products: _pedido.products,
                              onRemoveProduct: (index) {
                                if (index >= 0 && index < _pedido.products.length) {
                                  setState(() => _pedido.products.removeAt(index));
                                  _pedido.notifyListeners();
                                  _savePersistedData();
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
                                  _savePersistedData();
                                }
                              },
                              onUpdateQuantity: (index, quantity) {
                                if (index >= 0 && index < _pedido.products.length) {
                                  _pedido.updateProductQuantity(index, quantity);
                                  _savePersistedData();
                                }
                              },
                              onUpdatePrice: (index, price) {
                                if (index >= 0 && index < _pedido.products.length) {
                                  _pedido.products[index]['price'] = price;
                                  _pedido.notifyListeners();
                                  _savePersistedData();
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
                                      setState(() {
                                        _pedido.schedulingDate = date;
                                        _pedido.schedulingTime = ensureTimeRange(time);
                                      });
                                      _savePersistedData();
                                      _checkStoreByCep();
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
                                      setState(() {
                                        _pedido.showNotesField = value ?? false;
                                        if (!_pedido.showNotesField) _pedido.notesController.text = '';
                                      });
                                      _savePersistedData();
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
                                      onChanged: (value) => _savePersistedData(),
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
                                      setState(() {
                                        _pedido.showCouponField = value ?? false;
                                        if (!_pedido.showCouponField) {
                                          _pedido.couponController.text = '';
                                          _pedido.isCouponValid = false;
                                          _pedido.discountAmount = 0.0;
                                          _pedido.couponErrorMessage = null;
                                        }
                                      });
                                      _savePersistedData();
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
                                      onChanged: (value) => _savePersistedData(),
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
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: _clearLocalData,
                            icon: Icon(Icons.refresh, size: 16, color: primaryColor),
                            label: Text(
                              'Limpar Dados',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: primaryColor,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}