import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../core/config/api_config.dart';
import '../../models/evento.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class EventoRepository {
  Future<List<Evento>> listar(int lojaId) async {
    final response = await ApiService.get('/eventos/loja/$lojaId');

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Evento.fromJson(e)).toList();
    }

    throw Exception('Erro ao listar eventos: ${response.body}');
  }

  Future<http.MultipartFile> _montarArquivoImagem(
    String fieldName,
    XFile imagem,
  ) async {
    final mimeType =
        lookupMimeType(imagem.name) ??
        lookupMimeType(imagem.path) ??
        'image/jpeg';

    final parts = mimeType.split('/');

    if (kIsWeb) {
      final bytes = await imagem.readAsBytes();

      return http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: imagem.name,
        contentType: MediaType(parts[0], parts[1]),
      );
    } else {
      return await http.MultipartFile.fromPath(
        fieldName,
        imagem.path,
        contentType: MediaType(parts[0], parts[1]),
      );
    }
  }

  Future<void> criar({
    required int organizacaoId,
    required int lojaId,
    required int produtoIdIngresso,
    required String titulo,
    String? descricao,
    String? politicaCancelamento,
    String? politicaReembolso,
    String? politicaCashback,
    required String dataInicio,
    String? dataFim,
    String? local,
    String? endereco,
    String? status,
    XFile? imagem,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/eventos');

    final request = http.MultipartRequest('POST', uri);

    final token = await StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['organizacao_id'] = organizacaoId.toString();
    request.fields['loja_id'] = lojaId.toString();
    request.fields['produto_id_ingresso'] = produtoIdIngresso.toString();
    request.fields['nmtituloevento'] = titulo;
    request.fields['dtinicioevento'] = dataInicio;

    if (descricao != null && descricao.isNotEmpty) {
      request.fields['dsdescevento'] = descricao;
    }
    if (politicaCancelamento != null) {
      request.fields['dspoliticacancelamento'] = politicaCancelamento;
    }
    if (politicaReembolso != null) {
      request.fields['dspoliticareembolso'] = politicaReembolso;
    }
    if (politicaCashback != null) {
      request.fields['dspoliticacashback'] = politicaCashback;
    }
    if (dataFim != null && dataFim.isNotEmpty) {
      request.fields['dtfimevento'] = dataFim;
    }
    if (local != null && local.isNotEmpty) {
      request.fields['nmlocalevento'] = local;
    }
    if (endereco != null && endereco.isNotEmpty) {
      request.fields['dsendlocevento'] = endereco;
    }
    if (status != null && status.isNotEmpty) {
      request.fields['statusevento'] = status;
    }

    if (imagem != null) {
      request.files.add(await _montarArquivoImagem('urlbannerevento', imagem));
    }

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erro ao criar evento: $body');
    }
  }

  Future<void> atualizar({
    required int eventoId,
    String? titulo,
    String? descricao,
    String? politicaCancelamento,
    String? politicaReembolso,
    String? politicaCashback,
    String? dataInicio,
    String? dataFim,
    String? local,
    String? endereco,
    String? status,
    XFile? imagem,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/eventos/$eventoId');

    final request = http.MultipartRequest('PUT', uri);

    final token = await StorageService.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (titulo != null && titulo.isNotEmpty) {
      request.fields['nmtituloevento'] = titulo;
    }
    if (descricao != null) {
      request.fields['dsdescevento'] = descricao;
    }
    if (politicaCancelamento != null) {
      request.fields['dspoliticacancelamento'] = politicaCancelamento;
    }
    if (politicaReembolso != null) {
      request.fields['dspoliticareembolso'] = politicaReembolso;
    }
    if (politicaCashback != null) {
      request.fields['dspoliticacashback'] = politicaCashback;
    }
    if (dataInicio != null && dataInicio.isNotEmpty) {
      request.fields['dtinicioevento'] = dataInicio;
    }
    if (dataFim != null) {
      request.fields['dtfimevento'] = dataFim;
    }
    if (local != null) {
      request.fields['nmlocalevento'] = local;
    }
    if (endereco != null) {
      request.fields['dsendlocevento'] = endereco;
    }
    if (status != null && status.isNotEmpty) {
      request.fields['statusevento'] = status;
    }

    if (imagem != null) {
      request.files.add(await _montarArquivoImagem('urlbannerevento', imagem));
    }

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Erro ao atualizar evento: $body');
    }
  }

  Future<void> excluir(int eventoId) async {
    final response = await ApiService.delete('/eventos/$eventoId');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Erro ao excluir evento: ${response.body}');
    }
  }
}
