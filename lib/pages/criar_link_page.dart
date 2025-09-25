import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async'; // Adicionado para suportar Timer
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CriarLinkPage extends StatefulWidget {
  const CriarLinkPage({Key? key}) : super(key: key);

  @override
  State<CriarLinkPage> createState() => _CriarLinkPageState();
}

class _CriarLinkPageState extends State<CriarLinkPage> {
  final _formKey = GlobalKey<FormState>();
  String _paymentMethod = 'pix';
  final _orderIdController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;
  bool _isFetchingOrder = false;
  String? _resultMessage;
  String? _qrCodeUrl;
  String? _pixQrCode;
  String? _stripeCheckoutUrl;
  Timer? _debounce;

  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  Future<void> logToFile(String message) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/sistema-erp-barreiro/app_logs.txt');
      await file.writeAsString('[${DateTime.now()}] $message\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Falha ao escrever log: $e');
    }
  }

  Future<void> _fetchOrder() async {
    final orderId = _orderIdController.text.trim();
    if (orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor, insira o ID do pedido', style: GoogleFonts.poppins(fontSize: 14)),
          backgroundColor: Colors.redAccent,
        ),
      );
      await logToFile('Erro: ID do pedido vazio');
      return;
    }

    setState(() {
      _isFetchingOrder = true;
      _customerNameController.clear();
      _phoneNumberController.clear();
      _amountController.clear();
      _resultMessage = null;
      _qrCodeUrl = null;
      _pixQrCode = null;
      _stripeCheckoutUrl = null;
    });

    try {
      if (orderId.length == 5) {
        await logToFile('Buscando no App com ID: $orderId');
        final appListResponse = await http.get(
          Uri.parse('https://shop.fabapp.com/panel/stores/26682591/orders'),
        );

        if (appListResponse.statusCode != 200 || appListResponse.body.startsWith('<!DOCTYPE') || appListResponse.body.contains('<html')) {
          throw Exception('Erro ao buscar lista de pedidos do app: status ${appListResponse.statusCode}, body ${appListResponse.body}');
        }

        final appData = jsonDecode(appListResponse.body);
        final orders = appData['data'] as List<dynamic>;
        final order = orders.firstWhere(
          (o) => o['orderNumber'].toString() == orderId,
          orElse: () => null,
        );

        if (order == null) {
          throw Exception('Pedido não encontrado no app');
        }

        final orderIdApp = order['id'];
        final orderDetailsResponse = await http.get(
          Uri.parse('https://shop.fabapp.com/panel/stores/26682591/orders/$orderIdApp'),
        );

        if (orderDetailsResponse.statusCode != 200 || orderDetailsResponse.body.startsWith('<!DOCTYPE') || orderDetailsResponse.body.contains('<html')) {
          throw Exception('Erro ao buscar detalhes do pedido do app: status ${orderDetailsResponse.statusCode}, body ${orderDetailsResponse.body}');
        }

        final orderDetails = jsonDecode(orderDetailsResponse.body);
        final amountInCents = double.parse(orderDetails['amountFinal']);
        final amountInReais = (amountInCents / 100).toStringAsFixed(2);
        final rawPhone = orderDetails['userPhone'];
        final formattedPhone = rawPhone.length >= 11
            ? '(${rawPhone.substring(2, 4)}) ${rawPhone.substring(4, 9)}-${rawPhone.substring(9)}'
            : rawPhone;

        setState(() {
          _customerNameController.text = orderDetails['userName'];
          _phoneNumberController.text = formattedPhone;
          _amountController.text = amountInReais;
        });
      } else if (orderId.length == 6) {
        await logToFile('Buscando no WooCommerce com ID: $orderId');
        final wooResponse = await http.get(
          Uri.parse('https://aogosto.com.br/delivery/wp-json/wc/v3/orders/$orderId'),
          headers: {
            'Authorization':
                'Basic ${base64Encode(utf8.encode('ck_5156e2360f442f2585c8c9a761ef084b710e811f:cs_c62f9d8f6c08a1d14917e2a6db5dccce2815de8c'))}',
          },
        );

        if (wooResponse.statusCode != 200 || wooResponse.body.startsWith('<!DOCTYPE') || wooResponse.body.contains('<html')) {
          throw Exception('Erro ao buscar pedido no WooCommerce: status ${wooResponse.statusCode}, body ${wooResponse.body}');
        }

        final data = jsonDecode(wooResponse.body);
        final billing = data['billing'];

        setState(() {
          _customerNameController.text = '${billing['first_name']} ${billing['last_name']}';
          _phoneNumberController.text = billing['phone'];
          _amountController.text = data['total'];
        });
      } else {
        throw Exception('ID do pedido inválido: use 5 dígitos para o app ou 6 dígitos para o WooCommerce');
      }
    } catch (error) {
      await logToFile('Erro ao buscar pedido: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao buscar pedido: $error', style: GoogleFonts.poppins(fontSize: 14)),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isFetchingOrder = false);
    }
  }

  Future<Map<String, String>?> _generatePaymentLinkInternal({
    required String customerName,
    required String phoneNumber,
    required double amount,
    required String paymentMethod,
    required String orderId,
  }) async {
    final rawPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (rawPhone.length < 10 || rawPhone.length > 11) {
      throw Exception('Número de telefone inválido: deve ter 10 ou 11 dígitos.');
    }
    final areaCode = rawPhone.length >= 2 ? rawPhone.substring(0, 2) : '31';
    final phone = rawPhone.length >= 9 ? rawPhone.substring(2) : rawPhone;
    final amountInCents = (amount * 100).toInt();

    if (amountInCents <= 0) {
      throw Exception('O valor total do pedido deve ser maior que zero.');
    }

    const storeUnit = 'Unidade Barreiro';
    const proxyUnit = 'Unidade%20Barreiro';
    final endpoint = 'https://aogosto.com.br/proxy/$proxyUnit/${paymentMethod == 'pix' ? 'pagarme.php' : 'stripe.php'}';

    await logToFile('Gerando link de pagamento: paymentMethod=$paymentMethod, storeUnit=$storeUnit, endpoint=$endpoint, amountInCents=$amountInCents');

    try {
      if (paymentMethod == 'pix') {
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
            {'payment_method': 'pix', 'pix': {'expires_in': 3600}}
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
        if (response.statusCode != 200 || response.body.startsWith('<!DOCTYPE') || response.body.contains('<html')) {
          throw Exception('Erro ao criar pedido PIX: status ${response.statusCode}, body ${response.body}');
        }

        final data = jsonDecode(response.body);
        if (data['charges'] != null && data['charges'].isNotEmpty && data['charges'][0]['last_transaction'] != null) {
          final pixInfo = data['charges'][0]['last_transaction'];
          final pixText = pixInfo['text']?.toString() ?? '';
          final qrCodeUrl = pixInfo['qr_code_url']?.toString() ?? '';
          if (pixText.isEmpty) {
            await logToFile('Aviso: pixText vazio, usando qr_code como fallback: ${pixInfo['qr_code'] ?? 'null'}');
            final fallbackText = pixInfo['qr_code']?.toString() ?? '';
            if (fallbackText.isEmpty) {
              throw Exception('Nenhuma linha digitável ou QR code retornado para Pix.');
            }
            return {'type': 'pix', 'text': fallbackText, 'qr_code_url': qrCodeUrl};
          }
          return {'type': 'pix', 'text': pixText, 'qr_code_url': qrCodeUrl};
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
        if (response.statusCode != 200 || response.body.startsWith('<!DOCTYPE') || response.body.contains('<html')) {
          throw Exception('Erro ao criar link Stripe: status ${response.statusCode}, body ${response.body}');
        }

        final data = jsonDecode(response.body);
        if (data['payment_link'] != null && data['payment_link']['url'] != null) {
          return {'type': 'stripe', 'url': data['payment_link']['url']};
        } else {
          throw Exception('Nenhuma URL de checkout retornada: ${jsonEncode(data)}');
        }
      }
    } catch (error) {
      await logToFile('Erro ao gerar link de pagamento: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar link de pagamento: $error', style: GoogleFonts.poppins(fontSize: 14)),
          backgroundColor: Colors.redAccent,
        ),
      );
      return null;
    }
  }

  Future<void> _generatePaymentLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _resultMessage = null;
      _qrCodeUrl = null;
      _pixQrCode = null;
      _stripeCheckoutUrl = null;
    });

    try {
      final customerName = _customerNameController.text.trim();
      final phoneNumber = _phoneNumberController.text.trim();
      final amount = double.parse(_amountController.text.trim());
      final paymentMethod = _paymentMethod;
      final orderId = _orderIdController.text.trim();

      final paymentLinkResult = await _generatePaymentLinkInternal(
        customerName: customerName,
        phoneNumber: phoneNumber,
        amount: amount,
        paymentMethod: paymentMethod,
        orderId: orderId,
      );

      if (paymentLinkResult != null) {
        setState(() {
          if (paymentLinkResult['type'] == 'pix') {
            _resultMessage = 'Pagamento PIX criado com sucesso!';
            _qrCodeUrl = paymentLinkResult['qr_code_url'];
            _pixQrCode = paymentLinkResult['text'];
          } else {
            _resultMessage = 'Link de pagamento Stripe criado com sucesso!';
            _stripeCheckoutUrl = paymentLinkResult['url'];
          }
        });
      }
    } catch (error) {
      setState(() {
        _resultMessage = 'Erro: $error';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copiado para a área de transferência!', style: GoogleFonts.poppins(fontSize: 14)),
        backgroundColor: Colors.green,
      ),
    );
    await logToFile('Texto copiado para a área de transferência: $text');
  }

  @override
  void dispose() {
    _orderIdController.dispose();
    _customerNameController.dispose();
    _phoneNumberController.dispose();
    _amountController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFF28C38);
    final successColor = Colors.green.shade600;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.1),
      
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Busque o pedido para criar um link de pagamento para a Unidade Barreiro:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Container(
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _orderIdController,
                            decoration: InputDecoration(
                              labelText: 'ID do Pedido',
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
                              prefixIcon: Icon(Icons.search, color: primaryColor),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Por favor, insira o ID do pedido';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              _debounce?.cancel();
                              _debounce = Timer(const Duration(milliseconds: 500), _fetchOrder);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 100,
                          child: ElevatedButton(
                            onPressed: _isFetchingOrder ? null : _fetchOrder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              shadowColor: Colors.black.withOpacity(0.2),
                            ),
                            child: _isFetchingOrder
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    'Buscar',
                                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _paymentMethod,
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
                      ),
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                      items: const [
                        DropdownMenuItem(value: 'pix', child: Text('Pix')),
                        DropdownMenuItem(value: 'credit_card', child: Text('Cartão de Crédito On-line')),
                      ],
                      onChanged: (value) => setState(() => _paymentMethod = value!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _customerNameController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Nome do Cliente',
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
                        prefixIcon: Icon(Icons.person, color: primaryColor),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, busque o pedido para preencher este campo';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneNumberController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Telefone (DDD + Número)',
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
                        prefixIcon: Icon(Icons.phone, color: primaryColor),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, busque o pedido para preencher este campo';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Valor (R\$)',
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
                        prefixIcon: Icon(Icons.money, color: primaryColor),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, insira o valor';
                        }
                        if (double.tryParse(value) == null || double.parse(value) <= 0) {
                          return 'Por favor, insira um valor válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _generatePaymentLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          shadowColor: Colors.black.withOpacity(0.2),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Gerar Link',
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_resultMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _resultMessage!.contains('Erro') ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _resultMessage!.contains('Erro') ? Colors.red.shade200 : Colors.green.shade200),
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
                      _resultMessage!.contains('Erro') ? Icons.error : Icons.check_circle,
                      color: _resultMessage!.contains('Erro') ? Colors.redAccent : Colors.green.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _resultMessage!,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _resultMessage!.contains('Erro') ? Colors.redAccent : Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_qrCodeUrl != null && _pixQrCode != null) ...[
                const SizedBox(height: 16),
                Text(
                  'QR Code:',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Image.network(
                      _qrCodeUrl!,
                      width: 200,
                      height: 200,
                      errorBuilder: (context, error, stackTrace) => Text(
                        'Erro ao carregar QR Code',
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.redAccent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Linha Digitável (Pix):',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _pixQrCode!,
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.copy, size: 20, color: primaryColor),
                        onPressed: () => _copyToClipboard(_pixQrCode!),
                        tooltip: 'Copiar Código Pix',
                      ),
                    ],
                  ),
                ),
              ],
              if (_stripeCheckoutUrl != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Link de Pagamento (Cartão de Crédito):',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _stripeCheckoutUrl!,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.blue.shade600,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.copy, size: 20, color: primaryColor),
                        onPressed: () => _copyToClipboard(_stripeCheckoutUrl!),
                        tooltip: 'Copiar Link de Pagamento',
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}