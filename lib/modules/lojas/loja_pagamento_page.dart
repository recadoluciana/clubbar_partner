import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/api_service.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';

class LojaPagamentoPage extends StatefulWidget {
  final Loja loja;

  const LojaPagamentoPage({super.key, required this.loja});

  @override
  State<LojaPagamentoPage> createState() => _LojaPagamentoPageState();
}

class _LojaPagamentoPageState extends State<LojaPagamentoPage> {
  bool _carregando = true;
  bool _salvando = false;
  Map<String, dynamic>? _configuracao;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  String _erro(String corpo) {
    try {
      final dados = jsonDecode(corpo);
      if (dados is Map && dados['detail'] != null) return '${dados['detail']}';
    } catch (_) {}
    return corpo.isEmpty ? 'Não foi possível concluir a operação.' : corpo;
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final resposta = await ApiService.get(
        '/lojas/${widget.loja.lojaId}/mercado-pago',
      );
      if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
        throw Exception(_erro(resposta.body));
      }
      if (mounted) {
        setState(
          () => _configuracao = Map<String, dynamic>.from(
            jsonDecode(resposta.body),
          ),
        );
      }
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

  Future<void> _conectarMercadoPago() async {
    setState(() => _salvando = true);
    try {
      final resposta = await ApiService.post(
        '/lojas/${widget.loja.lojaId}/mercado-pago/autorizacao',
        const {},
      );
      if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
        throw Exception(_erro(resposta.body));
      }
      final url = '${jsonDecode(resposta.body)['authorization_url'] ?? ''}';
      if (url.isEmpty ||
          !await launchUrl(
            Uri.parse(url),
            mode: kIsWeb
                ? LaunchMode.platformDefault
                : LaunchMode.externalApplication,
          )) {
        throw Exception(
          'Não foi possível abrir a autorização do Mercado Pago.',
        );
      }
      if (mounted) {
        AppSnackBar.sucesso(
          context,
          'Conclua a autorização no Mercado Pago e depois toque em atualizar.',
        );
      }
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

  Future<void> _selecionar(String provedor) async {
    setState(() => _salvando = true);
    try {
      final resposta = await ApiService.put(
        '/lojas/${widget.loja.lojaId}/provedor-pagamento',
        {'provedor_pagamento': provedor},
      );
      if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
        throw Exception(_erro(resposta.body));
      }
      if (mounted) {
        setState(
          () => _configuracao = Map<String, dynamic>.from(
            jsonDecode(resposta.body),
          ),
        );
        AppSnackBar.sucesso(context, 'Provedor de pagamentos atualizado.');
      }
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
    final provedor = '${_configuracao?['provedor_pagamento'] ?? 'ASAAS'}';
    final conectada = _configuracao?['conectada'] == true;
    final mercadoPagoUserId =
        '${_configuracao?['mercadopago_user_id'] ?? ''}'.trim();
    final mercadoPagoNome =
        '${_configuracao?['mercadopago_nome'] ?? ''}'.trim();
    return Scaffold(
      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: 'Recebimentos',
            subtitulo: widget.loja.nmloja,
            trailing: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _carregando ? null : _carregar,
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Provedor ativo',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          leading: Icon(
                            provedor == 'MERCADO_PAGO'
                                ? Icons.storefront_rounded
                                : Icons.account_balance_rounded,
                          ),
                          title: Text(
                            provedor == 'MERCADO_PAGO'
                                ? 'Mercado Pago'
                                : 'Asaas',
                          ),
                          subtitle: const Text(
                            'O cliente usa este provedor no checkout desta loja.',
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Mercado Pago',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    conectada
                                        ? Icons.verified_rounded
                                        : Icons.link_off_rounded,
                                    color: conectada
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    conectada
                                        ? 'Conta conectada'
                                        : 'Conta ainda não conectada',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'A conta do parceiro recebe a venda; o Clubbar registra a comissão configurada no checkout.',
                              ),
                              if (conectada && mercadoPagoUserId.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                if (mercadoPagoNome.isNotEmpty)
                                  Text(
                                    mercadoPagoNome,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                Text(
                                  'Conta conectada — ID Mercado Pago: $mercadoPagoUserId',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _salvando
                                        ? null
                                        : _conectarMercadoPago,
                                    icon: const Icon(Icons.link_rounded),
                                    label: Text(
                                      conectada
                                          ? 'Conectar outra conta'
                                          : 'Conectar conta Mercado Pago',
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed:
                                        _salvando ||
                                            !conectada ||
                                            provedor == 'MERCADO_PAGO'
                                        ? null
                                        : () => _selecionar('MERCADO_PAGO'),
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                    ),
                                    label: const Text('Usar Mercado Pago'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _salvando || provedor == 'ASAAS'
                            ? null
                            : () => _selecionar('ASAAS'),
                        icon: const Icon(Icons.account_balance_rounded),
                        label: const Text('Voltar a usar Asaas'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
