import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';



class CriarPedidoService {
  static const String _baseUrl = 'https://aogosto.com.br/delivery/';
  static const String _proxyUrl = 'https://aogosto.com.br/afonsos/proxy/buscar-cliente-por-telefone.php';
  static const String _proxyCheckoutUrl = 'https://aogosto.com.br/proxy/checkout-flutter.php';
  static const String _consumerKey = 'ck_5156e2360f442f2585c8c9a761ef084b710e811f';
  static const String _consumerSecret = 'cs_c62f9d8f6c08a1d14917e2a6db5dccce2815de8c';

  Future<void> logToFile(String message) async {
    // desativado
  }

  Future<Map<String, dynamic>?> fetchCustomerByPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    await logToFile('Buscando cliente com telefone: $cleanPhone');
    String searchPhone = cleanPhone.startsWith('55') ? cleanPhone.substring(2) : cleanPhone;
    try {
      final response = await http.post(
        Uri.parse(_proxyUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'phone': searchPhone}),
      );
      await logToFile('Resposta fetchCustomerByPhone: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode == 200) {
        final customer = jsonDecode(response.body);
        await logToFile('Cliente encontrado: ID=${customer['id']}, Telefone no banco: ${customer['billing']['phone']}, Último pedido ID: ${customer['last_order_id']}');
        return customer;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Erro ao buscar cliente: ${response.statusCode} - ${response.body}');
      }
    } catch (error) {
      await logToFile('Erro ao buscar cliente: $error');
      throw Exception('Erro ao buscar cliente: $error');
    }
  }

  Future<List<Map<String, dynamic>>> fetchProducts(String searchTerm) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/wp-json/wc/v3/products?search=$searchTerm&per_page=20'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_consumerKey:$_consumerSecret'))}',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> products = jsonDecode(response.body);
        final result = products.map((product) => {
              'id': product['id'],
              'name': product['name'],
              'price': double.tryParse(product['price']) ?? 0.0,
              'image': product['images'].isNotEmpty ? product['images'][0]['src'] : null,
              'type': product['type'],
              'variations': product['variations'],
              'stock_status': product['stock_status'] ?? 'outofstock',
            }).toList();
        await logToFile('Produtos buscados: $result');
        return result;
      } else {
        throw Exception('Erro ao buscar produtos: ${response.statusCode} - ${response.body}');
      }
    } catch (error) {
      await logToFile('Erro ao buscar produtos: $error');
      throw Exception('Erro ao buscar produtos: $error');
    }
  }

  Future<List<Map<String, dynamic>>> fetchProductAttributes(int productId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/wp-json/wc/v3/products/$productId'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_consumerKey:$_consumerSecret'))}',
        },
      );
      await logToFile('Buscando atributos para produto ID $productId: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode == 200) {
        final product = jsonDecode(response.body);
        final attributes = product['attributes'] as List<dynamic>? ?? [];
        final result = attributes.map((attr) => {
              'name': attr['name'],
              'options': attr['options'] as List<dynamic>,
            }).toList();
        await logToFile('Atributos encontrados: $result');
        return result;
      } else {
        throw Exception('Erro ao buscar atributos do produto: ${response.statusCode} - ${response.body}');
      }
    } catch (error) {
      await logToFile('Erro ao buscar atributos do produto: $error');
      throw Exception('Erro ao buscar atributos do produto: $error');
    }
  }

  Future<List<Map<String, dynamic>>> fetchProductVariations(int productId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/wp-json/wc/v3/products/$productId/variations'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_consumerKey:$_consumerSecret'))}',
        },
      );
      await logToFile('Buscando variações para produto ID $productId: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> variations = jsonDecode(response.body);
        final result = variations.map((variation) => {
              'id': variation['id'],
              'attributes': variation['attributes'],
              'price': double.tryParse(variation['price']) ?? 0.0,
              'stock_status': variation['stock_status'] ?? 'outofstock',
            }).toList();
        await logToFile('Variações encontradas: $result');
        return result;
      } else {
        throw Exception('Erro ao buscar variações: ${response.statusCode} - ${response.body}');
      }
    } catch (error) {
      await logToFile('Erro ao buscar variações: $error');
      throw Exception('Erro ao buscar variações: $error');
    }
  }

  Future<Map<String, dynamic>> fetchStoreDecision({
    required String cep,
    required String shippingMethod,
    String pickupStore = '',
    String deliveryDate = '',
    String pickupDate = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_proxyCheckoutUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'cep': cep,
          'shipping_method': shippingMethod,
          'pickup_store': pickupStore,
          'delivery_date': deliveryDate,
          'pickup_date': pickupDate,
        }),
      );
      await logToFile('Buscando decisão da loja: cep=$cep, shipping_method=$shippingMethod, pickup_store=$pickupStore, delivery_date=$deliveryDate, pickup_date=$pickupDate, status=${response.statusCode}, body=${response.body}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erro ao determinar a loja: ${response.statusCode} - ${response.body}');
      }
    } catch (error) {
      await logToFile('Erro ao determinar a loja: $error');
      throw Exception('Erro ao determinar a loja: $error');
    }
  }

  Future<Map<String, dynamic>> validateCoupon({
    required String couponCode,
    required List<Map<String, dynamic>> products,
    required double shippingCost,
  }) async {
    try {
      final validLineItems = products.map((product) {
        final productId = product['id'];
        final quantity = product['quantity'] ?? 1;
        final price = product['price'] ?? 0.0;
        final variationId = product['variation_id'] != null && product['variation_id'] != 0 ? product['variation_id'] : null;
        if (productId == null || productId is! int || productId <= 0) {
          throw Exception('ID do produto inválido: $productId');
        }
        if (quantity is! int || quantity <= 0) {
          throw Exception('Quantidade inválida para o produto ID $productId: $quantity');
        }
        if (price is! num || price <= 0) {
          throw Exception('Preço inválido para o produto ID $productId: $price');
        }
        if (variationId != null && (variationId is! int || variationId <= 0)) {
          throw Exception('ID da variação inválido para o produto ID $productId: $variationId');
        }
        final lineItem = <String, dynamic>{
          'product_id': productId,
          'quantity': quantity,
          'subtotal': (price * quantity).toString(),
          'total': (price * quantity).toString(),
        };
        if (variationId != null) {
          lineItem['variation_id'] = variationId;
        }
        return lineItem;
      }).toList();
      final payload = {
        'line_items': validLineItems,
        'shipping_lines': [
          {
            'method_id': 'flat_rate',
            'method_title': 'Taxa de Entrega',
            'total': shippingCost.toString(),
          }
        ],
        'coupon_lines': [
          {
            'code': couponCode,
          }
        ],
      };
      await logToFile('Validando cupom: payload=${jsonEncode(payload)}');
      final response = await http.post(
        Uri.parse('$_baseUrl/wp-json/wc/v3/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_consumerKey:$_consumerSecret'))}',
        },
        body: jsonEncode(payload),
      );
      await logToFile('Resposta validação cupom: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode == 201) {
        final order = jsonDecode(response.body);
        final subtotal = products.fold<double>(0.0, (sum, product) => sum + ((product['price'] ?? 0.0) * (product['quantity'] ?? 1))) + shippingCost;
        final totalWithDiscount = double.tryParse(order['total']) ?? subtotal;
        final discount = subtotal - totalWithDiscount;
        await http.delete(
          Uri.parse('$_baseUrl/wp-json/wc/v3/orders/${order['id']}'),
          headers: {
            'Authorization': 'Basic ${base64Encode(utf8.encode('$_consumerKey:$_consumerSecret'))}',
          },
        );
        await logToFile('Cupom validado: subtotal=$subtotal, totalWithDiscount=$totalWithDiscount, discount=$discount');
        return {
          'is_valid': true,
          'discount_amount': discount,
          'total_with_discount': totalWithDiscount,
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'is_valid': false,
          'error_message': error['message'] ?? 'Cupom inválido ou não aplicável',
        };
      }
    } catch (error) {
      await logToFile('Erro ao validar cupom: $error');
      return {
        'is_valid': false,
        'error_message': 'Erro ao validar o cupom: $error',
      };
    }
  }

  Future<Map<String, dynamic>> createOrder({
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String billingCompany,
    required List<Map<String, dynamic>> products,
    required String shippingMethod,
    required String storeFinal,
    required String pickupStoreId,
    required String billingPostcode,
    required String billingAddress1,
    required String billingNumber,
    required String billingAddress2,
    required String billingNeighborhood,
    required String billingCity,
    required double shippingCost,
    required String paymentMethod,
    required String customerNotes,
    required String schedulingDate,
    required String schedulingTime,
    required String couponCode,
    required String paymentAccountStripe,
    required String paymentAccountPagarme,
  }) async {
    try {
      if (shippingMethod != 'delivery' && shippingMethod != 'pickup') {
        throw Exception('Método de entrega inválido: $shippingMethod. Deve ser "delivery" ou "pickup".');
      }
      final effectiveShippingCost = shippingMethod == 'pickup' ? 0.0 : shippingCost;
      final lineItems = products.map((product) {
        final productId = product['id'];
        final quantity = product['quantity'] ?? 1;
        final price = product['price'] ?? 0.0;
        final variationId = product['variation_id'] != null && product['variation_id'] != 0 ? product['variation_id'] : null;
        if (productId == null || productId is! int || productId <= 0) {
          throw Exception('ID do produto inválido: $productId');
        }
        if (quantity is! int || quantity <= 0) {
          throw Exception('Quantidade inválida para o produto ID $productId: $quantity');
        }
        if (price is! num || price <= 0) {
          throw Exception('Preço inválido para o produto ID $productId: $price');
        }
        final lineItem = {
          'product_id': productId,
          'name': product['name'],
          'quantity': quantity,
          'subtotal': (price * quantity).toStringAsFixed(2),
          'total': (price * quantity).toStringAsFixed(2),
        };
        if (variationId != null) {
          lineItem['variation_id'] = variationId;
          lineItem['meta_data'] = (product['variation_attributes'] as List<dynamic>?)?.map((attr) => {
                'key': attr['name'],
                'value': attr['option'],
              }).toList() ?? [];
        }
        return lineItem;
      }).toList();
      final effectiveEmail = customerEmail.isNotEmpty ? customerEmail : 'orders@aogosto.com.br';
      final cleanedCustomerName = customerName.trim().replaceAll(RegExp(r'\s+'), ' ');
      final nameParts = cleanedCustomerName.split(' ').where((part) => part.isNotEmpty).toList();
      final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      final orderStatus = (paymentMethod == 'pagarme_custom_pix' ||
              paymentMethod == 'stripe' ||
              paymentMethod == 'stripe_cc' ||
              paymentMethod == 'eh_stripe_pay')
          ? 'pending'
          : 'processing';
      final payload = {
        'payment_method': paymentMethod,
        'payment_method_title': {
          'pagarme_custom_pix': 'Pix On-line (Aprovação Imediata)',
          'stripe': 'Cartão de Crédito On-line',
          'stripe_cc': 'Cartão de Crédito On-line',
          'eh_stripe_pay': 'Cartão de Crédito On-line',
          'cod': 'Dinheiro na Entrega',
          'custom_729b8aa9fc227ff': 'Cartão na Entrega',
          'custom_e876f567c151864': 'Vale Alimentação',
        }[paymentMethod] ?? 'Método Desconhecido',
        'billing': {
          'first_name': firstName,
          'last_name': lastName,
          'company': billingCompany,
          'postcode': billingPostcode,
          'address_1': billingAddress1,
          'address_2': billingAddress2,
          'city': billingCity,
          'state': 'MG',
          'country': 'BR',
          'email': effectiveEmail,
          'phone': customerPhone,
        },
        'shipping': {
          'first_name': firstName,
          'last_name': lastName,
          'postcode': billingPostcode,
          'address_1': billingAddress1,
          'number': billingNumber,
          'address_2': billingAddress2,
          'neighborhood': billingNeighborhood,
          'city': billingCity,
          'state': 'MG',
          'country': 'BR',
        },
        'line_items': lineItems,
        'shipping_lines': [
          {
            'method_id': shippingMethod == 'delivery' ? 'flat_rate' : 'local_pickup',
            'method_title': shippingMethod == 'delivery' ? 'Motoboy' : 'Retirada na Unidade Barreiro',
            'total': effectiveShippingCost.toStringAsFixed(2),
          }
        ],
        'meta_data': [
          {'key': '_store_final', 'value': storeFinal},
          {'key': '_effective_store_final', 'value': storeFinal},
          {'key': '_billing_number', 'value': billingNumber},
          {'key': '_billing_neighborhood', 'value': billingNeighborhood},
          {'key': '_payment_account_stripe', 'value': paymentAccountStripe},
          {'key': '_payment_account_pagarme', 'value': paymentAccountPagarme},
          {'key': '_is_future_date', 'value': schedulingDate != DateFormat('yyyy-MM-dd').format(DateTime.now()) ? 'yes' : 'no'},
          if (shippingMethod == 'pickup') ...[
            {'key': '_shipping_pickup_stores', 'value': storeFinal},
            {'key': '_shipping_pickup_store_id', 'value': pickupStoreId},
            {'key': 'pickup_date', 'value': schedulingDate},
            {'key': 'pickup_time', 'value': schedulingTime},
          ],
          if (shippingMethod == 'delivery') ...[
            {'key': 'delivery_date', 'value': schedulingDate},
            {'key': 'delivery_time', 'value': schedulingTime},
          ],
          {'key': 'delivery_type', 'value': shippingMethod},
        ],
        'customer_note': customerNotes.isNotEmpty ? customerNotes : null,
        'status': orderStatus,
        if (couponCode.isNotEmpty)
          'coupon_lines': [
            {'code': couponCode},
          ],
      };
      await logToFile('Criando pedido: payload=${jsonEncode(payload)}');
      final response = await http.post(
        Uri.parse('$_baseUrl/wp-json/wc/v3/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_consumerKey:$_consumerSecret'))}',
        },
        body: jsonEncode(payload),
      );
      await logToFile('Resposta criação pedido: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erro ao criar pedido: ${response.statusCode} - ${response.body}');
      }
    } catch (error) {
      await logToFile('Erro ao criar pedido: $error');
      throw Exception('Erro ao criar pedido: $error');
    }
  }
}