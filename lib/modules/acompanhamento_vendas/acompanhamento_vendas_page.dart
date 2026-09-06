import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/acompanhamento_vendas_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/acompanhamento_vendas.dart';

class AcompanhamentoVendasPage extends StatefulWidget {
  const AcompanhamentoVendasPage({super.key});
  @override
  State<AcompanhamentoVendasPage> createState() =>
      _AcompanhamentoVendasPageState();
}

class _AcompanhamentoVendasPageState extends State<AcompanhamentoVendasPage> {
  final _repo = AcompanhamentoVendasRepository();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _data = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  ProdutosPendentesResumo? _produtos;
  List<EventoVendaResumo> _eventos = const [];
  String _periodo = 'FUTUROS';
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resultados = await Future.wait([
        _repo.produtosPendentes(),
        _repo.eventos(_periodo),
      ]);
      if (!mounted) return;
      setState(() {
        _produtos = resultados[0] as ProdutosPendentesResumo;
        _eventos = resultados[1] as List<EventoVendaResumo>;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString().replaceFirst('Exception: ', '');
        _carregando = false;
      });
    }
  }

  Future<void> _detalhar(EventoVendaResumo evento) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final detalhe = await _repo.detalheEvento(evento.eventoId);
      if (!mounted) return;
      Navigator.pop(context);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .72,
          maxChildSize: .94,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
            children: [
              Text(
                detalhe.nome,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: Colors.blue,
                ),
              ),
              Text(_data.format(detalhe.dataHora)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _resumo(
                      'Ingressos vendidos',
                      '${detalhe.quantidade}',
                      Icons.confirmation_number_rounded,
                      Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _resumo(
                      'Total recebido',
                      _moeda.format(detalhe.valorTotal),
                      Icons.payments_rounded,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Vendas por ingresso',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (detalhe.lotes.isEmpty)
                const Text('Nenhum ingresso configurado para este evento.'),
              ...detalhe.lotes.map(
                (lote) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${lote.numero}º lote • ${lote.nome}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Chip(label: Text('${lote.quantidade} vendidos')),
                          ],
                        ),
                        Text('${lote.setor} • ${_nomeTipo(lote.tipo)}'),
                        const SizedBox(height: 7),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Unitário: ${_moeda.format(lote.valorUnitario)}',
                            ),
                            Text(
                              _moeda.format(lote.valorTotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  String _nomeTipo(String tipo) =>
      {
        'INTEIRA': 'Inteira',
        'MEIA': 'Meia-entrada',
        'CORTESIA': 'Cortesia',
        'UNICO': 'Único',
      }[tipo] ??
      tipo;

  Widget _resumo(String titulo, String valor, IconData icone, Color cor) =>
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: cor.withValues(alpha: .25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: cor),
            const SizedBox(height: 7),
            Text(
              valor,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: cor,
              ),
            ),
            Text(
              titulo,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );

  Widget _conteudo() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(color: ClubbarColors.ambar),
      );
    }
    if (_erro != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 8),
            Text(_erro!, textAlign: TextAlign.center),
            TextButton.icon(
              onPressed: _carregar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    final produtos = _produtos!;
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Produtos vendidos a retirar',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Quantidade que deve estar disponível caso todos os clientes retirem seus produtos hoje.',
            style: TextStyle(color: ClubbarColors.textoSecundario),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _resumo(
                  'Unidades pendentes',
                  '${produtos.quantidadeTotal}',
                  Icons.inventory_2_rounded,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _resumo(
                  'Valor dos produtos',
                  _moeda.format(produtos.valorTotal),
                  Icons.sell_rounded,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (produtos.itens.isEmpty)
            const ClubbarCard(
              child: Text('Nenhum produto aguardando retirada.'),
            ),
          ...produtos.itens.map(
            (item) => ClubbarCard(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_drink_rounded,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.produto,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          item.loja,
                          style: const TextStyle(
                            color: ClubbarColors.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.quantidade} un.',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.blue,
                        ),
                      ),
                      Text(_moeda.format(item.valorTotal)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Acompanhamento de vendas de eventos',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
              ),
              DropdownButton<String>(
                value: _periodo,
                items: const [
                  DropdownMenuItem(value: 'FUTUROS', child: Text('Futuros')),
                  DropdownMenuItem(
                    value: 'REALIZADOS',
                    child: Text('Realizados'),
                  ),
                  DropdownMenuItem(value: 'TODOS', child: Text('Todos')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _periodo = value;
                    _carregar();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Selecione um evento para consultar ingressos vendidos e valores por lote, setor e tipo.',
            style: TextStyle(color: ClubbarColors.textoSecundario),
          ),
          const SizedBox(height: 10),
          if (_eventos.isEmpty)
            const ClubbarCard(
              child: Text('Nenhum evento encontrado neste período.'),
            ),
          ..._eventos.map(
            (evento) => ClubbarCard(
              onTap: () => _detalhar(evento),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_rounded,
                    size: 36,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          evento.nome,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.blue,
                          ),
                        ),
                        Text(
                          '${evento.loja} • ${_data.format(evento.dataHora)}',
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${evento.quantidade} ingressos • ${_moeda.format(evento.valorTotal)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: SafeArea(
      child: Column(
        children: [
          ClubbarPageHeader(
            titulo: 'Acompanhamento de vendas',
            subtitulo: 'Produtos a retirar e vendas de ingressos',
            trailing: IconButton(
              onPressed: _carregando ? null : _carregar,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          Expanded(child: _conteudo()),
        ],
      ),
    ),
  );
}
