import 'dart:convert';

import '../../models/acompanhamento_vendas.dart';
import '../../models/cliente_compras.dart';
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

  Future<ProdutosPendentesResumo> produtosPendentes({int? lojaId}) async {
    final query = lojaId == null ? '' : '?loja_id=$lojaId';
    final response = await ApiService.get(
      '/acompanhamento-vendas/produtos-pendentes$query',
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

  Future<List<CompraProduto>> comprasProdutos({
    String situacao = 'TODOS',
  }) async {
    final response = await ApiService.get(
      '/acompanhamento-vendas/produtos?situacao=$situacao',
    );
    if (response.statusCode != 200) {
      throw Exception(
        _erro(
          response.body,
          'Não foi possível consultar as compras de produtos.',
        ),
      );
    }
    final dados = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    return ((dados['itens'] as List?) ?? const [])
        .map(
          (item) =>
              CompraProduto.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<ClienteComCompras>> clientesComCompras({String? busca}) async {
    final termo = busca?.trim() ?? '';
    final query = termo.isEmpty
        ? ''
        : '?busca=${Uri.encodeQueryComponent(termo)}';
    final response = await ApiService.get(
      '/acompanhamento-vendas/clientes$query',
    );
    if (response.statusCode != 200) {
      throw Exception(
        _erro(response.body, 'Não foi possível consultar os clientes.'),
      );
    }
    final dados = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    return ((dados['clientes'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) => ClienteComCompras.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<List<EventoVendaResumo>> eventos(String periodo, {int? lojaId}) async {
    final query = lojaId == null ? '' : '&loja_id=$lojaId';
    final response = await ApiService.get(
      '/acompanhamento-vendas/eventos?periodo=$periodo$query',
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

  Future<List<IngressoVendido>> ingressosVendidosEvento(int eventoId) async {
    final response = await ApiService.get(
      '/acompanhamento-vendas/eventos/$eventoId/ingressos',
    );
    if (response.statusCode != 200) {
      throw Exception(
        _erro(
          response.body,
          'Não foi possível consultar os ingressos vendidos.',
        ),
      );
    }
    return (jsonDecode(response.body) as List)
        .map(
          (item) =>
              IngressoVendido.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }
}
