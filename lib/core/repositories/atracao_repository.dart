import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../models/atracao.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AtracaoRepository {
  Future<List<EstiloMusical>> listarEstilos() async {
    final r = await ApiService.get('/estilos-musicais');
    if (r.statusCode != 200) throw Exception(_erro(r.body));
    return (jsonDecode(r.body) as List)
        .map((e) => EstiloMusical.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<EstiloMusical>> listarEstilosParaGerenciar() async {
    final r = await ApiService.get('/estilos-musicais/gerenciar');
    if (r.statusCode != 200) throw Exception(_erro(r.body));
    return (jsonDecode(r.body) as List)
        .map((e) => EstiloMusical.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<EstiloMusical>> listarCatalogoEstilos() async {
    final r = await ApiService.get('/estilos-musicais/catalogo');
    if (r.statusCode != 200) throw Exception(_erro(r.body));
    return (jsonDecode(r.body) as List)
        .map((e) => EstiloMusical.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> importarEstilos(List<int> ids) async {
    final r = await ApiService.post('/estilos-musicais/importar', {
      'estilos_ids': ids,
    });
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(_erro(r.body));
    }
  }

  Future<void> salvarEstilo({
    EstiloMusical? estilo,
    required String nome,
    required String situacao,
  }) async {
    final dados = {'nmestilomusical': nome, 'sitestilomusical': situacao};
    final r = estilo == null
        ? await ApiService.post('/estilos-musicais', dados)
        : await ApiService.put('/estilos-musicais/${estilo.id}', dados);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(_erro(r.body));
    }
  }

  Future<void> excluirEstilo(int id) async {
    final r = await ApiService.delete('/estilos-musicais/$id');
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(_erro(r.body));
    }
  }

  Future<List<Atracao>> listar() async {
    final r = await ApiService.get('/atracoes');
    if (r.statusCode != 200) throw Exception(_erro(r.body));
    return (jsonDecode(r.body) as List)
        .map((e) => Atracao.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> salvar({
    Atracao? atracao,
    required String nome,
    required List<int> estilosIds,
    required String descricao,
    XFile? banner,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/atracoes${atracao == null ? '' : '/${atracao.atracaoId}'}',
    );
    final req = http.MultipartRequest(atracao == null ? 'POST' : 'PUT', uri);
    final token = await StorageService.getToken();
    if (token?.isNotEmpty == true) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.fields.addAll({
      'nmatracao': nome,
      'estilos_ids': jsonEncode(estilosIds),
      'dsatracao': descricao,
    });
    if (banner != null) {
      req.files.add(
        kIsWeb
            ? http.MultipartFile.fromBytes(
                'urlbanneratracao',
                await banner.readAsBytes(),
                filename: banner.name,
              )
            : await http.MultipartFile.fromPath(
                'urlbanneratracao',
                banner.path,
              ),
      );
    }
    final resp = await req.send();
    final body = await resp.stream.bytesToString();
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_erro(body));
    }
  }

  Future<void> excluir(int id) async {
    final r = await ApiService.delete('/atracoes/$id');
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(_erro(r.body));
    }
  }

  Future<List<AgendaEvento>> agenda(int lojaId, DateTime mes) async {
    final r = await ApiService.get(
      '/agenda-mensal?loja_id=$lojaId&ano=${mes.year}&mes=${mes.month}',
    );
    if (r.statusCode != 200) throw Exception(_erro(r.body));
    return (jsonDecode(r.body) as List)
        .map((e) => AgendaEvento.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> statusAgenda(int lojaId, DateTime mes) async {
    final r = await ApiService.get(
      '/agenda-mensal/status?loja_id=$lojaId&ano=${mes.year}&mes=${mes.month}',
    );
    if (r.statusCode != 200) throw Exception(_erro(r.body));
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }

  Future<String> publicarAgenda(int lojaId, DateTime mes) async {
    final r = await ApiService.post(
      '/agenda-mensal/publicar?loja_id=$lojaId&ano=${mes.year}&mes=${mes.month}',
      const {'publicar_apos_aprovacao': true},
    );
    if (r.statusCode != 200) throw Exception(_erro(r.body));
    return (jsonDecode(r.body)['mensagem'] ?? 'Agenda publicada.').toString();
  }

  Future<String> despublicarAgenda(int lojaId, DateTime mes) async {
    final r = await ApiService.post(
      '/agenda-mensal/despublicar?loja_id=$lojaId&ano=${mes.year}&mes=${mes.month}',
      const {},
    );
    if (r.statusCode != 200) throw Exception(_erro(r.body));
    return (jsonDecode(r.body)['mensagem'] ?? 'Agenda retirada da publicação.')
        .toString();
  }

  Future<void> adicionar({
    required int eventoId,
    required int atracaoId,
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final r = await ApiService.post('/eventos/$eventoId/atracoes', {
      'atracao_id': atracaoId,
      'dtinicioatracao': inicio.toIso8601String(),
      'dtfimatracao': fim.toIso8601String(),
    });
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(_erro(r.body));
    }
  }

  Future<void> atualizarProgramacao({
    required int id,
    required int atracaoId,
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final r = await ApiService.put('/eventos/atracoes/$id', {
      'atracao_id': atracaoId,
      'dtinicioatracao': inicio.toIso8601String(),
      'dtfimatracao': fim.toIso8601String(),
    });
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(_erro(r.body));
    }
  }

  Future<void> removerProgramacao(int id) async {
    final r = await ApiService.delete('/eventos/atracoes/$id');
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(_erro(r.body));
    }
  }

  Future<void> criarEventoRapido({
    required int lojaId,
    required String nomeEvento,
    required int atracaoId,
    required DateTime inicio,
    required DateTime fim,
    required double preco,
  }) async {
    final r = await ApiService.post('/agenda-mensal/evento-rapido', {
      'loja_id': lojaId,
      'nmtituloevento': nomeEvento,
      'atracao_id': atracaoId,
      'dtinicioatracao': inicio.toIso8601String(),
      'dtfimatracao': fim.toIso8601String(),
      'preco_lote': preco,
    });
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(_erro(r.body));
    }
  }

  String _erro(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['detail'] != null) return j['detail'].toString();
    } catch (_) {}
    return body.isEmpty ? 'Não foi possível concluir a operação.' : body;
  }
}
