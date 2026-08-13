import 'dart:convert';

import '../../core/services/api_service.dart';

class CaixaRepository {
  Map<String, dynamic> _map(String body) =>
      Map<String, dynamic>.from(jsonDecode(body) as Map);

  Never _erro(String body) {
    try {
      final data = _map(body);
      throw Exception(data['detail']?.toString() ?? body);
    } catch (e) {
      if (e is Exception && e.toString() != 'Exception: $body') rethrow;
      throw Exception(body);
    }
  }

  Future<Map<String, dynamic>> contexto() async {
    final response = await ApiService.get('/caixa/contexto');
    if (response.statusCode == 200) return _map(response.body);
    _erro(response.body);
  }

  Future<Map<String, dynamic>> carrinho() async {
    final response = await ApiService.get('/caixa/carrinho');
    if (response.statusCode == 200) return _map(response.body);
    _erro(response.body);
  }

  Future<void> adicionar(int produtoId) async {
    final response = await ApiService.post('/caixa/carrinho/itens', {
      'produto_id': produtoId,
      'quantidade': 1,
    });
    if (response.statusCode != 200 && response.statusCode != 201) {
      _erro(response.body);
    }
  }

  Future<Map<String, dynamic>> checkoutPix() async {
    final response = await ApiService.post('/caixa/checkout/pix', const {});
    if (response.statusCode == 200) return _map(response.body);
    _erro(response.body);
  }

  Future<Map<String, dynamic>> checkoutCartao() async {
    final response = await ApiService.post('/caixa/checkout/cartao', const {});
    if (response.statusCode == 200) return _map(response.body);
    _erro(response.body);
  }

  Future<Map<String, dynamic>> tickets(String checkoutId) async {
    final response = await ApiService.get(
      '/caixa/checkout/$checkoutId/tickets',
    );
    if (response.statusCode == 200) return _map(response.body);
    _erro(response.body);
  }
}
