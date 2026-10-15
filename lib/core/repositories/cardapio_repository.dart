import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

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
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível carregar os cardápios.');
    }
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
    });
    if (response.statusCode != 201) {
      throw _erro(response, 'Não foi possível criar o cardápio.');
    }
    return Map<String, dynamic>.from(_json(response));
  }

  Future<List<Map<String, dynamic>>> listarPadroes(int organizacaoId) async {
    return listarCardapiosEmpresa(organizacaoId);
  }

  Future<List<Map<String, dynamic>>> listarCardapiosEmpresa(
    int organizacaoId,
  ) async {
    final response = await ApiService.get(
      '/organizacoes/$organizacaoId/cardapios',
    );
    if (response.statusCode != 200) {
      throw _erro(
        response,
        'Não foi possível carregar os cardápios da empresa.',
      );
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
      '/organizacoes/$organizacaoId/cardapios',
      {'nmcardapio': nome, 'tipocardapio': tipo},
    );
    if (response.statusCode != 201) {
      throw _erro(response, 'Não foi possível criar o cardápio.');
    }
    return Map<String, dynamic>.from(_json(response));
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

  Future<List<Map<String, dynamic>>> listarProdutosPadraoOrganizacao(
    int organizacaoId,
  ) async {
    final response = await ApiService.get(
      '/organizacoes/$organizacaoId/produtos',
    );
    if (response.statusCode != 200) {
      throw _erro(
        response,
        'Não foi possível carregar os produtos da empresa.',
      );
    }
    return (_json(response) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> criarProdutoPadraoOrganizacao(
    int organizacaoId,
    Map<String, dynamic> dados,
  ) async {
    final response = await ApiService.post(
      '/organizacoes/$organizacaoId/produtos',
      dados,
    );
    if (response.statusCode != 201) {
      throw _erro(response, 'Não foi possível cadastrar o produto.');
    }
    return Map<String, dynamic>.from(_json(response));
  }

  Future<Map<String, dynamic>> alterarProdutoPadraoOrganizacao(
    int organizacaoId,
    int produtoId,
    Map<String, dynamic> dados,
  ) async {
    final response = await ApiService.put(
      '/organizacoes/$organizacaoId/produtos/$produtoId',
      dados,
    );
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível alterar o produto.');
    }
    return Map<String, dynamic>.from(_json(response));
  }

  Future<void> excluirProdutoPadraoOrganizacao(int produtoId) async {
    final response = await ApiService.delete('/produtos/$produtoId');
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível excluir o produto.');
    }
  }

  Future<String> enviarFotoProdutoPadraoOrganizacao(
    int organizacaoId,
    XFile imagem,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '${ApiConfig.baseUrl}/organizacoes/$organizacaoId/produtos/foto',
      ),
    );
    final token = await StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final mime = lookupMimeType(imagem.name) ?? 'image/jpeg';
    final partes = mime.split('/');
    request.files.add(
      kIsWeb
          ? http.MultipartFile.fromBytes(
              'foto',
              await imagem.readAsBytes(),
              filename: imagem.name,
              contentType: MediaType(partes[0], partes[1]),
            )
          : await http.MultipartFile.fromPath(
              'foto',
              imagem.path,
              contentType: MediaType(partes[0], partes[1]),
            ),
    );
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível enviar a foto.');
    }
    return '${_json(response)['urlfotoproduto']}';
  }

  Future<Map<String, dynamic>> associar(int lojaId, int cardapioId) async {
    final response = await ApiService.post(
      '/lojas/$lojaId/cardapios/associar',
      {'cardapio_id': cardapioId, 'prioridade': 10},
    );
    if (response.statusCode != 201) {
      throw _erro(response, 'Não foi possível usar o cardápio nesta loja.');
    }
    return Map<String, dynamic>.from(_json(response));
  }

  Future<void> removerAssociacao(int lojaId, int cardapioId) async {
    final response = await ApiService.delete(
      '/lojas/$lojaId/cardapios/$cardapioId/associacao',
    );
    if (response.statusCode != 204) {
      throw _erro(response, 'Não foi possível remover o cardápio da loja.');
    }
  }

  Future<Map<String, dynamic>> novaVersao(int cardapioId) async {
    final response = await ApiService.post(
      '/cardapios/$cardapioId/nova-versao',
      const {},
    );
    if (response.statusCode != 201) {
      throw _erro(response, 'Não foi possível criar a versão.');
    }
    return Map<String, dynamic>.from(_json(response));
  }

  Future<void> excluirCardapio(int cardapioId) async {
    final response = await ApiService.delete('/cardapios/$cardapioId');
    if (response.statusCode != 204) {
      throw _erro(response, 'Não foi possível excluir o cardápio.');
    }
  }

  Future<Map<String, dynamic>> consultarVersao(int versaoId) async {
    final response = await ApiService.get('/cardapios/versoes/$versaoId');
    if (response.statusCode != 200) {
      throw _erro(
        response,
        'Não foi possível carregar o conteúdo do cardápio.',
      );
    }
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
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível atualizar o cardápio.');
    }
  }

  Future<String> publicar(int versaoId) async {
    final response = await ApiService.post(
      '/cardapios/versoes/$versaoId/publicar',
      {},
    );
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível publicar o cardápio.');
    }
    return (Map<String, dynamic>.from(_json(response))['mensagem'] ??
            'Cardápio publicado.')
        .toString();
  }

  Future<String> retirarPublicacao(int cardapioId) async {
    final response = await ApiService.post(
      '/cardapios/$cardapioId/retirar-publicacao',
      const {},
    );
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível retirar a publicação.');
    }
    return (Map<String, dynamic>.from(_json(response))['mensagem'] ??
            'Publicação retirada.')
        .toString();
  }

  Future<List<Map<String, dynamic>>> listarProgramacoes(
    int cardapioId, {
    int? lojaId,
  }) async {
    final response = await ApiService.get(
      lojaId == null
          ? '/cardapios/$cardapioId/programacoes'
          : '/lojas/$lojaId/cardapios/$cardapioId/programacoes',
    );
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível carregar as programações.');
    }
    return (_json(response) as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> programarExibicao(
    int cardapioId, {
    int? lojaId,
    required DateTime inicio,
    required TimeOfDay horaInicio,
    DateTime? fim,
    TimeOfDay? horaFim,
  }) async {
    final caminho = lojaId == null
        ? '/cardapios/$cardapioId/programacoes'
        : '/lojas/$lojaId/cardapios/$cardapioId/programacoes';
    final response = await ApiService.post(caminho, {
      'dtinicio': inicio.toIso8601String().substring(0, 10),
      'dtfim': fim?.toIso8601String().substring(0, 10),
      'hrinicio': _horaApi(horaInicio),
      'hrfim': horaFim == null ? null : _horaApi(horaFim),
    });
    if (response.statusCode != 201) {
      throw _erro(response, 'Não foi possível programar a exibição.');
    }
  }

  String _horaApi(TimeOfDay hora) =>
      '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}:00';

  Future<void> removerProgramacao(
    int cardapioId,
    int programacaoId, {
    int? lojaId,
  }) async {
    final response = await ApiService.delete(
      lojaId == null
          ? '/cardapios/$cardapioId/programacoes/$programacaoId'
          : '/lojas/$lojaId/cardapios/$cardapioId/programacoes/$programacaoId',
    );
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível remover a programação.');
    }
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
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível reajustar os preços.');
    }
    return int.tryParse(
          '${Map<String, dynamic>.from(_json(response))['itens_alterados']}',
        ) ??
        0;
  }
}
