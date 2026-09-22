import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/acompanhamento_vendas_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/acompanhamento_vendas.dart';

class DetalheVendasEventoPage extends StatefulWidget {
  final EventoVendaResumo evento;

  const DetalheVendasEventoPage({super.key, required this.evento});

  @override
  State<DetalheVendasEventoPage> createState() =>
      _DetalheVendasEventoPageState();
}

class _DetalheVendasEventoPageState extends State<DetalheVendasEventoPage> {
  final _repo = AcompanhamentoVendasRepository();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _data = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  EventoVendaDetalhe? _detalhe;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final detalhe = await _repo.detalheEvento(widget.evento.eventoId);
      if (!mounted) return;
      setState(() => _detalhe = detalhe);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _nomeTipo(String tipo) =>
      {
        'INTEIRA': 'Inteira',
        'MEIA': 'Meia-entrada',
        'MEIA_LEGAL': 'Meia-entrada',
        'MEIA_IDOSO': 'Meia idoso',
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
                fontSize: 18,
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

  Widget _ocupacao(EventoVendaDetalhe detalhe) {
    final percentual = detalhe.percentualOcupacao.clamp(0, 100).toDouble();
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ocupação do evento',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${percentual.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentual / 100,
            color: Colors.red,
            backgroundColor: Colors.red.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(10),
            minHeight: 8,
          ),
          const SizedBox(height: 6),
          Text(
            '${detalhe.quantidade} vendidos • ${detalhe.quantidadeRestante} restantes • capacidade ${detalhe.capacidadeTotal}',
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _cardLote(List<LoteVendaResumo> precos) {
    final lote = precos.first;
    final restante = lote.quantidadeRestante;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${lote.numero}º lote • ${lote.nome}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(lote.setor),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(label: Text('${lote.quantidadeVendidaLote} vendidos')),
                Chip(
                  label: Text(
                    restante == null
                        ? 'Sem limite definido'
                        : '$restante restantes',
                  ),
                ),
              ],
            ),
            const Divider(),
            ...precos.map(
              (preco) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nomeTipo(preco.tipo),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${preco.quantidade} vendidos • ${_moeda.format(preco.valorUnitario)} cada',
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _moeda.format(preco.valorTotal),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conteudo() {
    if (_detalhe == null && _erro == null) {
      return const Center(
        child: CircularProgressIndicator(color: ClubbarColors.ambar),
      );
    }
    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 10),
              Text(_erro!, textAlign: TextAlign.center),
              TextButton.icon(
                onPressed: _carregar,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final detalhe = _detalhe!;
    final lotesAgrupados = <int, List<LoteVendaResumo>>{};
    for (final lote in detalhe.lotes) {
      lotesAgrupados.putIfAbsent(lote.loteId, () => []).add(lote);
    }
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          const SizedBox(height: 10),
          _ocupacao(detalhe),
          const SizedBox(height: 16),
          const Text(
            'Vendas por lote e setor',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (detalhe.lotes.isEmpty)
            const Text('Nenhum ingresso configurado para este evento.'),
          ...lotesAgrupados.values.map(_cardLote),
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
            titulo: widget.evento.nome,
            subtitulo:
                'Ingressos vendidos • ${_data.format(widget.evento.dataHora)}',
            tituloStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.blue,
            ),
          ),
          Expanded(child: _conteudo()),
        ],
      ),
    ),
  );
}
