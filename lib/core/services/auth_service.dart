import 'dart:convert';

import 'api_service.dart';
import 'storage_service.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static Future<void> login(String email, String senha) async {
    try {
      final response = await ApiService.post('/auth/loginuser', {
        'email': email,
        'senha': senha,
      });

      if (response.statusCode == 401) {
        throw const AuthException('E-mail ou senha inválidos.');
      }

      if (response.statusCode == 403) {
        throw const AuthException(
          'Este usuário está inativo. Entre em contato com o responsável.',
        );
      }

      if (response.statusCode != 200) {
        throw const AuthException(
          'Não foi possível realizar o login. Tente novamente.',
        );
      }

      final data = jsonDecode(response.body);

      final token = data['access_token'];
      final lojaId = data['loja_id'];
      final usuarioId = data['usuario_id'];
      final organizacaoId = data['organizacao_id'];
      final cargo = data['dscargo']?.toString() ?? '';

      if (token == null || token.toString().isEmpty) {
        throw const AuthException(
          'Não foi possível concluir o login. Tente novamente.',
        );
      }

      await StorageService.saveToken(token.toString());

      if (lojaId != null) {
        await StorageService.saveLojaId(lojaId);
      }

      if (usuarioId != null) {
        await StorageService.saveUsuarioId(usuarioId);
        await StorageService.saveNomeUsuario(
          data['nmusuario']?.toString() ?? '',
        );
      }

      if (organizacaoId != null) {
        await StorageService.saveOrganizacaoId(organizacaoId);
        await StorageService.saveNomeOrganizacao(
          data['nmorganizacao']?.toString() ?? '',
        );
      }

      await StorageService.saveCargo(cargo);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Não foi possível conectar ao servidor. Tente novamente.',
      );
    }
  }
}
