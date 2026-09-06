import 'dart:convert';

import '../services/api_service.dart';

class CardapioRepository {
  dynamic _json(dynamic response) => response.body.trim().isEmpty
      ? <String, dynamic>{}
      : jsonDecode(response.body);

  Exception _erro(dynamic response, String padrao) {
    final body = _json(response);
    return Exception(
      body is Map ? (body['detail']?.toString() ?? padrao) : padrao,
    );
  }

  Future<List<Map<String, dynamic>>> listar(int lojaId) async {
    final response = await ApiService.get('/lojas/$lojaId/cardapios');
    if (response.statusCode != 200)
      throw _erro(response, 'Não foi possível carregar os cardápios.');
    return (_json(response) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> criar(
    int lojaId,
    String nome,
    String tipo,
  ) async {
    final response = await ApiService.post('/lojas/$lojaId/cardapios', {
      'nmcardapio': nome,
      'tipocardapio': tipo,
      'prioridade': tipo == 'PRINCIPAL' ? 100 : 10,
    });
    if (response.statusCode != 201)
      throw _erro(response, 'Não foi possível criar o cardápio.');
    return Map<String, dynamic>.from(_json(response));
  }

  Future<Map<String, dynamic>> novaVersao(int cardapioId) async {
    final response = await ApiService.post(
      '/cardapios/$cardapioId/nova-versao',
      const {},
    );
    if (response.statusCode != 201)
      throw _erro(response, 'Não foi possível criar a versão.');
    return Map<String, dynamic>.from(_json(response));
  }

  Future<void> salvarConteudo(
    int versaoId,
    List<Map<String, dynamic>> categorias,
  ) async {
    final response = await ApiService.put(
      '/cardapios/versoes/$versaoId/conteudo',
      {'categorias': categorias},
    );
    if (response.statusCode != 200)
      throw _erro(response, 'Não foi possível atualizar o cardápio.');
  }

  Future<String> publicar(int versaoId, {bool aposAsaas = true}) async {
    final response = await ApiService.post(
      '/cardapios/versoes/$versaoId/publicar',
      {'publicar_apos_aprovacao': aposAsaas},
    );
    if (response.statusCode != 200)
      throw _erro(response, 'Não foi possível publicar o cardápio.');
    return (Map<String, dynamic>.from(_json(response))['mensagem'] ??
            'Cardápio publicado.')
        .toString();
  }

  Future<int> reajustar(
    int versaoId,
    double percentual, {
    int? categoriaId,
  }) async {
    final response =
        await ApiService.post('/cardapios/versoes/$versaoId/reajustar', {
          'categoria_id': categoriaId,
          'tipoajuste': 'PERCENTUAL',
          'operacao': percentual >= 0 ? 'AUMENTO' : 'REDUCAO',
          'valorajuste': percentual.abs(),
          'arredondamento': 2,
        });
    if (response.statusCode != 200)
      throw _erro(response, 'Não foi possível reajustar os preços.');
    return int.tryParse(
          '${Map<String, dynamic>.from(_json(response))['itens_alterados']}',
        ) ??
        0;
  }
}
