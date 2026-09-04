import 'dart:convert';

import '../services/api_service.dart';

class CardapioPadraoRepository {
  Map<String, dynamic> _mapaResposta(dynamic resposta) {
    if (resposta.body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(resposta.body);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  Exception _erro(dynamic resposta, String padrao) {
    final body = _mapaResposta(resposta);
    return Exception(body['detail']?.toString() ?? padrao);
  }

  Future<Map<String, dynamic>> consultar(int organizacaoId) async {
    final response = await ApiService.get(
      '/organizacoes/$organizacaoId/cardapio-padrao',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _erro(response, 'Não foi possível carregar o cardápio padrão.');
    }
    return _mapaResposta(response);
  }

  Future<Map<String, dynamic>> copiarDaLoja(
    int organizacaoId,
    int lojaId,
  ) async {
    final response = await ApiService.post(
      '/organizacoes/$organizacaoId/cardapio-padrao/copiar-da-loja/$lojaId',
      const {},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _erro(response, 'Não foi possível definir o cardápio padrão.');
    }
    return _mapaResposta(response);
  }

  Future<Map<String, dynamic>> importar(int lojaId) async {
    final response = await ApiService.post(
      '/lojas/$lojaId/cardapio-padrao/importar',
      const {},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _erro(response, 'Não foi possível importar o cardápio padrão.');
    }
    return _mapaResposta(response);
  }
}
