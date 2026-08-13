import 'dart:convert';

import '../../models/evento_lote.dart';
import '../services/api_service.dart';

class EventoLoteRepository {
  Future<List<EventoLote>> listar(int eventoId) async {
    final response = await ApiService.get('/eventos/$eventoId/lotes_todos');

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => EventoLote.fromJson(e)).toList();
    }

    throw Exception('Erro ao listar lotes: ${response.body}');
  }

  Future<void> criar({
    required int eventoId,
    required int organizacaoId,
    required int lojaId,
    required String nome,
    required double preco,
    required int quantidadeTotal,
    required int quantidadeVendida,
    String? dtInicioVenda,
    String? dtFimVenda,
    String status = 'ATIVO',
  }) async {
    final response = await ApiService.post('/eventos/$eventoId/lotes', {
      'organizacao_id': organizacaoId,
      'loja_id': lojaId,
      'nmlote': nome,
      'vrprecolote': preco,
      'qttotallote': quantidadeTotal,
      'qtvendidalote': quantidadeVendida,
      'dtiniciovenda': dtInicioVenda,
      'dtfimvenda': dtFimVenda,
      'statuslote': status,
    });

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erro ao criar lote: ${response.body}');
    }
  }

  Future<void> atualizar({
    required int loteId,
    int? organizacaoId,
    int? lojaId,
    int? eventoId,
    String? nome,
    double? preco,
    int? quantidadeTotal,
    int? quantidadeVendida,
    String? dtInicioVenda,
    String? dtFimVenda,
    String? status,
  }) async {
    final response = await ApiService.put('/eventos/lotes/$loteId', {
      'organizacao_id': organizacaoId,
      'loja_id': lojaId,
      'evento_id': eventoId,
      'nmlote': nome,
      'vrprecolote': preco,
      'qttotallote': quantidadeTotal,
      'qtvendidalote': quantidadeVendida,
      'dtiniciovenda': dtInicioVenda,
      'dtfimvenda': dtFimVenda,
      'statuslote': status,
    });

    if (response.statusCode != 200) {
      throw Exception('Erro ao atualizar lote: ${response.body}');
    }
  }

  Future<void> excluir(int loteId) async {
    final response = await ApiService.delete('/eventos/lotes/$loteId');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Erro ao excluir lote: ${response.body}');
    }
  }
}
