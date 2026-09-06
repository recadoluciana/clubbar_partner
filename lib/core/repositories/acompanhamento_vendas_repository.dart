import 'dart:convert';

import '../../models/acompanhamento_vendas.dart';
import '../services/api_service.dart';

class AcompanhamentoVendasRepository {
  String _erro(String body, String padrao) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
    } catch (_) {}
    return padrao;
  }

  Future<ProdutosPendentesResumo> produtosPendentes() async {
    final response = await ApiService.get(
      '/acompanhamento-vendas/produtos-pendentes',
    );
    if (response.statusCode != 200) {
      throw Exception(
        _erro(
          response.body,
          'Não foi possível consultar os produtos pendentes.',
        ),
      );
    }
    return ProdutosPendentesResumo.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<List<EventoVendaResumo>> eventos(String periodo) async {
    final response = await ApiService.get(
      '/acompanhamento-vendas/eventos?periodo=$periodo',
    );
    if (response.statusCode != 200) {
      throw Exception(
        _erro(
          response.body,
          'Não foi possível consultar as vendas dos eventos.',
        ),
      );
    }
    return (jsonDecode(response.body) as List)
        .map(
          (item) => EventoVendaResumo.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<EventoVendaDetalhe> detalheEvento(int eventoId) async {
    final response = await ApiService.get(
      '/acompanhamento-vendas/eventos/$eventoId',
    );
    if (response.statusCode != 200) {
      throw Exception(
        _erro(response.body, 'Não foi possível detalhar o evento.'),
      );
    }
    return EventoVendaDetalhe.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }
}
