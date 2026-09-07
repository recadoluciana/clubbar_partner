import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../core/config/api_config.dart';
import '../../models/evento.dart';
import '../../models/atracao.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class EventoRepository {
  Future<List<EventoModeloAtracao>> listarAtracoesPadrao(int modeloId) async {
    final response = await ApiService.get(
      '/eventos-modelos/$modeloId/atracoes',
    );
    if (response.statusCode != 200) {
      throw Exception(
        _mensagemErro(
          response.body,
          'Não foi possível listar as atrações padrão.',
        ),
      );
    }
    return (jsonDecode(response.body) as List)
        .map((e) => EventoModeloAtracao.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Atracao>> listarAtracoesDisponiveis(int modeloId) async {
    final response = await ApiService.get(
      '/eventos-modelos/$modeloId/atracoes-disponiveis',
    );
    if (response.statusCode != 200) {
      throw Exception(
        _mensagemErro(
          response.body,
          'Não foi possível listar as atrações cadastradas.',
        ),
      );
    }
    return (jsonDecode(response.body) as List)
        .map((e) => Atracao.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> salvarAtracaoPadrao({
    required int modeloId,
    EventoModeloAtracao? item,
    required int atracaoId,
    required int ordem,
    required int minutoInicio,
    required int minutoDuracao,
  }) async {
    final dados = {
      'atracao_id': atracaoId,
      'ordem': ordem,
      'nrminutoinicio': minutoInicio,
      'nrminutoduracao': minutoDuracao,
    };
    final response = item == null
        ? await ApiService.post('/eventos-modelos/$modeloId/atracoes', dados)
        : await ApiService.put('/eventos-modelos/atracoes/${item.id}', dados);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _mensagemErro(
          response.body,
          'Não foi possível salvar a atração padrão.',
        ),
      );
    }
  }

  Future<void> excluirAtracaoPadrao(int id) async {
    final response = await ApiService.delete('/eventos-modelos/atracoes/$id');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _mensagemErro(
          response.body,
          'Não foi possível excluir a atração padrão.',
        ),
      );
    }
  }

  Future<void> excluirOcorrencia(int eventoId) async {
    final response = await ApiService.delete('/eventos/$eventoId');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _mensagemErro(response.body, 'Não foi possível excluir esta data.'),
      );
    }
  }

  Future<void> agendar({
    required int modeloId,
    required DateTime inicio,
    required int capacidade,
    required String recorrencia,
    required int repeticoes,
  }) async {
    final response =
        await ApiService.post('/eventos-modelos/$modeloId/agendar', {
          'dtinicio': inicio.toIso8601String(),
          'capacidade': capacidade,
          'recorrencia': recorrencia,
          'repeticoes': repeticoes,
        });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _mensagemErro(
          response.body,
          'Não foi possível adicionar o evento à agenda.',
        ),
      );
    }
  }

  Future<List<Evento>> listar(int lojaId) async {
    final response = await ApiService.get('/eventos-modelos?loja_id=$lojaId');

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Evento.fromJson(e)).toList();
    }

    throw Exception('Erro ao listar eventos: ${response.body}');
  }

  Future<http.MultipartFile> _montarArquivoImagem(
    String fieldName,
    XFile imagem,
  ) async {
    final mimeType =
        lookupMimeType(imagem.name) ??
        lookupMimeType(imagem.path) ??
        'image/jpeg';

    final parts = mimeType.split('/');

    if (kIsWeb) {
      final bytes = await imagem.readAsBytes();

      return http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: imagem.name,
        contentType: MediaType(parts[0], parts[1]),
      );
    } else {
      return await http.MultipartFile.fromPath(
        fieldName,
        imagem.path,
        contentType: MediaType(parts[0], parts[1]),
      );
    }
  }

  Future<void> criar({
    required int organizacaoId,
    required int lojaId,
    required int produtoIdIngresso,
    required String titulo,
    String? descricao,
    String? politicaCancelamento,
    String? politicaReembolso,
    String? politicaCashback,
    String? dataInicio,
    String? dataFim,
    String? local,
    String? endereco,
    String? status,
    double precoPadrao = 0,
    XFile? imagem,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/eventos-modelos');

    final request = http.MultipartRequest('POST', uri);

    final token = await StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['organizacao_id'] = organizacaoId.toString();
    request.fields['loja_id'] = lojaId.toString();
    request.fields['produto_id_ingresso'] = produtoIdIngresso.toString();
    request.fields['nmtituloevento'] = titulo;

    if (descricao != null && descricao.isNotEmpty) {
      request.fields['dsdescevento'] = descricao;
    }
    if (politicaCancelamento != null) {
      request.fields['dspoliticacancelamento'] = politicaCancelamento;
    }
    if (politicaReembolso != null) {
      request.fields['dspoliticareembolso'] = politicaReembolso;
    }
    if (politicaCashback != null) {
      request.fields['dspoliticacashback'] = politicaCashback;
    }
    if (local != null && local.isNotEmpty) {
      request.fields['nmlocalevento'] = local;
    }
    if (endereco != null && endereco.isNotEmpty) {
      request.fields['dsendlocevento'] = endereco;
    }
    if (status != null && status.isNotEmpty) {
      request.fields['statusevento'] = status;
    }
    request.fields['vrprecolote'] = precoPadrao.toStringAsFixed(2);

    if (imagem != null) {
      request.files.add(await _montarArquivoImagem('urlbannerevento', imagem));
    }

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_mensagemErro(body, 'Não foi possível criar o evento.'));
    }
  }

  Future<void> atualizar({
    required int eventoId,
    String? titulo,
    String? descricao,
    String? politicaCancelamento,
    String? politicaReembolso,
    String? politicaCashback,
    String? dataInicio,
    String? dataFim,
    String? local,
    String? endereco,
    String? status,
    double? precoPadrao,
    XFile? imagem,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/eventos-modelos/$eventoId');

    final request = http.MultipartRequest('PUT', uri);

    final token = await StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (titulo != null && titulo.isNotEmpty) {
      request.fields['nmtituloevento'] = titulo;
    }
    if (descricao != null) {
      request.fields['dsdescevento'] = descricao;
    }
    if (politicaCancelamento != null) {
      request.fields['dspoliticacancelamento'] = politicaCancelamento;
    }
    if (politicaReembolso != null) {
      request.fields['dspoliticareembolso'] = politicaReembolso;
    }
    if (politicaCashback != null) {
      request.fields['dspoliticacashback'] = politicaCashback;
    }
    if (local != null) {
      request.fields['nmlocalevento'] = local;
    }
    if (endereco != null) {
      request.fields['dsendlocevento'] = endereco;
    }
    if (status != null && status.isNotEmpty) {
      request.fields['statusevento'] = status;
    }
    if (precoPadrao != null) {
      request.fields['vrprecolote'] = precoPadrao.toStringAsFixed(2);
    }

    if (imagem != null) {
      request.files.add(await _montarArquivoImagem('urlbannerevento', imagem));
    }

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception(
        _mensagemErro(body, 'Não foi possível atualizar o evento.'),
      );
    }
  }

  Future<void> excluir(int eventoId) async {
    final response = await ApiService.delete('/eventos-modelos/$eventoId');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Erro ao excluir evento: ${response.body}');
    }
  }

  String _mensagemErro(String body, String padrao) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
    } catch (_) {}
    return body.trim().isEmpty ? padrao : body;
  }
}
