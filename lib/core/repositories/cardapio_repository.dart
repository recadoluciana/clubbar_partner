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

  Future<List<Map<String, dynamic>>> listarPadroes(int organizacaoId) async {
    final response = await ApiService.get(
      '/organizacoes/$organizacaoId/cardapios-padrao',
    );
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível carregar os cardápios padrão.');
    }
    return (_json(response) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> criarPadrao(
    int organizacaoId,
    String nome,
    String tipo,
  ) async {
    final response = await ApiService.post(
      '/organizacoes/$organizacaoId/cardapios-padrao',
      {'nmcardapio': nome, 'tipocardapio': tipo, 'prioridade': 0},
    );
    if (response.statusCode != 201) {
      throw _erro(response, 'Não foi possível criar o cardápio padrão.');
    }
    return Map<String, dynamic>.from(_json(response));
  }

  Future<List<Map<String, dynamic>>> listarItensPadrao(
    int organizacaoId,
    int modeloId,
  ) async {
    final response = await ApiService.get(
      '/organizacoes/$organizacaoId/cardapios-padrao/$modeloId/itens',
    );
    if (response.statusCode != 200)
      throw _erro(
        response,
        'Não foi possível carregar os produtos do cardápio.',
      );
    return (_json(response) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listarCategoriasOrganizacao(
    int organizacaoId,
  ) async {
    final response = await ApiService.get(
      '/organizacoes/$organizacaoId/categorias',
    );
    if (response.statusCode != 200) {
      throw _erro(
        response,
        'Não foi possível carregar as categorias da empresa.',
      );
    }
    return (_json(response) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['sitcategoria'] == 'ATIVA')
        .toList();
  }

  Future<void> adicionarItemPadrao(
    int organizacaoId,
    int modeloId,
    Map<String, dynamic> dados,
  ) async {
    final response = await ApiService.post(
      '/organizacoes/$organizacaoId/cardapios-padrao/$modeloId/itens',
      dados,
    );
    if (response.statusCode != 201)
      throw _erro(response, 'Não foi possível adicionar o produto.');
  }

  Future<void> removerItemPadrao(
    int organizacaoId,
    int modeloId,
    int itemId,
  ) async {
    final response = await ApiService.delete(
      '/organizacoes/$organizacaoId/cardapios-padrao/$modeloId/itens/$itemId',
    );
    if (response.statusCode != 204)
      throw _erro(response, 'Não foi possível remover o produto.');
  }

  Future<void> alterarProdutoPadrao(
    int organizacaoId,
    int modeloId,
    int itemId,
    Map<String, dynamic> dados,
  ) async {
    final response = await ApiService.put(
      '/organizacoes/$organizacaoId/cardapios-padrao/$modeloId/itens/$itemId',
      dados,
    );
    if (response.statusCode != 200)
      throw _erro(response, 'Não foi possível alterar o produto.');
  }

  Future<Map<String, dynamic>> associar(
    int lojaId,
    int cardapioModeloId,
  ) async {
    final response = await ApiService.post(
      '/lojas/$lojaId/cardapios/associar',
      {'cardapiomodelo_id': cardapioModeloId, 'prioridade': 10},
    );
    if (response.statusCode != 201) {
      throw _erro(response, 'Não foi possível usar o cardápio nesta loja.');
    }
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

  Future<String> publicar(int versaoId) async {
    final response = await ApiService.post(
      '/cardapios/versoes/$versaoId/publicar',
      {},
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
