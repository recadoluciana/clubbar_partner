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

  Future<Map<String, dynamic>> consultar(int id) async {
    final r = await ApiService.get('/titular-financeiro/organizacao/$id');
    if (r.statusCode == 200) return _decode(r.body);
    throw Exception(_erro(r.body));
  }

  Future<Map<String, dynamic>> salvar(
    int id,
    Map<String, dynamic> dados,
  ) async {
    final r = await ApiService.put(
      '/titular-financeiro/organizacao/$id',
      dados,
    );
    if (r.statusCode == 200) return _decode(r.body);
    throw Exception(_erro(r.body));
  }

  Future<Map<String, dynamic>> ativar(int id) async {
    final r = await ApiService.post(
      '/titular-financeiro/organizacao/$id/ativar-recebimentos',
      {},
    );
    if (r.statusCode == 200) return _decode(r.body);
    throw Exception(_erro(r.body));
  }

  Future<Map<String, dynamic>> verificar(int id) async {
    final r = await ApiService.post(
      '/titular-financeiro/organizacao/$id/verificar-asaas',
      {},
    );
    if (r.statusCode == 200) return _decode(r.body);
    throw Exception(_erro(r.body));
  }
}
