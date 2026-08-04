import 'dart:convert';

import '../../models/categoria.dart';
import '../services/api_service.dart';

class CategoriaRepository {
  Future<List<Categoria>> listar(int lojaId) async {
    final response = await ApiService.get('/lojas/$lojaId/categorias_todas');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is List) {
        return data.map((e) => Categoria.fromJson(e)).toList();
      }

      return [];
    }

    throw Exception('Erro ao listar categorias: ${response.body}');
  }

  Future<int?> criar(
    int lojaId,
    String nome,
    String sitcategoria,
    int idordcategoria,
  ) async {
    final response = await ApiService.post('/lojas/$lojaId/categorias', {
      'nmcategoria': nome,
      'sitcategoria': sitcategoria,
      'idordcategoria': idordcategoria,
    });

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erro ao criar categoria: ${response.body}');
    }

    try {
      final data = jsonDecode(response.body);
      if (data is Map) {
        final valor = data['categoria_id'];
        if (valor is int) return valor;
        if (valor is num) return valor.toInt();
        return int.tryParse(valor?.toString() ?? '');
      }
    } catch (_) {
      // Algumas versões da API respondem sem corpo após a inclusão.
    }

    return null;
  }

  Future<void> atualizar(
    int lojaId,
    int categoriaId,
    String nome,
    String sitcategoria,
    int idordcategoria,
  ) async {
    final response =
        await ApiService.put('/lojas/$lojaId/categorias/$categoriaId', {
          'nmcategoria': nome,
          'sitcategoria': sitcategoria,
          'idordcategoria': idordcategoria,
        });

    if (response.statusCode != 200) {
      throw Exception('Erro ao atualizar categoria: ${response.body}');
    }
  }

  Future<void> excluir(int lojaId, int categoriaId) async {
    final response = await ApiService.delete(
      '/lojas/$lojaId/categorias/$categoriaId',
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Erro ao excluir categoria: ${response.body}');
    }
  }
}
