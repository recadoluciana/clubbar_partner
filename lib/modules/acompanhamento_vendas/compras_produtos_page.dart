import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/acompanhamento_vendas_repository.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/utils/horario_brasil.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/acompanhamento_vendas.dart';
import '../../models/loja.dart';

class ComprasProdutosPage extends StatefulWidget {
  const ComprasProdutosPage({super.key});

  @override
  State<ComprasProdutosPage> createState() => _ComprasProdutosPageState();
}

class _ComprasProdutosPageState extends State<ComprasProdutosPage> {
  final _repo = AcompanhamentoVendasRepository();
  final _lojaRepository = LojaRepository();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _data = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

  List<CompraProduto> _compras = const [];
  List<CompraProduto> _comprasResumo = const [];
  List<Loja> _lojas = const [];
  int? _lojaId;
  String _situacao = 'TODOS';
  String _busca = '';
  bool _carregando = true;
  String? _erro;
  late DateTime _inicio;
  late DateTime _fim;

  @override
  void initState() {
    super.initState();
    final agora = HorarioBrasil.agora();
    _fim = DateTime(agora.year, agora.month, agora.day);
    _inicio = _fim.subtract(const Duration(days: 30));
    _inicializar();
  }

  Future<void> _inicializar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final organizacaoId = await StorageService.getOrganizacaoId();
      if (organizacaoId == null || organizacaoId <= 0) {
        throw Exception('Organização não identificada.');
      }
      final lojas = await _lojaRepository.listar(organizacaoId);
      if (!mounted) return;
      setState(() {
        _lojas = lojas;
        _lojaId = null;
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

  Future<void> _carregar({bool mostrarCarregamento = true}) async {
    if (mostrarCarregamento) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }
    try {
      final resumoFuture = _repo.comprasProdutos(
        situacao: 'TODOS',
        lojaId: _lojaId,
        inicio: _inicio,
        fim: _fim,
      );
      final comprasFuture = _situacao == 'TODOS'
          ? resumoFuture
          : _repo.comprasProdutos(
              situacao: _situacao,
              lojaId: _lojaId,
              inicio: _inicio,
              fim: _fim,
            );
      final resultados = await Future.wait([resumoFuture, comprasFuture]);
      final resumo = resultados[0];
      final compras = resultados[1];
      if (!mounted) return;
      setState(() {
        _comprasResumo = resumo;
        _compras = compras;
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

  List<CompraProduto> _filtrarBusca(List<CompraProduto> compras) {
    final termo = _busca.trim().toLowerCase();
    if (termo.isEmpty) return compras;
    return compras.where((compra) {
      return compra.produto.toLowerCase().contains(termo) ||
          compra.cliente.toLowerCase().contains(termo) ||
          compra.emailCliente.toLowerCase().contains(termo);
    }).toList();
  }

  List<CompraProduto> get _comprasFiltradas => _filtrarBusca(_compras);

  List<CompraProduto> get _comprasResumoFiltradas =>
      _filtrarBusca(_comprasResumo);

  Future<void> _selecionarLoja(int? lojaId) async {
    if (lojaId == null) return;
    setState(() {
      _lojaId = lojaId;
      _situacao = 'TODOS';
      _busca = '';
    });
    await _carregar();
  }

  Future<void> _selecionarPeriodo() async {
    final periodo = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: HorarioBrasil.agora(),
      initialDateRange: DateTimeRange(start: _inicio, end: _fim),
      locale: const Locale('pt', 'BR'),
      helpText: 'Selecione o período das compras',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (periodo == null) return;
    setState(() {
      _inicio = periodo.start;
      _fim = periodo.end;
    });
    await _carregar();
  }

  Widget _filtroPeriodo() => Card(
    child: ListTile(
      leading: const Icon(
        Icons.calendar_month_outlined,
        color: ClubbarColors.primaria,
      ),
      title: const Text('Período da consulta', style: TextStyle(fontSize: 12)),
      subtitle: Text(
        '${DateFormat('dd/MM/yyyy').format(_inicio)} a ${DateFormat('dd/MM/yyyy').format(_fim)}',
      ),
      trailing: const Icon(Icons.edit_calendar_outlined),
      onTap: _carregando ? null : _selecionarPeriodo,
    ),
  );

  Widget _imagemProduto(CompraProduto compra) {
    final imagem = compra.imagemProduto.trim();
    final fallback = Container(
      color: ClubbarColors.infoClaro,
      child: const Icon(Icons.shopping_bag_rounded, color: ClubbarColors.info),
    );
    if (imagem.isEmpty) return fallback;
    return Image.network(
      ApiConfig.buildUrl(imagem),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  Widget _badge({
    required String texto,
    required Color cor,
    required IconData icone,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: cor.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 14, color: cor),
        const SizedBox(width: 4),
        Text(
          texto,
          style: TextStyle(
            color: cor,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _resumo(String titulo, int quantidade, Color cor, String situacao) {
    final selecionado = _situacao == situacao;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selecionado,
        child: Material(
          color: cor.withValues(alpha: selecionado ? .16 : .09),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selecionado ? cor : cor.withValues(alpha: .22),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _carregando || selecionado
                ? null
                : () {
                    setState(() => _situacao = situacao);
                    _carregar();
                  },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$quantidade',
                          style: TextStyle(
                            color: cor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (selecionado)
                        Icon(Icons.check_circle_rounded, size: 18, color: cor),
                    ],
                  ),
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _listaLojas() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Selecione o estabelecimento',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      if (_lojas.isEmpty) const Text('Nenhum estabelecimento disponível.'),
      ..._lojas.map((loja) {
        final imagem = (loja.urllogoloja ?? loja.urlfachadaloja ?? '').trim();
        final ativo = (loja.sitloja ?? '').toUpperCase() == 'ATIVA';
        return Card(
          child: ListTile(
            leading: imagem.isEmpty
                ? const Icon(Icons.storefront_outlined)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      ApiConfig.buildUrl(imagem),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.storefront_outlined),
                    ),
                  ),
            title: Text(loja.nmloja),
            subtitle: Text(
              ativo ? 'Ativo' : 'Inativo',
              style: TextStyle(
                color: ativo ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selecionarLoja(loja.lojaId),
          ),
        );
      }),
    ],
  );

  Widget _valorResumo(String titulo, String valor, Color cor) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 34,
            child: Text(
              titulo,
              maxLines: 2,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: TextStyle(
                color: cor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final compras = _comprasFiltradas;
    final comprasResumo = _comprasResumoFiltradas;
    final compradas = comprasResumo.fold(
      0,
      (soma, compra) => soma + compra.quantidade,
    );
    final pendentes = comprasResumo
        .where((compra) => !compra.retirado)
        .fold(0, (soma, compra) => soma + compra.quantidade);
    final retirados = comprasResumo
        .where((compra) => compra.retirado)
        .fold(0, (soma, compra) => soma + compra.quantidade);
    final valorVendido = comprasResumo.fold<double>(
      0,
      (soma, compra) => soma + compra.valorTotal,
    );
    final comissaoDisponivel = comprasResumo.every(
      (compra) => compra.valorAposComissao != null,
    );
    final valorAposComissao = comprasResumo.fold<double>(
      0,
      (soma, compra) => soma + (compra.valorAposComissao ?? 0),
    );
    final liquidoDisponivel = comprasResumo.every(
      (compra) => compra.liquidoEstimado != null,
    );
    final liquidoEstimado = comprasResumo.fold<double>(
      0,
      (soma, compra) => soma + (compra.liquidoEstimado ?? 0),
    );
    final simulacaoDisponivel = comprasResumo.every(
      (compra) => compra.simulacaoSemComissao != null,
    );
    final simulacaoSemComissao = comprasResumo.fold<double>(
      0,
      (soma, compra) => soma + (compra.simulacaoSemComissao ?? 0),
    );

    return PopScope(
      canPop: _lojaId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _lojaId != null) setState(() => _lojaId = null);
      },
      child: Scaffold(
        backgroundColor: ClubbarColors.fundo,
        appBar: ClubbarAppBar(
          mostrarVoltar: true,
          onVoltar: () {
            if (_lojaId != null) {
              setState(() => _lojaId = null);
            } else {
              Navigator.maybePop(context);
            }
          },
        ),
        body: SafeArea(
          child: Column(
            children: [
              ClubbarPageHeader(
                titulo: 'Produtos vendidos / entregues',
                subtitulo:
                    _lojas
                        .where((loja) => loja.lojaId == _lojaId)
                        .firstOrNull
                        ?.nmloja ??
                    'Escolha o estabelecimento',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Atualizar',
                      onPressed: _carregando
                          ? null
                          : (_lojaId == null ? _inicializar : _carregar),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _carregando
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: ClubbarColors.primaria,
                        ),
                      )
                    : _erro != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_rounded, size: 48),
                              const SizedBox(height: 10),
                              Text(_erro!, textAlign: TextAlign.center),
                              TextButton.icon(
                                onPressed: _lojaId == null
                                    ? _inicializar
                                    : _carregar,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _lojaId == null
                    ? _listaLojas()
                    : RefreshIndicator(
                        onRefresh: _carregar,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _filtroPeriodo(),
                            const SizedBox(height: 10),
                            TextField(
                              onChanged: (valor) =>
                                  setState(() => _busca = valor),
                              decoration: InputDecoration(
                                hintText: 'Buscar cliente ou produto',
                                prefixIcon: const Icon(Icons.search_rounded),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: ClubbarColors.borda,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _resumo(
                                  'Unidades vendidas',
                                  compradas,
                                  ClubbarColors.info,
                                  'TODOS',
                                ),
                                const SizedBox(width: 10),
                                _resumo(
                                  'Unidades a entregar',
                                  pendentes,
                                  ClubbarColors.aviso,
                                  'PENDENTES',
                                ),
                                const SizedBox(width: 10),
                                _resumo(
                                  'Unidades entregues',
                                  retirados,
                                  ClubbarColors.sucesso,
                                  'RETIRADOS',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _valorResumo(
                                  'Valor bruto',
                                  _moeda.format(valorVendido),
                                  ClubbarColors.info,
                                ),
                                const SizedBox(width: 10),
                                _valorResumo(
                                  'Após comissão Clubbar',
                                  comissaoDisponivel
                                      ? _moeda.format(valorAposComissao)
                                      : 'Indisponível',
                                  ClubbarColors.sucesso,
                                ),
                                const SizedBox(width: 10),
                                _valorResumo(
                                  'Após taxa MPago (estimativa)',
                                  liquidoDisponivel
                                      ? _moeda.format(liquidoEstimado)
                                      : 'Indisponível',
                                  ClubbarColors.sucesso,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _valorResumo(
                                  'Simulação sem comissão Clubbar',
                                  simulacaoDisponivel
                                      ? _moeda.format(simulacaoSemComissao)
                                      : 'Indisponível',
                                  ClubbarColors.info,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Simulação: considera comissão Clubbar zero. A cobrança real de produtos continua seguindo a taxa cadastrada na loja.',
                              style: TextStyle(
                                fontSize: 11,
                                color: ClubbarColors.textoSecundario,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              !comissaoDisponivel
                                  ? 'Valor após comissão indisponível: faltam dados de uma ou mais vendas.'
                                  : liquidoDisponivel
                                  ? 'Estimativa com Pix 0,99% e crédito 4,99%; a tarifa real pode variar.'
                                  : 'Líquido após processamento indisponível: faltam dados de pagamento ou comissão para uma ou mais vendas.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: ClubbarColors.textoSecundario,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${compras.length} compra${compras.length == 1 ? '' : 's'} encontrada${compras.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: ClubbarColors.textoSecundario,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (compras.isEmpty)
                              const ClubbarCard(
                                child: Text(
                                  'Nenhuma compra de produto encontrada.',
                                ),
                              ),
                            ...compras.map(
                              (compra) => ClubbarCard(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: _imagemProduto(compra),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  compra.produto,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              if (compra.cortesia)
                                                _badge(
                                                  texto: 'Cortesia',
                                                  cor: ClubbarColors.primaria,
                                                  icone: Icons
                                                      .card_giftcard_rounded,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            compra.cliente,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (compra.emailCliente.isNotEmpty)
                                            Text(
                                              compra.emailCliente,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: ClubbarColors
                                                    .textoSecundario,
                                              ),
                                            ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '${compra.loja} • Compra em ${_data.format(compra.dataCompra)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color:
                                                  ClubbarColors.textoSecundario,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              _badge(
                                                texto: compra.retirado
                                                    ? 'Entregue'
                                                    : 'Aguardando entrega',
                                                cor: compra.retirado
                                                    ? ClubbarColors.sucesso
                                                    : ClubbarColors.aviso,
                                                icone: compra.retirado
                                                    ? Icons.check_circle_rounded
                                                    : Icons.inventory_2_rounded,
                                              ),
                                              Text(
                                                '${compra.quantidade} un. • ${_moeda.format(compra.valorTotal)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (compra.retirado &&
                                              compra.dataRetirada != null) ...[
                                            const SizedBox(height: 5),
                                            Text(
                                              'Entregue em ${_data.format(compra.dataRetirada!)}${compra.responsavelRetirada.isEmpty ? '' : ' • ${compra.responsavelRetirada}'}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: ClubbarColors
                                                    .textoSecundario,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
