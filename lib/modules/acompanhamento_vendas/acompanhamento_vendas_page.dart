import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/acompanhamento_vendas_repository.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/acompanhamento_vendas.dart';
import '../../models/loja.dart';
import 'detalhe_vendas_evento_page.dart';

enum TipoAcompanhamento { produtos, ingressos }

class AcompanhamentoVendasPage extends StatefulWidget {
  const AcompanhamentoVendasPage({super.key, required this.tipo});
  final TipoAcompanhamento tipo;
  @override
  State<AcompanhamentoVendasPage> createState() =>
      _AcompanhamentoVendasPageState();
}

class _AcompanhamentoVendasPageState extends State<AcompanhamentoVendasPage> {
  final _repo = AcompanhamentoVendasRepository();
  final _lojaRepository = LojaRepository();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _data = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  ProdutosPendentesResumo? _produtos;
  List<EventoVendaResumo> _eventos = const [];
  List<Loja> _lojas = const [];
  int? _lojaId;
  String _periodo = 'FUTUROS';
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
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
        _lojaId = widget.tipo == TipoAcompanhamento.ingressos
            ? null
            : (lojas.any((loja) => loja.lojaId == lojaVinculadaId)
                  ? lojaVinculadaId
                  : lojas.firstOrNull?.lojaId);
        if (_lojaId == null && widget.tipo == TipoAcompanhamento.ingressos) {
          _carregando = false;
        }
      });
      if (_lojaId != null || widget.tipo == TipoAcompanhamento.produtos) {
        await _carregar(mostrarCarregamento: false);
      }
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
      final produtos = widget.tipo == TipoAcompanhamento.produtos
          ? await _repo.produtosPendentes(lojaId: _lojaId)
          : null;
      final eventos = widget.tipo == TipoAcompanhamento.ingressos
          ? await _repo.eventos(_periodo, lojaId: _lojaId)
          : null;
      if (!mounted) return;
      setState(() {
        _produtos = produtos;
        _eventos = eventos ?? const [];
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

  Widget _listaEstabelecimentos() => ListView(
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

  Widget _seletorEstabelecimento() {
    if (_lojas.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: DropdownButtonFormField<int>(
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
        ),
      ),
    );
  }

  Future<void> _detalhar(EventoVendaResumo evento) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetalheVendasEventoPage(evento: evento),
      ),
    );
  }

  Widget _imagemEvento(EventoVendaResumo evento) {
    final imagem = evento.imagemEvento.trim();
    final fallback = Container(
      color: Colors.deepPurple.withValues(alpha: .10),
      child: const Icon(
        Icons.event_rounded,
        size: 30,
        color: Colors.deepPurple,
      ),
    );
    if (imagem.isEmpty) return fallback;

    return Image.network(
      ApiConfig.buildUrl(imagem),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  Widget _imagemProduto(ProdutoPendente produto) {
    final imagem = produto.imagemProduto.trim();
    final fallback = Container(
      color: Colors.blue.withValues(alpha: .10),
      child: const Icon(Icons.local_drink_rounded, color: Colors.blue),
    );
    if (imagem.isEmpty) return fallback;

    return Image.network(
      ApiConfig.buildUrl(imagem),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }

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

  Widget? _estadoComum() {
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
              onPressed:
                  _lojaId == null && widget.tipo == TipoAcompanhamento.ingressos
                  ? _inicializar
                  : _carregar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    return null;
  }

  Widget _conteudoProdutos() {
    final estado = _estadoComum();
    if (estado != null) return estado;
    final produtos = _produtos!;
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Produtos vendidos a entregar',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Quantidade que deve estar disponível para entregar aos clientes.',
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
              child: Text('Nenhum produto aguardando entrega.'),
            ),
          ...produtos.itens.map(
            (item) => ClubbarCard(
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: _imagemProduto(item),
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
        ],
      ),
    );
  }

  Widget _filtroPeriodo(String titulo, String valor, IconData icone) {
    final selecionado = _periodo == valor;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selecionado,
        child: Material(
          color: ClubbarColors.primaria.withValues(
            alpha: selecionado ? .16 : .09,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selecionado
                  ? ClubbarColors.primaria
                  : ClubbarColors.primaria.withValues(alpha: .22),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: selecionado || _carregando
                ? null
                : () {
                    setState(() => _periodo = valor);
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
                        child: Icon(
                          icone,
                          color: ClubbarColors.primaria,
                          size: 22,
                        ),
                      ),
                      if (selecionado)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: ClubbarColors.primaria,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
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

  Widget _conteudoIngressos() {
    final estado = _estadoComum();
    if (estado != null) return estado;
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Ingressos vendidos',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _filtroPeriodo('Futuros', 'FUTUROS', Icons.event_rounded),
              const SizedBox(width: 10),
              _filtroPeriodo(
                'Realizados',
                'REALIZADOS',
                Icons.event_available_rounded,
              ),
              const SizedBox(width: 10),
              _filtroPeriodo('Todos', 'TODOS', Icons.calendar_month_rounded),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: _imagemEvento(evento),
                    ),
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
                          '${evento.quantidade} ingressos',
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
  Widget build(BuildContext context) => PopScope(
    canPop: widget.tipo != TipoAcompanhamento.ingressos || _lojaId == null,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop &&
          widget.tipo == TipoAcompanhamento.ingressos &&
          _lojaId != null) {
        setState(() {
          _lojaId = null;
          _erro = null;
        });
      }
    },
    child: Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: ClubbarAppBar(
        mostrarVoltar: true,
        onVoltar: () {
          if (widget.tipo == TipoAcompanhamento.ingressos && _lojaId != null) {
            setState(() {
              _lojaId = null;
              _erro = null;
            });
          } else {
            Navigator.maybePop(context);
          }
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: widget.tipo == TipoAcompanhamento.produtos
                  ? 'Produtos a entregar'
                  : 'Ingressos vendidos',
              subtitulo: widget.tipo == TipoAcompanhamento.produtos
                  ? 'Acompanhamento de produtos pendentes'
                  : _lojas
                            .where((loja) => loja.lojaId == _lojaId)
                            .firstOrNull
                            ?.nmloja ??
                        'Escolha o estabelecimento',
              trailing: IconButton(
                onPressed: _carregando
                    ? null
                    : (widget.tipo == TipoAcompanhamento.ingressos &&
                              _lojaId == null
                          ? _inicializar
                          : _carregar),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            if (widget.tipo == TipoAcompanhamento.produtos)
              _seletorEstabelecimento(),
            Expanded(
              child: widget.tipo == TipoAcompanhamento.produtos
                  ? _conteudoProdutos()
                  : _lojaId == null && !_carregando && _erro == null
                  ? _listaEstabelecimentos()
                  : _conteudoIngressos(),
            ),
          ],
        ),
      ),
    ),
  );
}
