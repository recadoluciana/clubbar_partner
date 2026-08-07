import 'dart:convert';

import '../../models/painel_gerencial.dart';
import '../services/api_service.dart';

class PainelGerencialRepository {
  Future<PainelGerencial> buscar() async {
    final response = await ApiService.get('/painel-gerencial');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return PainelGerencial.fromJson(data);
      }
      if (data is Map) {
        return PainelGerencial.fromJson(Map<String, dynamic>.from(data));
      }
      throw Exception('Resposta inválida do painel gerencial.');
    }

    var mensagem = 'Não foi possível carregar o painel gerencial.';
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] != null) {
        mensagem = data['detail'].toString();
      }
    } catch (_) {}
    throw Exception(mensagem);
  }
}
