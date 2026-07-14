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

  String mensagemErroAmigavel(Object e) {
    final texto = e.toString();

    final textoLower = texto.toLowerCase();

    if (textoLower.contains('socketexception') ||
        textoLower.contains('failed host lookup') ||
        textoLower.contains('connection refused')) {
      return 'Sem conexão com a internet ou servidor indisponível.';
    }

    if (textoLower.contains('timeout')) {
      return 'O servidor demorou para responder. Tente novamente.';
    }

    if (textoLower.contains('502') ||
        textoLower.contains('503') ||
        textoLower.contains('500')) {
      return 'Sistema em atualização. Tente novamente em instantes.';
    }

    // Preserva a mensagem amigável enviada pela API
    if (texto.startsWith('Exception: ')) {
      return texto.replaceFirst('Exception: ', '');
    }

    return texto;
  }

  static Future<Map<String, dynamic>> confirmarRetirada({
    required int itvendaId,
  }) async {
    final usuarioId = await StorageService.getUsuarioId();

    if (usuarioId == null || usuarioId == 0) {
      throw Exception('Usuário não identificado. Faça login novamente.');
    }

    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/entregas/$itvendaId/entregarproduto?usuario_id=$usuarioId',
      ),
      headers: await _headers(),
    );

    final data = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    return data;
  }

  static Future<Map<String, dynamic>> buscarProdutoPorToken({
    required String token,
  }) async {
    try {
      final tokenLimpo = token.trim();

      if (tokenLimpo.isEmpty) {
        throw Exception('Token do produto não informado.');
      }

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/entregas/buscar-por-token/'
        '${Uri.encodeComponent(tokenLimpo)}',
      );

      final response = await http.get(uri, headers: await _headers());

      final respostaTexto = response.body.trim();

      final contentType = response.headers['content-type']?.toLowerCase() ?? '';

      final retornouHtml =
          contentType.contains('text/html') ||
          respostaTexto.toLowerCase().startsWith('<!doctype html') ||
          respostaTexto.toLowerCase().startsWith('<html');

      if (retornouHtml) {
        final trechoResposta = respostaTexto.length > 600
            ? respostaTexto.substring(0, 600)
            : respostaTexto;

        throw Exception(
          'URL:\n$uri\n\n'
          'BASE URL:\n${ApiConfig.baseUrl}\n\n'
          'STATUS:\n${response.statusCode}\n\n'
          'CONTENT-TYPE:\n$contentType\n\n'
          'RESPOSTA:\n$trechoResposta',
        );
      }

      Map<String, dynamic> body = {};

      if (respostaTexto.isNotEmpty) {
        final decoded = jsonDecode(respostaTexto);

        if (decoded is Map<String, dynamic>) {
          body = decoded;
        } else if (decoded is Map) {
          body = Map<String, dynamic>.from(decoded);
        } else {
          throw Exception(
            'A API retornou um formato inesperado.\n\n'
            'URL:\n$uri\n\n'
            'Resposta:\n$respostaTexto',
          );
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          body['detail']?.toString() ??
              body['message']?.toString() ??
              'Não foi possível consultar o produto.\n\n'
                  'URL:\n$uri\n\n'
                  'Status: ${response.statusCode}',
        );
      }

      return body;
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  static Future<Map<String, dynamic>> confirmarRetiradaPorToken({
    required String token,
  }) async {
    try {
      final usuarioId = await StorageService.getUsuarioId();

      if (usuarioId == null || usuarioId == 0) {
        throw Exception(
          'Usuário responsável não identificado. Faça login novamente.',
        );
      }

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/entregas/entregar-por-token/'
        '${Uri.encodeComponent(token)}'
        '?usuario_id=$usuarioId',
      );

      final response = await http.post(uri, headers: await _headers());

      final dynamic decoded = response.body.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);

      final body = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};

      if (response.statusCode != 200) {
        throw Exception(
          body['detail']?.toString() ??
              'Não foi possível confirmar a retirada.',
        );
      }

      return body;
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
