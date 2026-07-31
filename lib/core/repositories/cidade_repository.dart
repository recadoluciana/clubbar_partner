import 'dart:convert';

import '../../models/cidade.dart';
import '../services/api_service.dart';

class CidadeRepository {
  Future<List<Cidade>> listar() async {
    final response = await ApiService.get('/cidades');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is List) {
        return data.map((e) => Cidade.fromJson(e)).toList();
      }

      return [];
    }

    throw Exception('Erro ao listar cidades: ${response.body}');
  }
}
