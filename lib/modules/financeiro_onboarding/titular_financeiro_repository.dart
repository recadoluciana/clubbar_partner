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

  String _rota(int id, int? lojaId, [String sufixo = '']) =>
      '/titular-financeiro/organizacao/$id$sufixo'
      '${lojaId == null ? '' : '?loja_id=$lojaId'}';

  Future<Map<String, dynamic>> consultar(int id, {int? lojaId}) async {
    final r = await ApiService.get(_rota(id, lojaId));
    if (r.statusCode == 200) return _decode(r.body);
    throw Exception(_erro(r.body));
  }

  Future<Map<String, dynamic>> salvar(
    int id,
    Map<String, dynamic> dados, {
    int? lojaId,
  }) async {
    final r = await ApiService.put(_rota(id, lojaId), dados);
    if (r.statusCode == 200) return _decode(r.body);
    throw Exception(_erro(r.body));
  }

  Future<Map<String, dynamic>> ativar(int id, {int? lojaId}) async {
    final r = await ApiService.post(
      _rota(id, lojaId, '/ativar-recebimentos'),
      {},
    );
    if (r.statusCode == 200) return _decode(r.body);
    throw Exception(_erro(r.body));
  }

  Future<Map<String, dynamic>> verificar(int id, {int? lojaId}) async {
    final r = await ApiService.post(_rota(id, lojaId, '/verificar-asaas'), {});
    if (r.statusCode == 200) return _decode(r.body);
    throw Exception(_erro(r.body));
  }

  Future<Map<String, dynamic>> aprovarSandbox(int id, {int? lojaId}) async {
    final r = await ApiService.post(_rota(id, lojaId, '/aprovar-sandbox'), {});
    if (r.statusCode == 200) return _decode(r.body);
    throw Exception(_erro(r.body));
  }
}
