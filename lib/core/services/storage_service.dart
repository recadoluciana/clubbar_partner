import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _tokenKey = 'auth_token';

  static const String _lojaIdKey = 'loja_id';
  static const String _organizacaoIdKey = 'organizacao_id';
  static const String _usuarioIdKey = 'usuario_id';

  static const String _nomeUsuarioKey = 'nome_usuario';
  static const String _nomeOrganizacaoKey = 'nome_organizacao';

  // NOVOS
  static const String _cargoKey = 'dscargo';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveLojaId(int lojaId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lojaIdKey, lojaId);
  }

  static Future<int?> getLojaId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lojaIdKey);
  }

  static Future<void> saveOrganizacaoId(int organizacaoId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_organizacaoIdKey, organizacaoId);
  }

  static Future<int?> getOrganizacaoId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_organizacaoIdKey);
  }

  static Future<void> saveUsuarioId(int usuarioId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_usuarioIdKey, usuarioId);
  }

  static Future<int?> getUsuarioId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_usuarioIdKey);
  }

  static Future<void> saveNomeUsuario(String nome) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nomeUsuarioKey, nome);
  }

  static Future<String?> getNomeUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nomeUsuarioKey);
  }

  static Future<void> saveNomeOrganizacao(String nome) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nomeOrganizacaoKey, nome);
  }

  static Future<String?> getNomeOrganizacao() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nomeOrganizacaoKey);
  }

  // NOVOS

  static Future<void> saveCargo(String cargo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cargoKey, cargo);
  }

  static Future<String?> getCargo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cargoKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();
  }
}
