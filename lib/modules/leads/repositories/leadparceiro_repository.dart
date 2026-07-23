import 'dart:convert';

import '../models/leadparceiro.dart';
import '../../../core/services/api_service.dart';

class LeadParceiroRepository {
  Future<List<LeadParceiro>> listar() async {
    final response = await ApiService.get('/parceiros');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(LeadParceiro.fromJson)
            .toList();
      }
      return [];
    }

    throw Exception(_extrairErro(response.body, 'Erro ao listar leads.'));
  }

  Future<LeadParceiro> buscar(int leadparceiroId) async {
    final response = await ApiService.get('/parceiros/$leadparceiroId');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return LeadParceiro.fromJson(data);
      }
    }

    throw Exception(_extrairErro(response.body, 'Erro ao buscar lead.'));
  }

  Future<LeadParceiro> atualizar({
    required int leadparceiroId,
    required String nmresponsavel,
    required String tipo,
    required String telefone,
    required String email,
    required String status,
  }) async {
    final response = await ApiService.put('/parceiros/$leadparceiroId', {
      'nmresponsavel': nmresponsavel,
      'tipo': tipo,
      'telefone': telefone,
      'email': email,
      'status': status,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return LeadParceiro.fromJson(data);
      }
    }

    throw Exception(_extrairErro(response.body, 'Erro ao atualizar lead.'));
  }

  String _extrairErro(String body, String fallback) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['detail'] != null) {
        final detail = data['detail'];
        if (detail is List) {
          return detail
              .map((item) {
                if (item is Map && item['msg'] != null) {
                  return item['msg'].toString();
                }
                return item.toString();
              })
              .join(' ');
        }
        return detail.toString();
      }
    } catch (_) {}

    final texto = body.trim();
    return texto.isEmpty ? fallback : texto;
  }
}
