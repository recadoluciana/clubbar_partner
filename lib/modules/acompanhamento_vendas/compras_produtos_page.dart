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
      final dados = await Future.wait([
        StorageService.getOrganizacaoId(),
        StorageService.getLojaId(),
      ]);
      final organizacaoId = dados[0];
      final lojaVinculadaId = dados[1];
      if (organizacaoId == null || organizacaoId <= 0) {
        throw Exception('Organização não identificada.');
      }
      final lojas = await _lojaRepository.listar(organizacaoId);
      if (!mounted) return;
      setState(() {
        _lojas = lojas;
        _lojaId = lojas.any((loja) => loja.lojaId == lojaVinculadaId)
            ? lojaVinculadaId
            : lojas.firstOrNull?.lojaId;
      });
      await _carregar(mostrarCarregamento: false);
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
      final compras = await _repo.comprasProdutos(
        situacao: _situacao,
        lojaId: _lojaId,
        inicio: _inicio,
        fim: _fim,
      );
      if (!mounted) return;
      setState(() {
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

  Future<void> _selecionarLoja(int? lojaId) async {
    if (lojaId == null || lojaId == _lojaId) return;
    setState(() => _lojaId = lojaId);
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

  Widget _seletorEstabelecimento() {
    if (_lojas.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<int>(
      key: ValueKey(_lojaId),
      initialValue: _lojaId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Estabelecimento',
        prefixIcon: Icon(Icons.storefront_rounded),
        border: OutlineInputBorder(),
      ),
      items: _lojas
          .map(
            (loja) => DropdownMenuItem<int>(
              value: loja.lojaId,
              child: Text(loja.nmloja, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: _carregando ? null : _selecionarLoja,
    );
  }

  Widget _filtroPeriodo() => OutlinedButton.icon(
    onPressed: _carregando ? null : _selecionarPeriodo,
    icon: const Icon(Icons.date_range_rounded),
    label: Text(
      'Período: ${DateFormat('dd/MM/yy').format(_inicio)} a ${DateFormat('dd/MM/yy').format(_fim)}',
    ),
  );

  List<CompraProduto> get _comprasFiltradas {
    final termo = _busca.trim().toLowerCase();
    if (termo.isEmpty) return _compras;
    return _compras.where((compra) {
      return compra.produto.toLowerCase().contains(termo) ||
          compra.cliente.toLowerCase().contains(termo) ||
          compra.emailCliente.toLowerCase().contains(termo) ||
          compra.loja.toLowerCase().contains(termo);
    }).toList();
  }

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

  Widget _resumo(String titulo, int quantidade, Color cor) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$quantidade',
            style: TextStyle(
              color: cor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            titulo,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final compras = _comprasFiltradas;
    final compradas = compras.fold(
      0,
      (soma, compra) => soma + compra.quantidade,
    );
    final pendentes = compras
        .where((compra) => !compra.retirado)
        .fold(0, (soma, compra) => soma + compra.quantidade);
    final retirados = compras
        .where((compra) => compra.retirado)
        .fold(0, (soma, compra) => soma + compra.quantidade);

    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: 'Compras de produtos',
              subtitulo: 'Clientes, produtos comprados e situação de retirada',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Alterar período',
                    onPressed: _carregando ? null : _selecionarPeriodo,
                    icon: const Icon(Icons.date_range_rounded),
                  ),
                  IconButton(
                    tooltip: 'Atualizar',
                    onPressed: _carregando ? null : _carregar,
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
                              onPressed: _carregar,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _carregar,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _seletorEstabelecimento(),
                          if (_lojas.isNotEmpty) const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _filtroPeriodo(),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            onChanged: (valor) =>
                                setState(() => _busca = valor),
                            decoration: InputDecoration(
                              hintText:
                                  'Buscar cliente, produto ou estabelecimento',
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
                                'Unidades compradas',
                                compradas,
                                ClubbarColors.info,
                              ),
                              const SizedBox(width: 10),
                              _resumo(
                                'Unidades a retirar',
                                pendentes,
                                ClubbarColors.aviso,
                              ),
                              const SizedBox(width: 10),
                              _resumo(
                                'Unidades retiradas',
                                retirados,
                                ClubbarColors.sucesso,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final filtro in const [
                                ('TODOS', 'Todas'),
                                ('PENDENTES', 'A retirar'),
                                ('RETIRADOS', 'Retiradas'),
                              ])
                                ChoiceChip(
                                  label: Text(filtro.$2),
                                  selected: _situacao == filtro.$1,
                                  selectedColor: ClubbarColors.primariaClaro,
                                  onSelected: (_) {
                                    if (_situacao != filtro.$1) {
                                      setState(() => _situacao = filtro.$1);
                                      _carregar();
                                    }
                                  },
                                ),
                            ],
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
                                                icone:
                                                    Icons.card_giftcard_rounded,
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
                                              color:
                                                  ClubbarColors.textoSecundario,
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
                                                  ? 'Retirado'
                                                  : 'Aguardando retirada',
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
                                            'Retirada em ${_data.format(compra.dataRetirada!)}${compra.responsavelRetirada.isEmpty ? '' : ' • ${compra.responsavelRetirada}'}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color:
                                                  ClubbarColors.textoSecundario,
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
    );
  }
}
