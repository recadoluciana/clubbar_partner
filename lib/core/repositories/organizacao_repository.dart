import 'dart:convert';

import '../../models/organizacao.dart';
import '../services/api_service.dart';

class OrganizacaoRepository {
  String _mensagemErro(String body, String mensagemPadrao) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['detail'] is String) {
        return data['detail'].toString();
      }
      if (data is Map && data['detail'] is List) {
        final erros = data['detail'] as List;
        if (erros.any(
          (erro) =>
              erro is Map &&
              (erro['loc'] as List?)?.contains('emailorganizacao') == true,
        )) {
          return 'Informe um e-mail válido com no máximo 254 caracteres.';
        }
      }
    } catch (_) {}
    return mensagemPadrao;
  }

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
      throw Exception(
        _mensagemErro(
          response.body,
          'Não foi possível atualizar os dados da empresa.',
        ),
      );
    }
  }

  Future<void> criar(Map<String, dynamic> dados) async {
    final response = await ApiService.post('/organizacoes', dados);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erro ao criar empresa: ${response.body}');
    }
  }
}
