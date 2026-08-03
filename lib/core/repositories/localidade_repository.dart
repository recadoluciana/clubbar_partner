import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/cidade.dart';
import '../../models/estado.dart';
import '../services/api_service.dart';

class LocalidadeRepository {
  Future<EnderecoCep> buscarEnderecoPorCep(String cep) async {
    final numeros = cep.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeros.length != 8) {
      throw Exception('Informe um CEP válido com 8 dígitos.');
    }

    final response = await http.get(
      Uri.parse('https://viacep.com.br/ws/$numeros/json/'),
    );
    if (response.statusCode != 200) {
      throw Exception('Não foi possível consultar o CEP.');
    }

    final data = jsonDecode(response.body);
    if (data is! Map || data['erro'] == true) {
      throw Exception('CEP não encontrado.');
    }

    return EnderecoCep.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<Estado>> listarEstados() async {
    final response = await ApiService.get('/localidades/estados');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is! List) {
        throw Exception('Resposta inválida ao carregar estados.');
      }

      return data
          .map(
            (item) => Estado.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    }

    throw Exception(
      'Erro ao carregar estados: ${_obterMensagemErro(response.body)}',
    );
  }

  Future<List<Cidade>> listarCidadesPorEstado(int estadoId) async {
    if (estadoId <= 0) {
      throw Exception('Estado inválido.');
    }

    final response = await ApiService.get(
      '/localidades/estados/$estadoId/cidades',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is! List) {
        throw Exception('Resposta inválida ao carregar cidades.');
      }

      return data
          .map(
            (item) => Cidade.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    }

    throw Exception(
      'Erro ao carregar cidades: ${_obterMensagemErro(response.body)}',
    );
  }

  String _obterMensagemErro(String body) {
    try {
      final data = jsonDecode(body);

      if (data is Map<String, dynamic>) {
        final detail = data['detail'];

        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }

        if (detail is List && detail.isNotEmpty) {
          return detail
              .map((item) {
                if (item is Map<String, dynamic>) {
                  return item['msg']?.toString() ?? item.toString();
                }

                return item.toString();
              })
              .join(', ');
        }

        final mensagem = data['message'] ?? data['mensagem'];

        if (mensagem != null && mensagem.toString().trim().isNotEmpty) {
          return mensagem.toString().trim();
        }
      }
    } catch (_) {
      // Mantém o corpo original quando não for possível interpretar o JSON.
    }

    final texto = body.trim();

    if (texto.isEmpty) {
      return 'Não foi possível concluir a operação.';
    }

    return texto;
  }
}

class EnderecoCep {
  final String cep;
  final String logradouro;
  final String bairro;
  final String cidade;
  final String uf;
  final int? codigoIbgeCidade;

  const EnderecoCep({
    required this.cep,
    required this.logradouro,
    required this.bairro,
    required this.cidade,
    required this.uf,
    this.codigoIbgeCidade,
  });

  factory EnderecoCep.fromJson(Map<String, dynamic> json) {
    final ibge = json['ibge']?.toString().trim() ?? '';
    return EnderecoCep(
      cep: json['cep']?.toString().trim() ?? '',
      logradouro: json['logradouro']?.toString().trim() ?? '',
      bairro: json['bairro']?.toString().trim() ?? '',
      cidade: json['localidade']?.toString().trim() ?? '',
      uf: json['uf']?.toString().trim().toUpperCase() ?? '',
      codigoIbgeCidade: int.tryParse(ibge),
    );
  }
}
