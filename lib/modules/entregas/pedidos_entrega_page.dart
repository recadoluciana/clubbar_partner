import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';

class PedidosEntregaPage extends StatefulWidget {
  const PedidosEntregaPage({super.key});

  @override
  State<PedidosEntregaPage> createState() => _PedidosEntregaPageState();
}

class _PedidosEntregaPageState extends State<PedidosEntregaPage> {
  List<Map<String, dynamic>> _pedidos = const [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final usuarioId = await StorageService.getUsuarioId();
      if (usuarioId == null || usuarioId == 0)
        throw Exception('Usuário não identificado.');
      final resposta = await ApiService.get(
        '/entregas/pedidos-entrega?usuario_id=$usuarioId',
      );
      if (resposta.statusCode != 200) throw Exception(resposta.body);
      final dados = jsonDecode(resposta.body) as List<dynamic>;
      if (mounted)
        setState(
          () => _pedidos = dados
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
    } catch (e) {
      if (mounted)
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _mudarSituacao(
    Map<String, dynamic> pedido,
    String situacao,
  ) async {
    try {
      final usuarioId = await StorageService.getUsuarioId();
      final id = pedido['pedidoentrega_id'];
      final resposta = await ApiService.post(
        '/entregas/pedidos-entrega/$id/situacao?usuario_id=$usuarioId',
        {'situacao': situacao},
      );
      if (resposta.statusCode != 200) throw Exception(resposta.body);
      if (!mounted) return;
      AppSnackBar.sucesso(
        context,
        situacao == 'ACEITO'
            ? 'Pedido aceito.'
            : 'Pedido marcado como saiu para entrega.',
      );
      await _carregar();
    } catch (e) {
      if (mounted)
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _situacao(Map<String, dynamic> pedido) {
    switch ('${pedido['situacao'] ?? ''}'.toUpperCase()) {
      case 'AGUARDANDO_ACEITE':
        return 'Aguardando aceite';
      case 'ACEITO':
        return 'Aceito';
      case 'EM_ROTA':
        return 'Em rota';
      case 'ENTREGUE':
        return 'Entregue';
      case 'RECUSADO':
        return 'Recusado';
      default:
        return 'Cancelado';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6F6F6),
    appBar: ClubbarAppBar(mostrarVoltar: true),
    body: Column(
      children: [
        ClubbarPageHeader(
          titulo: 'Pedidos para entrega',
          subtitulo:
              'Aceite o pedido e informe quando ele sair para o cliente.',
          trailing: IconButton(
            onPressed: _carregando ? null : _carregar,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_pedidos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 48),
                          child: Center(
                            child: Text(
                              'Nenhum pedido para entrega no momento.',
                            ),
                          ),
                        ),
                      ..._pedidos.map((pedido) {
                        final situacao = '${pedido['situacao'] ?? ''}'
                            .toUpperCase();
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Venda #${pedido['venda_id']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 17,
                                        ),
                                      ),
                                    ),
                                    Chip(label: Text(_situacao(pedido))),
                                  ],
                                ),
                                Text(
                                  '${pedido['nmcliente'] ?? ''} • R\$ ${pedido['total'] ?? '0'}',
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${pedido['itens_resumo'] ?? ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${pedido['endereco'] ?? ''}',
                                      ),
                                    ),
                                  ],
                                ),
                                if ('${pedido['observacao'] ?? ''}'
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text('Obs.: ${pedido['observacao']}'),
                                ],
                                if (situacao == 'AGUARDANDO_ACEITE' ||
                                    situacao == 'ACEITO') ...[
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: () => _mudarSituacao(
                                        pedido,
                                        situacao == 'AGUARDANDO_ACEITE'
                                            ? 'ACEITO'
                                            : 'EM_ROTA',
                                      ),
                                      icon: Icon(
                                        situacao == 'AGUARDANDO_ACEITE'
                                            ? Icons.check_circle_outline
                                            : Icons.local_shipping_outlined,
                                      ),
                                      label: Text(
                                        situacao == 'AGUARDANDO_ACEITE'
                                            ? 'Aceitar pedido'
                                            : 'Marcar como saiu para entrega',
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );
}
