import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'storage_service.dart';

class ApiService {
  static Future<Map<String, String>> _headers() async {
    final token = await StorageService.getToken();

    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String endpoint) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    return http.get(url, headers: await _headers());
  }

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    return http.post(url, headers: await _headers(), body: jsonEncode(body));
  }

  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    return http.put(url, headers: await _headers(), body: jsonEncode(body));
  }

  static Future<http.Response> delete(String endpoint) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    return http.delete(url, headers: await _headers());
  }

  static Future<void> confirmarRetirada({required int itvendaId}) async {
    final usuarioId = await StorageService.getUsuarioId();

    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/entregas/$itvendaId/entregarproduto?usuario_id=$usuarioId',
      ),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }
  }
}
