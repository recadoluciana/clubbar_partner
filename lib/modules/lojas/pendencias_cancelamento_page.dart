import 'package:flutter/material.dart';

import '../../core/repositories/loja_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/horario_brasil.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';

class PendenciasCancelamentoPage extends StatefulWidget {
  final Loja loja;
  final List<Map<String, dynamic>> pendencias;

  const PendenciasCancelamentoPage({
    super.key,
    required this.loja,
    required this.pendencias,
  });

  @override
  State<PendenciasCancelamentoPage> createState() =>
      _PendenciasCancelamentoPageState();
}

class _PendenciasCancelamentoPageState
    extends State<PendenciasCancelamentoPage> {
  late List<Map<String, dynamic>> pendencias = widget.pendencias;
  Loja get loja => widget.loja;
  bool _carregando = false;

  Future<void> _atualizar() async {
    setState(() => _carregando = true);
    try {
      final dados = await LojaRepository().consultarCancelamento(loja.lojaId);
      final lista = (dados['pendencias'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (mounted) setState(() => pendencias = lista);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível atualizar as pendências.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _texto(dynamic valor, {String vazio = 'Não informado'}) {
    final texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? vazio : texto;
  }

  String _data(dynamic valor, {bool comHora = false}) {
    final data = HorarioBrasil.deTextoBrasil(valor);
    if (data == null) return 'Não informada';
    final base =
        '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    if (!comHora) return base;
    return '$base às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  String _cpf(dynamic valor) {
    return Formatters.cpfMascarado(_texto(valor));
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
    final nome = _texto(
      item['nome'],
      vazio: ehIngresso ? 'Ingresso' : 'Produto',
    );
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
                child: ehIngresso && item['data_evento'] != null
                    ? Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$nome • ',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: ClubbarColors.textoPrincipal,
                              ),
                            ),
                            TextSpan(
                              text: _data(item['data_evento'], comHora: true),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        nome,
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
              Icons.badge_outlined,
              'Participante: ${_texto(item['nome_participante'])}',
            ),
            _linha(
              Icons.fingerprint_rounded,
              'CPF: ${_cpf(item['cpf_participante'])}',
            ),
            _linha(
              Icons.confirmation_number_outlined,
              'Tipo de ingresso: ${_texto(item['tipo_ingresso'])}',
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
    appBar: ClubbarAppBar(
      mostrarVoltar: true,
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _carregando ? null : _atualizar,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
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
