import 'package:flutter/material.dart';

import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';

class PendenciasCancelamentoPage extends StatelessWidget {
  final Loja loja;
  final List<Map<String, dynamic>> pendencias;

  const PendenciasCancelamentoPage({
    super.key,
    required this.loja,
    required this.pendencias,
  });

  String _texto(dynamic valor, {String vazio = 'Não informado'}) {
    final texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? vazio : texto;
  }

  String _data(dynamic valor, {bool comHora = false}) {
    final data = DateTime.tryParse(valor?.toString() ?? '')?.toLocal();
    if (data == null) return 'Não informada';
    final base =
        '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    if (!comHora) return base;
    return '$base às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  Widget _linha(IconData icone, String texto) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 18, color: ClubbarColors.textoSecundario),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 14,
              color: ClubbarColors.textoSecundario,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _card(Map<String, dynamic> item) {
    final ehIngresso = item['tipo'] == 'INGRESSO';
    final local = [
      _texto(item['local_evento'], vazio: ''),
      _texto(item['endereco_evento'], vazio: ''),
    ].where((texto) => texto.isNotEmpty).join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClubbarColors.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ehIngresso
                    ? Icons.confirmation_number_outlined
                    : Icons.shopping_bag_outlined,
                color: ClubbarColors.primaria,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _texto(
                    item['nome'],
                    vazio: ehIngresso ? 'Ingresso' : 'Produto',
                  ),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: ClubbarColors.avisoClaro,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${item['quantidade'] ?? 1}x',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _linha(Icons.person_outline_rounded, _texto(item['nome_cliente'])),
          _linha(Icons.email_outlined, _texto(item['email_cliente'])),
          _linha(Icons.phone_outlined, _texto(item['telefone_cliente'])),
          _linha(
            Icons.shopping_cart_outlined,
            'Compra realizada em ${_data(item['data_compra'], comHora: true)}',
          ),
          if (ehIngresso) ...[
            _linha(
              Icons.event_outlined,
              'Evento em ${_data(item['data_evento'], comHora: true)}',
            ),
            if (local.isNotEmpty) _linha(Icons.location_on_outlined, local),
          ] else if (item['validade_produto'] != null)
            _linha(
              Icons.event_available_outlined,
              'Válido até ${_data(item['validade_produto'])}',
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: Column(
      children: [
        ClubbarPageHeader(
          titulo: loja.nmloja,
          subtitulo: 'Itens Pendentes de Retirada',
          tituloStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Colors.blue,
          ),
        ),
        Expanded(
          child: pendencias.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      'Não há produtos ou ingressos pendentes de retirada neste estabelecimento.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '${pendencias.length} item(ns) aguardando retirada ou uso.',
                      style: const TextStyle(
                        color: ClubbarColors.textoSecundario,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...pendencias.map(_card),
                  ],
                ),
        ),
      ],
    ),
  );
}
