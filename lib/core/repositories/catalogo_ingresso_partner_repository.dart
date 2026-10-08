import 'dart:convert';

import '../../models/evento_lote.dart';
import '../services/api_service.dart';

class CatalogoIngressoPartnerRepository {
  Exception _erro(dynamic response, String padrao) {
    try {
      final dados = jsonDecode(response.body);
      if (dados is Map && dados['detail'] != null) {
        return Exception(dados['detail'].toString());
      }
    } catch (_) {}
    return Exception(padrao);
  }

  Future<List<ModalidadeIngressoCatalogo>> listarModalidades({
    bool incluirInativos = false,
  }) async {
    final response = await ApiService.get(
      '/ingressos-catalogo/parceiro/modalidades${incluirInativos ? '?incluir_inativos=true' : ''}',
    );
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível carregar as modalidades.');
    }
    return (jsonDecode(response.body) as List)
        .map(
          (e) => ModalidadeIngressoCatalogo.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<List<BeneficioIngressoCatalogo>> listarBeneficios({
    bool incluirInativos = false,
  }) async {
    final response = await ApiService.get(
      '/ingressos-catalogo/parceiro/beneficios${incluirInativos ? '?incluir_inativos=true' : ''}',
    );
    if (response.statusCode != 200) {
      throw _erro(response, 'Não foi possível carregar os benefícios.');
    }
    return (jsonDecode(response.body) as List)
        .map(
          (e) => BeneficioIngressoCatalogo.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<void> salvarBeneficio({
    BeneficioIngressoCatalogo? atual,
    required String codigo,
    required String nome,
    required bool exigeComprovante,
    required String situacao,
  }) async {
    final dados = {
      'cdbeneficio': codigo.trim().toUpperCase(),
      'nmbeneficio': nome.trim(),
      'exigecomprovante': exigeComprovante,
      'situacao': situacao,
      'nrordem': atual?.ordem ?? 99,
    };
    final response = atual == null
        ? await ApiService.post(
            '/ingressos-catalogo/parceiro/beneficios',
            dados,
          )
        : await ApiService.put(
            '/ingressos-catalogo/parceiro/beneficios/${atual.id}',
            dados,
          );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _erro(response, 'Não foi possível salvar o benefício.');
    }
  }

  Future<void> salvarModalidade({
    ModalidadeIngressoCatalogo? atual,
    required String codigo,
    required String nome,
    required String tipo,
    required bool exigeBeneficio,
    required bool exigeComprovante,
    required List<int> beneficiosIds,
    required String situacao,
  }) async {
    final dados = {
      'cdmodalidade': codigo.trim().toUpperCase(),
      'nmmodalidade': nome.trim(),
      'tipomodalidade': tipo,
      'aplicacotalegal': false,
      'exigebeneficio': exigeBeneficio,
      'exigecomprovante': exigeComprovante,
      'permitepersonalizarnome': true,
      'situacao': situacao,
      'nrordem': atual?.ordem ?? 99,
      'beneficios_ids': beneficiosIds,
    };
    final response = atual == null
        ? await ApiService.post(
            '/ingressos-catalogo/parceiro/modalidades',
            dados,
          )
        : await ApiService.put(
            '/ingressos-catalogo/parceiro/modalidades/${atual.id}',
            dados,
          );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _erro(response, 'Não foi possível salvar a modalidade.');
    }
  }

  Future<void> excluirBeneficio(int id) async {
    final response = await ApiService.delete(
      '/ingressos-catalogo/parceiro/beneficios/$id',
    );
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw _erro(response, 'Não foi possível excluir o benefício.');
  }

  Future<void> excluirModalidade(int id) async {
    final response = await ApiService.delete(
      '/ingressos-catalogo/parceiro/modalidades/$id',
    );
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw _erro(response, 'Não foi possível excluir a modalidade.');
  }
}
