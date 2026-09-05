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
    int? eventoSetorId,
    int numeroLote = 1,
    String tipoIngresso = 'UNICO',
  }) async {
    final response = await ApiService.post('/eventos/$eventoId/lotes', {
      'organizacao_id': organizacaoId,
      'loja_id': lojaId,
      'nmlote': nome,
      'eventosetor_id': eventoSetorId,
      'nrlote': numeroLote,
      'tipoingresso': tipoIngresso,
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
    int? eventoSetorId,
    int? numeroLote,
    String? tipoIngresso,
  }) async {
    final response = await ApiService.put('/eventos/lotes/$loteId', {
      'organizacao_id': organizacaoId,
      'loja_id': lojaId,
      'evento_id': eventoId,
      'nmlote': nome,
      'eventosetor_id': eventoSetorId,
      'nrlote': numeroLote,
      'tipoingresso': tipoIngresso,
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

  Future<List<EventoSetor>> listarSetores(int eventoId) async {
    final response = await ApiService.get('/eventos/$eventoId/setores');
    if (response.statusCode != 200) throw Exception(response.body);
    return (jsonDecode(response.body) as List)
        .map((e) => EventoSetor.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<EventoSetor> criarSetor({
    required int eventoId,
    required String nome,
    required int capacidade,
    String descricao = '',
  }) async {
    final response = await ApiService.post('/eventos/$eventoId/setores', {
      'nmsetor': nome,
      'dssetor': descricao,
      'qtcapacidade': capacidade,
      'nrordem': 1,
      'sitsetor': 'ATIVO',
    });
    if (response.statusCode != 201) throw Exception(response.body);
    return EventoSetor.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body)),
    );
  }

  Future<void> excluir(int loteId) async {
    final response = await ApiService.delete('/eventos/lotes/$loteId');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Erro ao excluir lote: ${response.body}');
    }
  }
}
