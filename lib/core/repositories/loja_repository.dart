import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../core/config/api_config.dart';
import '../../models/loja.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class LojaRepository {
  Future<List<Loja>> listar(int organizacaoId) async {
    final response = await ApiService.get(
      '/lojas/organizacoes/$organizacaoId/lojas_todas',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is List) {
        return data.map((e) => Loja.fromJson(e)).toList();
      }

      return [];
    }

    throw Exception('Erro ao listar lojas: ${response.body}');
  }

  Future<http.MultipartFile> _montarArquivoImagem(
    String fieldName,
    XFile imagem,
  ) async {
    if (kIsWeb) {
      final bytes = await imagem.readAsBytes();
      return http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: imagem.name,
      );
    } else {
      return await http.MultipartFile.fromPath(fieldName, imagem.path);
    }
  }

  Future<int> criar({
    required int organizacaoId,
    required int estadoId,
    required int cidadeId,
    required String nome,
    String? estiloLoja,
    String? bairro,
    String? telefone,
    int? diasValidade,
    String? endereco,
    String? instagram,
    String aberto24x7 = 'N',
    String idvalidadeprod = 'S',
    XFile? imagem,
    XFile? imagemFachada,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/lojas');

    final request = http.MultipartRequest('POST', uri);

    final token = await StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['organizacao_id'] = organizacaoId.toString();
    request.fields['estado_id'] = estadoId.toString();
    request.fields['cidade_id'] = cidadeId.toString();
    request.fields['nmloja'] = nome;
    request.fields['dsestiloloja'] = estiloLoja ?? '';
    request.fields['dsbairroloja'] = bairro ?? '';
    request.fields['nrtelloja'] = telefone ?? '';

    request.fields['endloja'] = endereco ?? '';
    request.fields['dsinstaloja'] = instagram ?? '';
    request.fields['aberto24x7'] = aberto24x7 == 'S' ? 'S' : 'N';
    request.fields['idvalidadeprod'] = idvalidadeprod == 'N' ? 'N' : 'S';

    if (diasValidade != null) {
      request.fields['nrdiavalidade'] = diasValidade.toString();
    }

    if (imagem != null) {
      request.files.add(await _montarArquivoImagem('urllogoloja', imagem));
    }
    if (imagemFachada != null) {
      request.files.add(
        await _montarArquivoImagem('urlfachadaloja', imagemFachada),
      );
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erro ao criar loja: $responseBody');
    }

    try {
      final data = jsonDecode(responseBody);
      if (data is Map) {
        final lojaId = data['loja_id'];
        if (lojaId is int && lojaId > 0) return lojaId;

        final lojaIdConvertido = int.tryParse(lojaId?.toString() ?? '');
        if (lojaIdConvertido != null && lojaIdConvertido > 0) {
          return lojaIdConvertido;
        }
      }
    } catch (_) {
      // A mensagem abaixo explicita o contrato esperado do endpoint.
    }

    throw Exception('A API criou a loja, mas não retornou um loja_id válido.');
  }

  Future<void> atualizar({
    required int lojaId,
    required int organizacaoId,
    required int estadoId,
    required int cidadeId,
    required String nome,
    String? estiloLoja,
    String? bairro,
    String? telefone,
    int? diasValidade,
    String? endereco,
    String? instagram,
    String aberto24x7 = 'N',
    String idvalidadeprod = 'S',
    XFile? imagem,
    XFile? imagemFachada,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/lojas/$lojaId');

    final request = http.MultipartRequest('PUT', uri);

    final token = await StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['organizacao_id'] = organizacaoId.toString();
    request.fields['estado_id'] = estadoId.toString();
    request.fields['cidade_id'] = cidadeId.toString();
    request.fields['nmloja'] = nome;
    request.fields['dsestiloloja'] = estiloLoja ?? '';
    request.fields['dsbairroloja'] = bairro ?? '';
    request.fields['nrtelloja'] = telefone ?? '';

    request.fields['endloja'] = endereco ?? '';
    request.fields['dsinstaloja'] = instagram ?? '';
    request.fields['aberto24x7'] = aberto24x7 == 'S' ? 'S' : 'N';
    request.fields['idvalidadeprod'] = idvalidadeprod == 'N' ? 'N' : 'S';

    if (diasValidade != null) {
      request.fields['nrdiavalidade'] = diasValidade.toString();
    }

    if (imagem != null) {
      request.files.add(await _montarArquivoImagem('urllogoloja', imagem));
    }
    if (imagemFachada != null) {
      request.files.add(
        await _montarArquivoImagem('urlfachadaloja', imagemFachada),
      );
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Erro ao atualizar loja: $responseBody');
    }
  }

  Future<void> atualizarAberto24x7(Loja loja, String aberto24x7) async {
    final estadoId = loja.estadoId;
    final cidadeId = loja.cidadeId;
    if (estadoId == null || cidadeId == null) {
      throw Exception('Estado e cidade da loja não foram identificados.');
    }

    await atualizar(
      lojaId: loja.lojaId,
      organizacaoId: loja.organizacaoId,
      estadoId: estadoId,
      cidadeId: cidadeId,
      nome: loja.nmloja,
      estiloLoja: loja.dsestiloloja,
      bairro: loja.dsbairroloja,
      telefone: loja.nrtelloja,
      diasValidade: loja.nrdiavalidade,
      endereco: loja.endloja,
      instagram: loja.dsinstaloja,
      aberto24x7: aberto24x7,
      idvalidadeprod: loja.idvalidadeprod,
    );
  }

  Future<void> excluir(int lojaId) async {
    final response = await ApiService.delete('/lojas/$lojaId');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Erro ao excluir loja: ${response.body}');
    }
  }

  Future<void> inativar(int lojaId) async {
    final response = await ApiService.patch('/lojas/$lojaId/inativar');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Erro ao inativar loja: ${response.body}');
    }
  }

  Future<void> reativar(int lojaId) async {
    final response = await ApiService.patch('/lojas/$lojaId/reativar');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Erro ao reativar loja: ${response.body}');
    }
  }
}
