import 'dart:convert';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  static Future<void> login(String email, String senha) async {
    final response = await ApiService.post('/auth/loginuser', {
      'email': email,
      'senha': senha,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final token = data['access_token'];
      final lojaId = data['loja_id'];
      final usuarioId = data['usuario_id'];
      final organizacaoId = data['organizacao_id'];
      final cargo = data['dscargo']?.toString() ?? '';

      if (token == null || token.toString().isEmpty) {
        throw Exception('Token não retornado');
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

      await StorageService.saveSuperAdmin(
        data['is_superadmin'] == true || cargo == 'SUPERADMIN',
      );
    } else {
      throw Exception('Login inválido: ${response.body}');
    }
  }
}
