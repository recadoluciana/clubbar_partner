import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class LojaPerfilRepository {
  Future<Map<String, dynamic>> conteudo(int lojaId) async =>
      _get('/lojas/$lojaId/conteudo');
  Future<Map<String, dynamic>> politica(int lojaId) async =>
      _get('/lojas/$lojaId/politica-ingressos');
  Future<void> salvarConteudo(int lojaId, Map<String, dynamic> dados) async =>
      _put('/lojas/$lojaId/conteudo', dados);
  Future<void> salvarPolitica(int lojaId, Map<String, dynamic> dados) async =>
      _put('/lojas/$lojaId/politica-ingressos', dados);
  Future<void> excluirConteudo(int lojaId) async =>
      _delete('/lojas/$lojaId/conteudo');
  Future<void> excluirPolitica(int lojaId) async =>
      _delete('/lojas/$lojaId/politica-ingressos');
  Future<String> upload(int lojaId, XFile arquivo) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/lojas/$lojaId/conteudo/upload'),
    );
    final token = await StorageService.getToken();
    if (token?.isNotEmpty == true)
      req.headers['Authorization'] = 'Bearer $token';
    req.files.add(
      kIsWeb
          ? http.MultipartFile.fromBytes(
              'arquivo',
              await arquivo.readAsBytes(),
              filename: arquivo.name,
            )
          : await http.MultipartFile.fromPath('arquivo', arquivo.path),
    );
    final r = await req.send();
    final body = await r.stream.bytesToString();
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception(_erro(body));
    return (jsonDecode(body) as Map)['url'].toString();
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final r = await ApiService.get(path);
    if (r.statusCode != 200) throw Exception(_erro(r.body));
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }

  Future<void> _put(String path, Map<String, dynamic> body) async {
    final r = await ApiService.put(path, body);
    if (r.statusCode < 200 || r.statusCode >= 300)
      throw Exception(_erro(r.body));
  }

  Future<void> _delete(String path) async {
    final r = await ApiService.delete(path);
    if (r.statusCode < 200 || r.statusCode >= 300)
      throw Exception(_erro(r.body));
  }

  String _erro(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['detail'] != null) return j['detail'].toString();
    } catch (_) {}
    return body;
  }
}
