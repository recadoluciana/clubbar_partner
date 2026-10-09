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
    required int minutoDuracao,
  }) async {
    final dados = {
      'atracao_id': atracaoId,
      'ordem': ordem,
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

  Future<List<Map<String, dynamic>>> listarModalidadesPadrao(
    int modeloId,
  ) async {
    final response = await ApiService.get(
      '/eventos-modelos/$modeloId/modalidades',
    );
    if (response.statusCode != 200) {
      throw Exception(
        _mensagemErro(
          response.body,
          'Não foi possível carregar as modalidades do evento.',
        ),
      );
    }
    return (jsonDecode(response.body) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  Future<void> salvarModalidadesPadrao({
    required int modeloId,
    required Map<int, Set<int>> beneficiosPorModalidade,
  }) async {
    final response = await ApiService.put(
      '/eventos-modelos/$modeloId/modalidades',
      {
        'modalidades': beneficiosPorModalidade.entries
            .map(
              (entry) => {
                'modalidade_id': entry.key,
                'beneficios_ids': entry.value.toList(),
              },
            )
            .toList(),
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _mensagemErro(
          response.body,
          'Não foi possível salvar as modalidades do evento.',
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

  Future<String> publicarEvento(int eventoId) async {
    final response = await ApiService.post('/eventos/$eventoId/publicar', {});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _mensagemErro(response.body, 'Não foi possível publicar o evento.'),
      );
    }
    return (jsonDecode(response.body)['mensagem'] ?? 'Evento publicado.')
        .toString();
  }

  Future<String> despublicarEvento(int eventoId) async {
    final response = await ApiService.post(
      '/eventos/$eventoId/despublicar',
      {},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _mensagemErro(
          response.body,
          'Não foi possível retirar a publicação do evento.',
        ),
      );
    }
    return (jsonDecode(response.body)['mensagem'] ??
            'Publicação do evento retirada.')
        .toString();
  }

  Future<String> publicarEventos(List<int> eventoIds) async {
    final response = await ApiService.post('/eventos/publicar', {
      'evento_ids': eventoIds,
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _mensagemErro(response.body, 'Não foi possível publicar os eventos.'),
      );
    }
    return (jsonDecode(response.body)['mensagem'] ?? 'Eventos publicados.')
        .toString();
  }

  Future<void> atualizarPoliticaEventoAgendado({
    required int eventoId,
    required String politicaCancelamento,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${ApiConfig.baseUrl}/eventos/$eventoId'),
    );
    final token = await StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['dspoliticacancelamento'] = politicaCancelamento;

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _mensagemErro(body, 'Não foi possível atualizar a política do evento.'),
      );
    }
  }

  /// Atualiza somente esta ocorrência da agenda. Não altera o evento padrão
  /// nem outras datas que tenham sido criadas a partir dele.
  Future<void> atualizarEventoAgendado({
    required int eventoId,
    required String titulo,
    XFile? imagem,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${ApiConfig.baseUrl}/eventos/$eventoId'),
    );
    final token = await StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['nmtituloevento'] = titulo.trim();
    if (imagem != null) {
      request.files.add(await _montarArquivoImagem('urlbannerevento', imagem));
    }

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _mensagemErro(body, 'Não foi possível atualizar o evento agendado.'),
      );
    }
  }

  Future<void> atualizarHorarioEventoAgendado({
    required int eventoId,
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${ApiConfig.baseUrl}/eventos/$eventoId'),
    );
    final token = await StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['dtinicioevento'] = inicio.toIso8601String();
    request.fields['dtfimevento'] = fim.toIso8601String();

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _mensagemErro(body, 'Não foi possível atualizar o horário do evento.'),
      );
    }
  }

  Future<void> agendar({
    required int modeloId,
    required int lojaId,
    required DateTime inicio,
    required DateTime fim,
    required int capacidade,
    required String nomeSetorInicial,
    required double precoInteira,
    required String recorrencia,
    required int repeticoes,
    String? local,
    String? endereco,
  }) async {
    final response =
        await ApiService.post('/eventos-modelos/$modeloId/agendar', {
          'dtinicio': inicio.toIso8601String(),
          'dtfim': fim.toIso8601String(),
          'loja_id': lojaId,
          'capacidade': capacidade,
          'nome_setor_inicial': nomeSetorInicial.trim(),
          'preco_inteira': precoInteira,
          if (local != null && local.trim().isNotEmpty) 'local': local.trim(),
          if (endereco != null && endereco.trim().isNotEmpty)
            'endereco': endereco.trim(),
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

  Future<List<Evento>> listar() async {
    final response = await ApiService.get('/eventos-modelos');

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Evento.fromJson(e)).toList();
    }

    throw Exception('Erro ao listar eventos: ${response.body}');
  }

  /// Busca os dados próprios de uma ocorrência agendada, incluindo o local
  /// que será apresentado ao público.
  Future<Evento> obterEventoAgendado(int eventoId) async {
    final response = await ApiService.get('/eventos/$eventoId');
    if (response.statusCode == 200) {
      return Evento.fromJson(
        Map<String, dynamic>.from(jsonDecode(response.body) as Map),
      );
    }
    throw Exception(
      _mensagemErro(response.body, 'Não foi possível carregar o evento.'),
    );
  }

  Future<void> atualizarLocalEventoAgendado({
    required int eventoId,
    required String local,
    required String endereco,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${ApiConfig.baseUrl}/eventos/$eventoId'),
    );
    final token = await StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['nmlocalevento'] = local.trim();
    request.fields['dsendlocevento'] = endereco.trim();

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _mensagemErro(body, 'Não foi possível atualizar o local do evento.'),
      );
    }
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

  Future<int> criar({
    required int organizacaoId,
    required int produtoIdIngresso,
    required String titulo,
    String? descricao,
    String? politicaCancelamento,
    String tipoLocal = 'ESTABELECIMENTO',
    String? cep,
    String? dataInicio,
    String? dataFim,
    String? local,
    String? endereco,
    String? status,
    double precoPadrao = 0,
    XFile? imagem,
    Map<int, Set<int>>? beneficiosPorModalidade,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/eventos-modelos');

    final request = http.MultipartRequest('POST', uri);

    final token = await StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['organizacao_id'] = organizacaoId.toString();
    request.fields['produto_id_ingresso'] = produtoIdIngresso.toString();
    request.fields['nmtituloevento'] = titulo;

    if (descricao != null && descricao.isNotEmpty) {
      request.fields['dsdescevento'] = descricao;
    }
    if (politicaCancelamento != null) {
      request.fields['dspoliticacancelamento'] = politicaCancelamento;
    }
    request.fields['tipolocalevento'] = tipoLocal;
    if (cep != null && cep.isNotEmpty) request.fields['nrceplocalevento'] = cep;
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
    if (beneficiosPorModalidade != null) {
      request.fields['modalidades_json'] = jsonEncode({
        'modalidades': beneficiosPorModalidade.entries
            .map(
              (entry) => {
                'modalidade_id': entry.key,
                'beneficios_ids': entry.value.toList(),
              },
            )
            .toList(),
      });
    }

    if (imagem != null) {
      request.files.add(await _montarArquivoImagem('urlbannerevento', imagem));
    }

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_mensagemErro(body, 'Não foi possível criar o evento.'));
    }
    final dados = Map<String, dynamic>.from(jsonDecode(body) as Map);
    return (dados['eventomodelo_id'] as num?)?.toInt() ??
        (dados['evento_id'] as num?)?.toInt() ??
        0;
  }

  Future<void> atualizar({
    required int eventoId,
    String? titulo,
    String? descricao,
    String? politicaCancelamento,
    String? tipoLocal,
    String? cep,
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
    if (tipoLocal != null) request.fields['tipolocalevento'] = tipoLocal;
    if (cep != null) request.fields['nrceplocalevento'] = cep;
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
