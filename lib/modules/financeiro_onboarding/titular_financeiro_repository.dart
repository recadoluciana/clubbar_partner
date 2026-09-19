import 'dart:convert';
import '../../core/services/api_service.dart';

class TitularFinanceiroRepository {
  Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty || body.trim() == 'null') return {};
    return Map<String, dynamic>.from(jsonDecode(body) as Map);
  }

  String _erro(String body) {
    try {
      final data = jsonDecode(body);
      return data is Map && data['detail'] != null
          ? data['detail'].toString()
          : body;
    } catch (_) {
      return body;
    }
  }

  String _rota(int id, int? titularFinanceiroId, [String sufixo = '']) =>
      '/titular-financeiro/organizacao/$id$sufixo'
      '${titularFinanceiroId == null ? '' : '?titularfinanceiro_id=$titularFinanceiroId'}';

  Future<List<Map<String, dynamic>>> listar(int id) async {
    final r = await ApiService.get('/titular-financeiro/organizacao/$id/todos');
    if (r.statusCode == 200) {
      final data = jsonDecode(r.body);
      return (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    throw Exception(_erro(r.body));
  }

  Future<Map<String, dynamic>> consultar(
    int id, {
    int? titularFinanceiroId,
  }) async {
    final r = await ApiService.get(_rota(id, titularFinanceiroId));
    if (r.statusCode == 200) return _decode(r.body);
    throw Exception(_erro(r.body));
  }

  Future<Map<String, dynamic>> criar(int id, Map<String, dynamic> dados) async {
    final r = await ApiService.post(
      '/titular-financeiro/organizacao/$id',
      dados,
    );
    if (r.statusCode == 200 || r.statusCode == 201) return _decode(r.body);
    throw Exception(_erro(r.body));
  }

  Future<Map<String, dynamic>> salvar(
    int id,
    Map<String, dynamic> dados, {
    int? titularFinanceiroId,
  }) async {
    final r = await ApiService.put(_rota(id, titularFinanceiroId), dados);
    if (r.statusCode == 200) return _decode(r.body);
    throw Exception(_erro(r.body));
  }

  Future<Map<String, dynamic>> ativar(
    int id, {
    required int titularFinanceiroId,
  }) async {
    final r = await ApiService.post(
      _rota(id, titularFinanceiroId, '/ativar-recebimentos'),
      {},
    );
    if (r.statusCode == 200) return _decode(r.body);
    throw Exception(_erro(r.body));
  }

  Future<Map<String, dynamic>> verificar(
    int id, {
    required int titularFinanceiroId,
  }) async {
    final r = await ApiService.post(
      _rota(id, titularFinanceiroId, '/verificar-asaas'),
      {},
    );
    if (r.statusCode == 200) return _decode(r.body);
    throw Exception(_erro(r.body));
  }

  Future<Map<String, dynamic>> aprovarSandbox(
    int id, {
    required int titularFinanceiroId,
  }) async {
    final r = await ApiService.post(
      _rota(id, titularFinanceiroId, '/aprovar-sandbox'),
      {},
    );
    if (r.statusCode == 200) return _decode(r.body);
    throw Exception(_erro(r.body));
  }

  Future<Map<String, dynamic>> inativar(
    int id, {
    required int titularFinanceiroId,
  }) async {
    final r = await ApiService.patch(
      '/titular-financeiro/organizacao/$id/titular/$titularFinanceiroId/inativar',
      body: {},
    );
    if (r.statusCode == 200) return _decode(r.body);
    throw Exception(_erro(r.body));
  }

  Future<Map<String, dynamic>> reativar(
    int id, {
    required int titularFinanceiroId,
  }) async {
    final r = await ApiService.patch(
      '/titular-financeiro/organizacao/$id/titular/$titularFinanceiroId/reativar',
      body: {},
    );
    if (r.statusCode == 200) return _decode(r.body);
    throw Exception(_erro(r.body));
  }
}
