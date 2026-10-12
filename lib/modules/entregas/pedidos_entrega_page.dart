import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/repositories/loja_repository.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';

class PedidosEntregaPage extends StatefulWidget {
  const PedidosEntregaPage({super.key});

  @override
  State<PedidosEntregaPage> createState() => _PedidosEntregaPageState();
}

class _PedidosEntregaPageState extends State<PedidosEntregaPage> {
  final LojaRepository _lojaRepository = LojaRepository();

  List<Map<String, dynamic>> _pedidos = const [];
  List<Loja> _lojas = const [];
  bool _carregando = true;
  bool _selecionandoEstabelecimento = false;
  int? _lojaIdSelecionada;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    try {
      final dados = await Future.wait([
        StorageService.getLojaId(),
        StorageService.getOrganizacaoId(),
      ]);
      final lojaVinculadaId = dados[0];
      final organizacaoId = dados[1];

      if (lojaVinculadaId != null && lojaVinculadaId > 0) {
        _lojaIdSelecionada = lojaVinculadaId;
        await _carregar();
        return;
      }

      if (organizacaoId == null || organizacaoId <= 0) {
        throw Exception('A organização do usuário não foi identificada.');
      }

      final lojas = await _lojaRepository.listar(organizacaoId);
      if (!mounted) return;
      setState(() {
        _lojas = lojas;
        _selecionandoEstabelecimento = true;
        _carregando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final usuarioId = await StorageService.getUsuarioId();
      if (usuarioId == null || usuarioId == 0) {
        throw Exception('Usuário não identificado.');
      }
      final resposta = await ApiService.get(
        '/entregas/pedidos-entrega?usuario_id=$usuarioId'
        '&loja_id=$_lojaIdSelecionada',
      );
      if (resposta.statusCode != 200) throw Exception(resposta.body);
      final dados = jsonDecode(resposta.body) as List<dynamic>;
      if (mounted) {
        setState(
          () => _pedidos = dados
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
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
        '/entregas/pedidos-entrega/$id/situacao?usuario_id=$usuarioId'
        '&loja_id=$_lojaIdSelecionada',
        {'situacao': situacao},
      );
      if (resposta.statusCode != 200) {
        throw Exception(resposta.body);
      }
      if (!mounted) {
        return;
      }
      AppSnackBar.sucesso(
        context,
        situacao == 'ACEITO'
            ? 'Pedido aceito.'
            : 'Pedido marcado como saiu para entrega.',
      );
      await _carregar();
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
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

  Widget _seletorEstabelecimento() {
    if (_lojas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhum estabelecimento está disponível para este usuário.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          margin: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.storefront_rounded),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Selecione o estabelecimento',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Escolha o estabelecimento cujos pedidos para entrega deseja acompanhar.',
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  initialValue: _lojaIdSelecionada,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Estabelecimento',
                    border: OutlineInputBorder(),
                  ),
                  items: _lojas
                      .map(
                        (loja) => DropdownMenuItem(
                          value: loja.lojaId,
                          child: Text(
                            loja.nmloja,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (lojaId) {
                    setState(() => _lojaIdSelecionada = lojaId);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _lojaIdSelecionada == null
                        ? null
                        : () {
                            setState(
                              () => _selecionandoEstabelecimento = false,
                            );
                            _carregar();
                          },
                    icon: const Icon(Icons.delivery_dining_rounded),
                    label: const Text('Ver pedidos para entrega'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_lojas.isNotEmpty)
                IconButton(
                  onPressed: _carregando
                      ? null
                      : () =>
                            setState(() => _selecionandoEstabelecimento = true),
                  icon: const Icon(Icons.storefront_rounded),
                  tooltip: 'Trocar estabelecimento',
                ),
              IconButton(
                onPressed: _carregando ? null : _carregar,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Atualizar pedidos',
              ),
            ],
          ),
        ),
        Expanded(
          child: _selecionandoEstabelecimento
              ? _seletorEstabelecimento()
              : _carregando
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
                                if (situacao == 'ENTREGUE') ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE1F5E8),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF18763B),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Entregue em ${pedido['dtrecebimento_fmt'] ?? 'data não informada'}',
                                                style: const TextStyle(
                                                  color: Color(0xFF18763B),
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              if ('${pedido['nmusuariorecebimento'] ?? ''}'
                                                  .trim()
                                                  .isNotEmpty)
                                                Text(
                                                  'Responsável: ${pedido['nmusuariorecebimento']}',
                                                  style: const TextStyle(
                                                    color: Color(0xFF18763B),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
