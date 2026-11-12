import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/repositories/loja_repository.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../models/loja.dart';

class TitularEstabelecimentosSecao extends StatefulWidget {
  const TitularEstabelecimentosSecao({
    super.key,
    required this.organizacaoId,
    required this.titularId,
    required this.habilitado,
    required this.onAlterado,
  });

  final int organizacaoId;
  final int titularId;
  final bool habilitado;
  final VoidCallback onAlterado;

  @override
  State<TitularEstabelecimentosSecao> createState() =>
      _TitularEstabelecimentosSecaoState();
}

class _TitularEstabelecimentosSecaoState
    extends State<TitularEstabelecimentosSecao> {
  final _repository = LojaRepository();
  List<Loja> _lojas = [];
  Map<int, Map<String, dynamic>> _configuracoes = {};
  bool _carregando = true;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  String _detalhe(String body) {
    try {
      return '${jsonDecode(body)['detail'] ?? 'Não foi possível concluir a operação.'}';
    } catch (_) {
      return 'Não foi possível concluir a operação.';
    }
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lojas = await _repository.listar(widget.organizacaoId);
      final configs = await Future.wait(
        lojas.map((loja) async {
          final response = await ApiService.get(
            '/lojas/${loja.lojaId}/mercado-pago',
          );
          if (response.statusCode != 200) {
            throw Exception(_detalhe(response.body));
          }
          return Map<String, dynamic>.from(jsonDecode(response.body));
        }),
      );
      if (!mounted) return;
      setState(() {
        _lojas = lojas;
        _configuracoes = {
          for (var i = 0; i < lojas.length; i++) lojas[i].lojaId: configs[i],
        };
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _erro = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _associar() async {
    int? lojaId;
    String? provedor = 'MERCADO_PAGO';
    final resultado = await showDialog<({int lojaId, String provedor})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, atualizar) => AlertDialog(
          title: const Text('Associar estabelecimento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Escolha o estabelecimento e o provedor para as novas vendas.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: lojaId,
                  decoration: const InputDecoration(
                    labelText: 'Estabelecimento',
                  ),
                  items: _lojas
                      .map(
                        (loja) => DropdownMenuItem(
                          value: loja.lojaId,
                          child: Text(loja.nmloja),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => atualizar(() {
                    lojaId = value;
                    provedor = 'MERCADO_PAGO';
                  }),
                ),
                if (lojaId != null) ...[
                  const SizedBox(height: 12),
                  Text(_descricaoAtual(_configuracoes[lojaId!])),
                  RadioGroup<String>(
                    groupValue: provedor,
                    onChanged: (value) => atualizar(() => provedor = value),
                    child: const Column(
                      children: [
                        RadioListTile<String>(
                          value: 'MERCADO_PAGO',
                          title: Text('Mercado Pago'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: lojaId == null || provedor == null
                  ? null
                  : () => Navigator.pop(context, (
                      lojaId: lojaId!,
                      provedor: provedor!,
                    )),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (resultado == null || !mounted) return;
    setState(() => _salvando = true);
    try {
      final response = await ApiService.put(
        '/lojas/${resultado.lojaId}/provedor-pagamento',
        {
          'titularfinanceiro_id': widget.titularId,
          'provedor_pagamento': resultado.provedor,
        },
      );
      if (response.statusCode != 200) throw Exception(_detalhe(response.body));
      if (!mounted) return;
      AppSnackBar.sucesso(
        context,
        'Recebimentos do estabelecimento atualizados.',
      );
      widget.onAlterado();
    } catch (error) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  String _descricaoAtual(Map<String, dynamic>? config) {
    if (config == null || config['titularfinanceiro_id'] == null) {
      return 'Ainda não possui titular financeiro.';
    }
    final nome = config['provedor_pagamento'] == 'MERCADO_PAGO'
        ? 'Mercado Pago'
        : 'Asaas';
    return config['titularfinanceiro_id'] == widget.titularId
        ? 'Este titular já está associado com $nome.'
        : 'Este estabelecimento já possui outro titular; ao salvar, a associação será substituída.';
  }

  @override
  Widget build(BuildContext context) {
    final vinculadas = _lojas
        .where(
          (loja) =>
              _configuracoes[loja.lojaId]?['titularfinanceiro_id'] ==
              widget.titularId,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Estabelecimentos e recebimentos',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (_carregando)
          const Center(child: CircularProgressIndicator())
        else if (_erro != null) ...[
          Text(_erro!),
          TextButton.icon(
            onPressed: _carregar,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ] else ...[
          if (vinculadas.isEmpty)
            const Text('Nenhum estabelecimento associado a este titular.'),
          for (final loja in vinculadas)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(loja.nmloja),
              subtitle: Text(
                _configuracoes[loja.lojaId]?['provedor_pagamento'] ==
                        'MERCADO_PAGO'
                    ? 'Mercado Pago'
                    : 'Asaas',
              ),
            ),
          OutlinedButton.icon(
            onPressed: !widget.habilitado || _salvando || _lojas.isEmpty
                ? null
                : _associar,
            icon: const Icon(Icons.link),
            label: Text(
              _lojas.isEmpty
                  ? 'Nenhum estabelecimento cadastrado'
                  : 'Associar ou alterar estabelecimento',
            ),
          ),
        ],
      ],
    );
  }
}
