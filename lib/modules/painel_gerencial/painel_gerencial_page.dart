import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/painel_gerencial_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/painel_gerencial.dart';

class PainelGerencialPage extends StatefulWidget {
  const PainelGerencialPage({super.key});

  @override
  State<PainelGerencialPage> createState() => _PainelGerencialPageState();
}

class _PainelGerencialPageState extends State<PainelGerencialPage> {
  final _repository = PainelGerencialRepository();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _inteiro = NumberFormat.decimalPattern('pt_BR');

  static const _coresGrafico = <Color>[
    ClubbarColors.ambar,
    ClubbarColors.info,
    ClubbarColors.sucesso,
    ClubbarColors.aviso,
    Color(0xFF7E57C2),
    Color(0xFF00838F),
  ];

  PainelGerencial? _painel;
  bool _carregando = true;
  String? _erro;
  String _nomeOrganizacao = 'Empresa não identificada';
  String _cargo = '';
  DateTime _mesSelecionado = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  bool get _podeTrocarMes => _cargo == 'SUPERADMIN' || _cargo == 'ADMIN';
  bool get _mesAtual {
    final agora = DateTime.now();
    return _mesSelecionado.year == agora.year &&
        _mesSelecionado.month == agora.month;
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  String _mensagemErro(Object erro) =>
      erro.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();

  Future<void> _carregar() async {
    if (!_carregando) setState(() => _carregando = true);
    try {
      final resultados = await Future.wait([
        _repository.buscar(
          ano: _mesSelecionado.year,
          mes: _mesSelecionado.month,
        ),
        StorageService.getNomeOrganizacao(),
        StorageService.getCargo(),
      ]);
      if (!mounted) return;
      final nome = (resultados[1] as String? ?? '').trim();
      setState(() {
        _painel = resultados[0] as PainelGerencial;
        _nomeOrganizacao = nome.isEmpty ? 'Empresa não identificada' : nome;
        _cargo = (resultados[2] as String? ?? '').trim().toUpperCase();
        _erro = null;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      final mensagem = _mensagemErro(e);
      setState(() {
        _erro = mensagem;
        _carregando = false;
      });
      AppSnackBar.erro(context, mensagem);
    }
  }

  Future<void> _mudarMes(int deslocamento) async {
    if (!_podeTrocarMes || _carregando) return;
    final novo = DateTime(
      _mesSelecionado.year,
      _mesSelecionado.month + deslocamento,
    );
    final atual = DateTime(DateTime.now().year, DateTime.now().month);
    if (novo.isAfter(atual)) return;
    setState(() {
      _mesSelecionado = novo;
      _painel = null;
      _erro = null;
    });
    await _carregar();
  }

  String _tituloMes() {
    final nome = DateFormat('MMMM', 'pt_BR').format(_mesSelecionado);
    return '${nome[0].toUpperCase()}${nome.substring(1)} de ${_mesSelecionado.year}';
  }

  Widget _botaoAtualizar() {
    return Tooltip(
      message: 'Atualizar',
      child: SizedBox.square(
        dimension: 40,
        child: IconButton(
          onPressed: _carregando ? null : _carregar,
          icon: const Icon(Icons.refresh_rounded, size: 22),
          color: ClubbarColors.preto,
          style: IconButton.styleFrom(
            backgroundColor: ClubbarColors.ambar,
            disabledBackgroundColor: ClubbarColors.borda,
            shape: const CircleBorder(),
          ),
        ),
      ),
    );
  }

  Widget _seletorMes() {
    Widget navegacao({required bool anterior}) {
      if (!_podeTrocarMes) return const SizedBox.square(dimension: 40);
      return IconButton(
        tooltip: anterior ? 'Mês anterior' : 'Próximo mês',
        onPressed: _carregando || (!anterior && _mesAtual)
            ? null
            : () => _mudarMes(anterior ? -1 : 1),
        icon: Icon(
          anterior ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
        ),
      );
    }

    return Row(
      children: [
        navegacao(anterior: true),
        Expanded(
          child: Text(
            _tituloMes(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: ClubbarColors.textoSecundario,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        navegacao(anterior: false),
      ],
    );
  }

  Widget _kpi({
    required String titulo,
    required String valor,
    required IconData icone,
  }) {
    return ClubbarCard(
      elevation: 1,
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ClubbarColors.ambarClaro,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icone, color: ClubbarColors.ambarEscuro),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ClubbarColors.textoSecundario,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    valor,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpis(PainelGerencial painel) {
    final referenciaMes = painel.periodoFim ?? DateTime.now();
    final nomeMes = DateFormat('MMMM', 'pt_BR').format(referenciaMes);

    final itens = [
      (
        'Total vendido hoje',
        _moeda.format(painel.totalHoje),
        Icons.payments_outlined,
      ),
      (
        'Total vendido no mês - $nomeMes',
        _moeda.format(painel.totalMes),
        Icons.bar_chart_rounded,
      ),
      (
        'Total vendido em produtos no mês',
        _moeda.format(painel.totalProdutosMes),
        Icons.shopping_bag_outlined,
      ),
      (
        'Total vendido em ingressos no mês',
        _moeda.format(painel.totalIngressosMes),
        Icons.confirmation_number_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final colunas = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final largura = (constraints.maxWidth - (12 * (colunas - 1))) / colunas;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: itens
              .map(
                (item) => SizedBox(
                  width: largura,
                  child: _kpi(titulo: item.$1, valor: item.$2, icone: item.$3),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _participacao(PainelGerencial painel) {
    final itens = painel.participacaoLojas;
    return ClubbarCard(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Participação por loja',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          if (itens.isEmpty || painel.totalMes <= 0)
            const _EstadoSemDados(mensagem: 'Nenhuma venda paga no período.')
          else ...[
            SizedBox(
              height: 190,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 38,
                  sectionsSpace: 2,
                  sections: List.generate(itens.length, (index) {
                    final item = itens[index];
                    return PieChartSectionData(
                      color: _coresGrafico[index % _coresGrafico.length],
                      value: item.valor,
                      radius: 52,
                      title: '${item.percentual.toStringAsFixed(1)}%',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(itens.length, (index) {
              final item = itens[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: _coresGrafico[index % _coresGrafico.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.nomeLoja,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _moeda.format(item.valor),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _graficoProdutos(PainelGerencial painel) {
    final itens = painel.produtosMaisVendidos.take(5).toList();
    final maior = itens.fold<int>(
      0,
      (valor, item) => item.quantidade > valor ? item.quantidade : valor,
    );
    return ClubbarCard(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Produtos mais vendidos',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          if (itens.isEmpty)
            const _EstadoSemDados(
              mensagem: 'Nenhum produto vendido no período.',
            )
          else
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  maxY: maior <= 0 ? 1 : maior * 1.2,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 38,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= itens.length) {
                            return const SizedBox.shrink();
                          }
                          final nome = itens[index].nome;
                          return Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Text(
                              nome.length > 8
                                  ? '${nome.substring(0, 8)}…'
                                  : nome,
                              style: const TextStyle(fontSize: 9),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(itens.length, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: itens[index].quantidade.toDouble(),
                          width: 18,
                          color: ClubbarColors.ambar,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ranking({
    required String titulo,
    required List<ItemRankingGerencial> itens,
    required String vazio,
  }) {
    return ClubbarCard(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          if (itens.isEmpty)
            _EstadoSemDados(mensagem: vazio)
          else
            ...itens.take(5).toList().asMap().entries.map((entry) {
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: ClubbarColors.ambarClaro,
                      foregroundColor: ClubbarColors.preto,
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.nome,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${_inteiro.format(item.quantidade)} vendidos • ${_moeda.format(item.valor)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: ClubbarColors.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _conteudo(PainelGerencial painel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largo = constraints.maxWidth >= 820;
        return Column(
          children: [
            _kpis(painel),
            const SizedBox(height: 14),
            if (largo)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _participacao(painel)),
                  const SizedBox(width: 14),
                  Expanded(child: _graficoProdutos(painel)),
                ],
              )
            else ...[
              _participacao(painel),
              const SizedBox(height: 14),
              _graficoProdutos(painel),
            ],
            const SizedBox(height: 14),
            if (largo)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ranking(
                      titulo: 'Ranking de produtos',
                      itens: painel.produtosMaisVendidos,
                      vazio: 'Nenhum produto vendido.',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ranking(
                      titulo: 'Ranking de ingressos',
                      itens: painel.ingressosMaisVendidos,
                      vazio: 'Nenhum ingresso vendido.',
                    ),
                  ),
                ],
              )
            else ...[
              _ranking(
                titulo: 'Ranking de produtos',
                itens: painel.produtosMaisVendidos,
                vazio: 'Nenhum produto vendido.',
              ),
              const SizedBox(height: 14),
              _ranking(
                titulo: 'Ranking de ingressos',
                itens: painel.ingressosMaisVendidos,
                vazio: 'Nenhum ingresso vendido.',
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: _nomeOrganizacao,
              subtitulo: _tituloMes(),
              subtituloWidget: _seletorMes(),
              trailing: _botaoAtualizar(),
            ),
            Expanded(
              child: _carregando && _painel == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: ClubbarColors.ambar,
                      ),
                    )
                  : _erro != null && _painel == null
                  ? _EstadoErro(mensagem: _erro!, onTentarNovamente: _carregar)
                  : RefreshIndicator(
                      onRefresh: _carregar,
                      color: ClubbarColors.ambar,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [_conteudo(_painel!)],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoSemDados extends StatelessWidget {
  final String mensagem;
  const _EstadoSemDados({required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ClubbarColors.textoSecundario),
        ),
      ),
    );
  }
}

class _EstadoErro extends StatelessWidget {
  final String mensagem;
  final Future<void> Function() onTentarNovamente;
  const _EstadoErro({required this.mensagem, required this.onTentarNovamente});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: ClubbarColors.erro,
            ),
            const SizedBox(height: 12),
            Text(mensagem, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onTentarNovamente,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
              style: FilledButton.styleFrom(
                backgroundColor: ClubbarColors.ambar,
                foregroundColor: ClubbarColors.preto,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
