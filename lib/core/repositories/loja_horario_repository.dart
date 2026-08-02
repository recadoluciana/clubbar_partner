import 'dart:convert';

import '../../models/loja_horario.dart';
import '../services/api_service.dart';

class LojaHorarioRepository {
  Future<List<LojaHorario>> buscarPorLoja(int lojaId) async {
    final response = await ApiService.get('/lojas/$lojaId/horarios');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _mensagemErro(response.body, 'Erro ao carregar horários.'),
      );
    }

    final data = _decodificarLista(response.body);
    return data
        .map(
          (item) =>
              LojaHorario.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<LojaHorario>> salvarTodos(
    int lojaId,
    List<LojaHorario> horarios,
  ) async {
    final payload = horarios
        .map((horario) => horario.copyWith(lojaId: lojaId).toJson())
        .toList();

    final response = await ApiService.put('/lojas/$lojaId/horarios', payload);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_mensagemErro(response.body, 'Erro ao salvar horários.'));
    }

    if (response.body.trim().isEmpty) {
      return horarios;
    }

    final data = _decodificarLista(response.body);
    if (data.isEmpty) return horarios;

    return data
        .map(
          (item) =>
              LojaHorario.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  List<dynamic> _decodificarLista(String body) {
    if (body.trim().isEmpty) return const [];

    final data = jsonDecode(body);
    if (data is List) return data;

    if (data is Map) {
      final horarios = data['horarios'];
      if (horarios is List) return horarios;
    }

    throw Exception('Resposta inválida da API de horários.');
  }

  String _mensagemErro(String body, String fallback) {
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        final mensagem = data['detail'] ?? data['message'] ?? data['mensagem'];
        if (mensagem != null && mensagem.toString().trim().isNotEmpty) {
          return mensagem.toString().trim();
        }
      }
    } catch (_) {
      // Usa o corpo original quando a resposta não for JSON.
    }

    return body.trim().isEmpty ? fallback : body.trim();
  }
}
