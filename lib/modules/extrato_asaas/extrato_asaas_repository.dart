import 'dart:convert';

import '../../core/services/api_service.dart';

class ExtratoAsaasRepository {
  Future<Map<String, dynamic>> consultar(
    int organizacaoId, {
    required DateTime inicio,
    required DateTime fim,
  }) async {
    String data(DateTime valor) =>
        '${valor.year.toString().padLeft(4, '0')}-${valor.month.toString().padLeft(2, '0')}-${valor.day.toString().padLeft(2, '0')}';
    final resposta = await ApiService.get(
      '/titular-financeiro/organizacao/$organizacaoId/extrato-asaas'
      '?data_inicio=${data(inicio)}&data_fim=${data(fim)}&limite=100',
    );
    final body = resposta.body.trim().isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(resposta.body) as Map);
    if (resposta.statusCode != 200) {
      throw Exception(body['detail']?.toString() ?? 'Não foi possível consultar o extrato.');
    }
    return body;
  }
}
