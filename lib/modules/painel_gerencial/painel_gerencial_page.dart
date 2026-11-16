import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/painel_gerencial_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/utils/horario_brasil.dart';
import '../../core/widgets/app_snackbar.dart';
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
    Color(0xFF1F8A4C),
    Color(0xFF1976D2),
    Color(0xFFE64A19),
    Color(0xFFF9A825),
    Color(0xFF7E57C2),
    Color(0xFF00838F),
  ];

  Color _corGrafico(int indice) => indice < _coresGrafico.length
      ? _coresGrafico[indice]
      : HSVColor.fromAHSV(1, (indice * 137.508) % 360, .7, .72).toColor();

  PainelGerencial? _painel;
  bool _carregando = true;
  String? _erro;
  String _nomeOrganizacao = 'Empresa não identificada';
  String _cargo = '';
  DateTime _mesSelecionado = DateTime(
    HorarioBrasil.agora().year,
    HorarioBrasil.agora().month,
  );

  bool get _podeTrocarMes => _cargo == 'SUPERADMIN' || _cargo == 'ADMIN';
  bool get _mesAtual {
    final agora = HorarioBrasil.agora();
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
    final agora = HorarioBrasil.agora();
    final atual = DateTime(agora.year, agora.month);
    if (novo.isAfter(atual)) return;
    setState(() {
      _mesSelecionado = novo;
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
          color: Colors.white,
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

  Widget _kpi({required String titulo, required String valor}) {
    return Column(
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _totalComDetalhes(
    String titulo,
    double total,
    double? produtos,
    double? ingressos,
  ) {
    return ClubbarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _kpi(
                  titulo: 'Produtos',
                  valor: produtos == null
                      ? 'Indisponível'
                      : _moeda.format(produtos),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpi(
                  titulo: 'Ingressos',
                  valor: ingressos == null
                      ? 'Indisponível'
                      : _moeda.format(ingressos),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpi(titulo: 'Total', valor: _moeda.format(total)),
              ),
            ],
          ),
        ],
      ),
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
            'Participação por estabelecimento',
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
                      color: _corGrafico(index),
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
                        color: _corGrafico(index),
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

  Widget _graficoProdutos(
    List<ItemRankingGerencial> produtos, {
    bool porValor = false,
  }) {
    final itens = produtos.take(5).toList();
    final maior = itens.fold<double>(
      0,
      (valor, item) =>
          (porValor ? item.valor : item.quantidade.toDouble()) > valor
          ? (porValor ? item.valor : item.quantidade.toDouble())
          : valor,
    );
    return ClubbarCard(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            porValor
                ? 'Produtos mais vendidos (por valor)'
                : 'Produtos mais vendidos (por qtde)',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
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
                    leftTitles: porValor
                        ? AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 58,
                              getTitlesWidget: (value, meta) => Text(
                                _moeda.format(value),
                                style: const TextStyle(fontSize: 9),
                              ),
                            ),
                          )
                        : const AxisTitles(
                            sideTitles: SideTitles(showTitles: true),
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
                          toY: porValor
                              ? itens[index].valor
                              : itens[index].quantidade.toDouble(),
                          width: 18,
                          color: _corGrafico(index),
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
    bool coresDoGrafico = false,
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
                      backgroundColor: coresDoGrafico
                          ? _corGrafico(entry.key)
                          : ClubbarColors.ambarClaro,
                      foregroundColor: coresDoGrafico
                          ? Colors.white
                          : ClubbarColors.preto,
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
    final produtosPorValor = produtosOrdenadosPorValor(
      painel.produtosMaisVendidos,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final largo = constraints.maxWidth >= 820;
        return Column(
          children: [
            _totalComDetalhes(
              'Vendido hoje',
              painel.totalHoje,
              painel.totalProdutosHoje,
              painel.totalIngressosHoje,
            ),
            const SizedBox(height: 14),
            _seletorMes(),
            const SizedBox(height: 14),
            if (_carregando)
              const Center(child: CircularProgressIndicator())
            else if (_erro != null)
              _EstadoErro(mensagem: _erro!, onTentarNovamente: _carregar)
            else ...[
              _totalComDetalhes(
                'Vendido no mês',
                painel.totalMes,
                painel.totalProdutosMes,
                painel.totalIngressosMes,
              ),
              const SizedBox(height: 14),
              if (largo)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _participacao(painel)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _graficoProdutos(painel.produtosMaisVendidos),
                    ),
                  ],
                )
              else ...[
                _participacao(painel),
                const SizedBox(height: 14),
                _graficoProdutos(painel.produtosMaisVendidos),
              ],
              const SizedBox(height: 14),
              if (largo)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ranking(
                        titulo: 'Ranking de produtos (por qtde)',
                        coresDoGrafico: true,
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
                  titulo: 'Ranking de produtos (por qtde)',
                  coresDoGrafico: true,
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
              const SizedBox(height: 14),
              if (largo)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _graficoProdutos(produtosPorValor, porValor: true),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _ranking(
                        titulo: 'Ranking de produtos (por valor)',
                        coresDoGrafico: true,
                        itens: produtosPorValor,
                        vazio: 'Nenhum produto vendido.',
                      ),
                    ),
                  ],
                )
              else ...[
                _graficoProdutos(produtosPorValor, porValor: true),
                const SizedBox(height: 14),
                _ranking(
                  titulo: 'Ranking de produtos (por valor)',
                  coresDoGrafico: true,
                  itens: produtosPorValor,
                  vazio: 'Nenhum produto vendido.',
                ),
              ],
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 60,
        automaticallyImplyLeading: false,
        titleSpacing: 8,
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, size: 25),
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/corujao.png',
              height: 40,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _nomeOrganizacao,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        actions: [_botaoAtualizar(), const SizedBox(width: 12)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: 'Visão Gerencial',
              subtitulo: '',
              tituloWidget: const Center(
                child: Text(
                  'Visão Gerencial',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: ClubbarColors.primariaEscuro,
                  ),
                ),
              ),
              subtituloWidget: const SizedBox.shrink(),
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
