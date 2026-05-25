import 'dart:convert';

import '../services/api_service.dart';

class SuperAdminRepository {
  Future<Map<String, dynamic>> dashboard() async {
    final response = await ApiService.get('/superadmin/dashboard');

    if (response.statusCode != 200) {
      throw Exception('Erro ao carregar dashboard');
    }

    return jsonDecode(response.body);
  }
}
