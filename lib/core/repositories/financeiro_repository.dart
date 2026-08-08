import 'dart:convert';

import '../services/api_service.dart';

class FinanceiroRepository {
  Future<Map<String, dynamic>> resumo(int lojaId) async {
    final response = await ApiService.get(
      '/financeiro/parceiro/resumo?loja_id=$lojaId',
    );
    if (response.statusCode != 200) throw Exception(_mensagem(response.body));
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>?> conta(int lojaId) async {
    final response = await ApiService.get(
      '/financeiro/lojas/$lojaId/conta-bancaria',
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) throw Exception(_mensagem(response.body));
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> salvarConta(int lojaId, Map<String, dynamic> dados) async {
    final response = await ApiService.put(
      '/financeiro/lojas/$lojaId/conta-bancaria',
      dados,
    );
    if (response.statusCode != 200) throw Exception(_mensagem(response.body));
  }

  String _mensagem(String body) {
    try {
      final data = jsonDecode(body);
      return data['detail']?.toString() ??
          'Erro ao processar dados financeiros.';
    } catch (_) {
      return 'Erro ao processar dados financeiros.';
    }
  }
}
