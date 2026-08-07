import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../models/atracao.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AtracaoRepository {
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
    required String estilo,
    required String descricao,
    XFile? banner,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/atracoes${atracao == null ? '' : '/${atracao.atracaoId}'}',
    );
    final req = http.MultipartRequest(atracao == null ? 'POST' : 'PUT', uri);
    final token = await StorageService.getToken();
    if (token?.isNotEmpty == true)
      req.headers['Authorization'] = 'Bearer $token';
    req.fields.addAll({
      'nmatracao': nome,
      'dsestilomusical': estilo,
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
    if (resp.statusCode < 200 || resp.statusCode >= 300)
      throw Exception(_erro(body));
  }

  Future<void> excluir(int id) async {
    final r = await ApiService.delete('/atracoes/$id');
    if (r.statusCode < 200 || r.statusCode >= 300)
      throw Exception(_erro(r.body));
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
    if (r.statusCode < 200 || r.statusCode >= 300)
      throw Exception(_erro(r.body));
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
    if (r.statusCode < 200 || r.statusCode >= 300)
      throw Exception(_erro(r.body));
  }

  Future<void> removerProgramacao(int id) async {
    final r = await ApiService.delete('/eventos/atracoes/$id');
    if (r.statusCode < 200 || r.statusCode >= 300)
      throw Exception(_erro(r.body));
  }

  String _erro(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['detail'] != null) return j['detail'].toString();
    } catch (_) {}
    return body.isEmpty ? 'Não foi possível concluir a operação.' : body;
  }
}
