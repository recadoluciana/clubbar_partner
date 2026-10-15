import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/acompanhamento_vendas_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/acompanhamento_vendas.dart';

class IngressosVendidosEventoPage extends StatefulWidget {
  final EventoVendaResumo evento;

  const IngressosVendidosEventoPage({super.key, required this.evento});

  @override
  State<IngressosVendidosEventoPage> createState() =>
      _IngressosVendidosEventoPageState();
}

class _IngressosVendidosEventoPageState
    extends State<IngressosVendidosEventoPage> {
  final _repo = AcompanhamentoVendasRepository();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _data = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  List<IngressoVendido>? _ingressos;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final ingressos = await _repo.ingressosVendidosEvento(
        widget.evento.eventoId,
      );
      if (mounted) setState(() => _ingressos = ingressos);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Widget _linha(String rotulo, String valor, {IconData? icone}) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icone != null) ...[
          Icon(icone, size: 16, color: ClubbarColors.textoSecundario),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13),
              children: [
                TextSpan(
                  text: '$rotulo: ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: valor),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _card(IngressoVendido ingresso) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.confirmation_number_rounded,
                color: ClubbarColors.ambar,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ingresso.participante,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _moeda.format(ingresso.preco),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          _linha('Evento', widget.evento.nome, icone: Icons.event_rounded),
          _linha(
            'Data e hora do evento',
            _data.format(widget.evento.dataHora),
            icone: Icons.schedule_rounded,
          ),
          _linha('Lote', '${ingresso.numeroLote}º • ${ingresso.lote}'),
          _linha('Setor', ingresso.setor),
          _linha('Modalidade', ingresso.modalidade),
          _linha('Preço', _moeda.format(ingresso.preco)),
          if (ingresso.taxa > 0) _linha('Taxa', _moeda.format(ingresso.taxa)),
          _linha(
            'Compra',
            '#${ingresso.vendaId} realizada em ${_data.format(ingresso.dataCompra)}',
          ),
          _linha('Cliente', ingresso.cliente),
          _linha('Participante', ingresso.participante),
          if (ingresso.cpfParticipante.isNotEmpty)
            _linha('CPF do participante', ingresso.cpfParticipante),
          if (ingresso.quantidade > 1)
            _linha('Quantidade', '${ingresso.quantidade}'),
        ],
      ),
    ),
  );

  Widget _conteudo() {
    if (_ingressos == null && _erro == null) {
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

    final ingressos = _ingressos!;
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${ingressos.length} ingresso${ingressos.length == 1 ? '' : 's'} vendido${ingressos.length == 1 ? '' : 's'}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (ingressos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(child: Text('Nenhum ingresso vendido.')),
            ),
          ...ingressos.map(_card),
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
            titulo: 'Ingressos vendidos',
            subtitulo:
                '${widget.evento.nome} • ${_data.format(widget.evento.dataHora)}',
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
