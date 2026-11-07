import 'dart:convert';

import '../services/api_service.dart';

class ReconciliacaoCancelamentosRepository {
  String _erro(String corpo, String padrao) {
    try {
      final dados = jsonDecode(corpo);
      if (dados is Map && dados['detail'] != null) {
        return dados['detail'].toString();
      }
    } catch (_) {}
    return padrao;
  }

  Future<List<Map<String, dynamic>>> listar(String provedor) async {
    final resposta = await ApiService.get(
      '/reconciliacao-cancelamentos?provedor=$provedor',
    );
    if (resposta.statusCode != 200) {
      throw Exception(
        _erro(resposta.body, 'Não foi possível consultar os cancelamentos.'),
      );
    }
    return (jsonDecode(resposta.body) as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> consultar(int vendaId, String provedor) async {
    final resposta = await ApiService.get(
      '/reconciliacao-cancelamentos/$vendaId/${provedor == 'MERCADO_PAGO' ? 'mercado-pago' : 'asaas'}',
    );
    if (resposta.statusCode != 200) {
      throw Exception(
        _erro(resposta.body, 'Não foi possível consultar o Asaas.'),
      );
    }
    return Map<String, dynamic>.from(jsonDecode(resposta.body) as Map);
  }

  Future<String> concluir(int vendaId) => _executar(
    '/reconciliacao-cancelamentos/$vendaId/concluir',
    'Não foi possível concluir o cancelamento.',
  );

  Future<String> reativar(int vendaId) => _executar(
    '/reconciliacao-cancelamentos/$vendaId/reativar',
    'Não foi possível reativar os itens.',
  );

  Future<String> _executar(String endpoint, String padrao) async {
    final resposta = await ApiService.post(endpoint, const <String, dynamic>{});
    if (resposta.statusCode != 200) {
      throw Exception(_erro(resposta.body, padrao));
    }
    final dados = Map<String, dynamic>.from(jsonDecode(resposta.body) as Map);
    return dados['mensagem']?.toString() ?? 'Operação concluída.';
  }
}
