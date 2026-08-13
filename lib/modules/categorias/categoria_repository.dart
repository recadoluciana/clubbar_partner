import 'dart:convert';
import 'package:clubbar_partner/core/services/api_service.dart';

import '../../models/categoria.dart';

class CategoriaRepository {
  Future<List<Categoria>> listar(int lojaId) async {
    final response = await ApiService.get('/lojas/$lojaId/categorias');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is List) {
        return data.map((e) => Categoria.fromJson(e)).toList();
      }

      return [];
    }

    throw Exception('Erro ao listar categorias: ${response.body}');
  }

  Future<void> criar(int lojaId, String nome) async {
    final response = await ApiService.post('/lojas/$lojaId/categorias', {
      'nmcategoria': nome,
      'sitcategoria': 'ATIVA',
      'idordcategoria': 1,
    });

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erro ao criar categoria: ${response.body}');
    }
  }

  Future<void> atualizar(int categoriaId, String nome) async {
    final response = await ApiService.put('/categorias/$categoriaId', {
      'nmcategoria': nome,
    });

    if (response.statusCode != 200) {
      throw Exception('Erro ao atualizar categoria: ${response.body}');
    }
  }

  Future<void> excluir(int categoriaId) async {
    final response = await ApiService.delete('/categorias/$categoriaId');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Erro ao excluir categoria: ${response.body}');
    }
  }
}
