import 'dart:convert';

import '../../models/organizacao.dart';
import '../services/api_service.dart';

class OrganizacaoRepository {
  Future<Organizacao> buscarPorUsuario(int usuarioId) async {
    final response = await ApiService.get('/organizacoes/usuario/$usuarioId');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Organizacao.fromJson(data);
    }

    throw Exception('Erro ao carregar empresa: ${response.body}');
  }

  Future<void> atualizar(int usuarioId, Map<String, dynamic> dados) async {
    final response = await ApiService.put(
      '/organizacoes/usuario/$usuarioId',
      dados,
    );

    if (response.statusCode != 200) {
      throw Exception('Erro ao atualizar empresa: ${response.body}');
    }
  }

  Future<void> criar(Map<String, dynamic> dados) async {
    final response = await ApiService.post('/organizacoes', dados);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erro ao criar empresa: ${response.body}');
    }
  }
}
