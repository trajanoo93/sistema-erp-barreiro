import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://script.google.com/macros/s/AKfycbxhnXFW0hPkxCzWQWTFAyOMHo2khkgUwd94AsM-ixXueTV4ZX7paUCmVNbRl9hOHW4/exec?action=ReadCDBarreiro';

  static Future<List<dynamic>> fetchPedidos() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data;
      } else {
        throw Exception('Falha ao carregar pedidos: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Falha ao carregar pedidos: $e');
    }
  }
}
