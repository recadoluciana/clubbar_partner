import 'dart:convert';

import '../../models/auditoria.dart';
import '../services/api_service.dart';

class AuditoriaRepository {
  Future<List<AuditoriaItem>> listar({int dias = 30}) async {
    final response = await ApiService.get('/auditoria?dias=$dias&limite=500');
    if (response.statusCode != 200) throw Exception(_erro(response.body));
    return (jsonDecode(response.body) as List)
        .map((item) => AuditoriaItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  String _erro(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['detail'] != null) return '${data['detail']}';
    } catch (_) {}
    return 'Não foi possível carregar a auditoria.';
  }
}
