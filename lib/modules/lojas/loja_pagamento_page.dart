import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/services/api_service.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';
import '../financeiro_onboarding/titular_financeiro_repository.dart';

class LojaPagamentoPage extends StatefulWidget {
  const LojaPagamentoPage({super.key, required this.loja});
  final Loja loja;

  @override
  State<LojaPagamentoPage> createState() => _LojaPagamentoPageState();
}

class _LojaPagamentoPageState extends State<LojaPagamentoPage> {
  final _repo = TitularFinanceiroRepository();
  List<Map<String, dynamic>> _titulares = [];
  int? _titularId;
  String _provedor = 'MERCADO_PAGO';
  Map<String, dynamic>? _mercadoPago;
  bool _carregando = true, _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  String _erro(String corpo) {
    try {
      return '${jsonDecode(corpo)['detail'] ?? 'Não foi possível concluir a operação.'}';
    } catch (_) {
      return 'Não foi possível concluir a operação.';
    }
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final titulares = await _repo.listar(widget.loja.organizacaoId);
      final resposta = await ApiService.get(
        '/lojas/${widget.loja.lojaId}/mercado-pago',
      );
      if (resposta.statusCode != 200) throw Exception(_erro(resposta.body));
      final config = jsonDecode(resposta.body);
      if (!mounted) return;
      setState(() {
        _titularId = config['titularfinanceiro_id'] as int?;
        _titulares = titulares
            .where(
              (t) =>
                  '${t['sittitular'] ?? 'ATIVO'}'.toUpperCase() == 'ATIVO' ||
                  t['titularfinanceiro_id'] == _titularId,
            )
            .toList();
        _provedor = 'MERCADO_PAGO';
      });
      await _carregarMercadoPago();
    } catch (erro) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _carregarMercadoPago() async {
    final id = _titularId;
    if (id == null) {
      if (mounted) setState(() => _mercadoPago = null);
      return;
    }
    final resposta = await ApiService.get(
      '/organizacoes/${widget.loja.organizacaoId}/titulares/$id/mercado-pago',
    );
    if (resposta.statusCode != 200) throw Exception(_erro(resposta.body));
    if (mounted && _titularId == id) {
      setState(
        () =>
            _mercadoPago = Map<String, dynamic>.from(jsonDecode(resposta.body)),
      );
    }
  }

  Future<void> _salvar() async {
    if (_titularId == null) {
      AppSnackBar.erro(context, 'Selecione um titular financeiro.');
      return;
    }
    setState(() => _salvando = true);
    try {
      final resposta = await ApiService.put(
        '/lojas/${widget.loja.lojaId}/provedor-pagamento',
        {'titularfinanceiro_id': _titularId, 'provedor_pagamento': _provedor},
      );
      if (resposta.statusCode != 200) throw Exception(_erro(resposta.body));
      if (mounted) {
        AppSnackBar.sucesso(
          context,
          'Titular e provedor de recebimentos atualizados.',
        );
      }
      await _carregar();
    } catch (erro) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mpPronto = _mercadoPago?['conectada'] == true;
    return Scaffold(
      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: 'Recebimentos',
            subtitulo: widget.loja.nmloja,
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _carregando ? null : _carregar,
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        'Selecione o titular financeiro e o provedor usado nas novas vendas.',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _titularId,
                        decoration: const InputDecoration(
                          labelText: 'Titular financeiro',
                        ),
                        items: _titulares
                            .map(
                              (t) => DropdownMenuItem<int>(
                                value: t['titularfinanceiro_id'] as int,
                                child: Text('${t['nmrazaosocial']}'),
                              ),
                            )
                            .toList(),
                        onChanged: _salvando
                            ? null
                            : (id) async {
                                setState(() {
                                  _titularId = id;
                                  _mercadoPago = null;
                                });
                                try {
                                  await _carregarMercadoPago();
                                } catch (erro) {
                                  if (context.mounted) {
                                    AppSnackBar.erro(
                                      context,
                                      erro.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                      const SizedBox(height: 16),
                      RadioGroup<String>(
                        groupValue: _provedor,
                        onChanged: (valor) {
                          if (!_salvando && valor != null) {
                            setState(() => _provedor = valor);
                          }
                        },
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              value: 'MERCADO_PAGO',
                              title: const Text('Mercado Pago'),
                              subtitle: Text(
                                mpPronto
                                    ? 'Conta conectada: ${_mercadoPago?['nome'] ?? ''}'
                                    : 'Conta ainda não conectada',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _salvando ? null : _salvar,
                        child: const Text('Salvar recebimentos'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
