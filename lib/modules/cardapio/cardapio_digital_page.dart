import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/categoria_repository.dart';
import '../../core/repositories/produto_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/categoria.dart';
import '../../models/loja.dart';
import '../categorias/categoria_list_page.dart';
import '../produtos/produto_form_page.dart';
import '../produtos/produto_list_page.dart';

class CardapioDigitalPage extends StatefulWidget {
  final Loja loja;
  const CardapioDigitalPage({super.key, required this.loja});

  @override
  State<CardapioDigitalPage> createState() => _CardapioDigitalPageState();
}

class _CardapioDigitalPageState extends State<CardapioDigitalPage> {
  final _categoriasRepo = CategoriaRepository();
  final _produtosRepo = ProdutoRepository();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  List<Categoria> _categorias = [];
  List<Map<String, dynamic>> _produtos = [];
  int? _categoriaId;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final resultados = await Future.wait([
        _categoriasRepo.listar(widget.loja.lojaId),
        _produtosRepo.listar(widget.loja.lojaId),
      ]);
      final categorias =
          (resultados[0] as List<Categoria>)
              .where(
                (c) => (c.sitcategoria ?? 'ATIVA').toUpperCase() == 'ATIVA',
              )
              .toList()
            ..sort(
              (a, b) =>
                  (a.idordcategoria ?? 0).compareTo(b.idordcategoria ?? 0),
            );
      final produtos = resultados[1]
          .whereType<Map>()
          .map((p) => Map<String, dynamic>.from(p))
          .where(
            (p) =>
                (p['sitproduto'] ?? 'ATIVO').toString().toUpperCase() ==
                'ATIVO',
          )
          .toList();
      if (mounted) {
        setState(() {
          _categorias = categorias;
          _produtos = produtos;
          if (_categoriaId != null &&
              !categorias.any((c) => c.categoriaId == _categoriaId)) {
            _categoriaId = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<Map<String, dynamic>> get _produtosVisiveis => _categoriaId == null
      ? _produtos
      : _produtos
            .where((p) => int.tryParse('${p['categoria_id']}') == _categoriaId)
            .toList();

  String? _urlImagem(Map<String, dynamic> produto) {
    final valor = (produto['urlfotoproduto'] ?? '').toString().trim();
    if (valor.isEmpty) return null;
    return valor.startsWith('http') ? valor : ApiConfig.buildUrl(valor);
  }

  double _numero(Object? valor) =>
      double.tryParse((valor ?? '0').toString().replaceAll(',', '.')) ?? 0;

  bool _descontoAtivo(Map<String, dynamic> produto) {
    final tipo = (produto['tipodesconto'] ?? 'NENHUM').toString().toUpperCase();
    final ativo =
        produto['descontoativo'] == true ||
        produto['descontoativo']?.toString().toLowerCase() == 'true';
    return ativo && tipo != 'NENHUM' && _numero(produto['vrdesconto']) > 0;
  }

  String _seloDesconto(Map<String, dynamic> produto) {
    final tipo = (produto['tipodesconto'] ?? '').toString().toUpperCase();
    final desconto = _numero(produto['vrdesconto']);
    if (tipo == 'PERCENTUAL') {
      final casas = desconto % 1 == 0 ? 0 : 1;
      return '-${desconto.toStringAsFixed(casas)}%';
    }
    return '-${_moeda.format(desconto)}';
  }

  Future<void> _novaCategoria() async {
    final controller = TextEditingController();
    final nome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova categoria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nome da categoria',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (nome == null || nome.isEmpty) return;
    try {
      final id = await _categoriasRepo.criar(
        widget.loja.lojaId,
        nome,
        'ATIVA',
        _categorias.length + 1,
      );
      await _carregar();
      if (mounted && id != null) {
        setState(() => _categoriaId = id);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _abrirProduto([Map<String, dynamic>? produto]) async {
    if (produto == null && _categorias.isEmpty) {
      AppSnackBar.aviso(
        context,
        'Crie uma categoria antes de adicionar produtos.',
      );
      return;
    }
    final alterou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProdutoFormPage(
          lojaId: widget.loja.lojaId,
          organizacaoId: widget.loja.organizacaoId,
          produto: produto,
          categoriaIdInicial: _categoriaId,
        ),
      ),
    );
    if (alterou == true) {
      await _carregar();
    }
  }

  Future<void> _compartilhar() async {
    final link = 'https://app.clubbar.com.br/?loja_id=${widget.loja.lojaId}';
    final texto =
        'Veja o cardápio digital da ${widget.loja.nmloja} no Clubbar:\n$link';
    await Clipboard.setData(ClipboardData(text: texto));
    if (mounted) {
      AppSnackBar.sucesso(
        context,
        'Link do cardápio copiado. Cole no WhatsApp, Instagram ou onde desejar.',
      );
    }
  }

  Future<void> _abrirGerenciamento(String opcao) async {
    final Widget pagina = opcao == 'categorias'
        ? CategoriaListPage(
            organizacaoId: widget.loja.organizacaoId,
            lojaIdInicial: widget.loja.lojaId,
            fixarLoja: true,
          )
        : ProdutoListPage(
            organizacaoId: widget.loja.organizacaoId,
            lojaIdInicial: widget.loja.lojaId,
            fixarLoja: true,
          );
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pagina));
    await _carregar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: ClubbarAppBar(
      mostrarVoltar: true,
      actions: [
        IconButton(
          tooltip: 'Compartilhar',
          onPressed: _compartilhar,
          icon: const Icon(Icons.share),
        ),
        PopupMenuButton<String>(
          tooltip: 'Gerenciar cadastros',
          onSelected: _abrirGerenciamento,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'categorias',
              child: ListTile(
                leading: Icon(Icons.category_outlined),
                title: Text('Gerenciar categorias'),
              ),
            ),
            PopupMenuItem(
              value: 'produtos',
              child: ListTile(
                leading: Icon(Icons.inventory_2_outlined),
                title: Text('Gerenciar produtos'),
              ),
            ),
          ],
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _abrirProduto(),
      icon: const Icon(Icons.add),
      label: const Text('Produto'),
    ),
    body: Column(
      children: [
        ClubbarPageHeader(
          titulo: 'Cardápio Digital',
          subtitulo: '${widget.loja.nmloja} • Assim aparecerá para o cliente',
        ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Categorias',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: const Text('Todos'),
                                        selected: _categoriaId == null,
                                        onSelected: (_) =>
                                            setState(() => _categoriaId = null),
                                      ),
                                    ),
                                    ..._categorias.map(
                                      (c) => Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(c.nmcategoria),
                                          selected:
                                              _categoriaId == c.categoriaId,
                                          onSelected: (_) => setState(
                                            () => _categoriaId = c.categoriaId,
                                          ),
                                        ),
                                      ),
                                    ),
                                    ActionChip(
                                      avatar: const Icon(Icons.add, size: 18),
                                      label: const Text('Nova categoria'),
                                      onPressed: _novaCategoria,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _categoriaId == null
                                          ? 'Todos os produtos'
                                          : _categorias
                                                .firstWhere(
                                                  (c) =>
                                                      c.categoriaId ==
                                                      _categoriaId,
                                                )
                                                .nmcategoria,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_produtosVisiveis.length} itens',
                                    style: const TextStyle(
                                      color: ClubbarColors.textoSecundario,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_produtosVisiveis.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'Nenhum produto nesta categoria.\nUse o botão + Produto para cadastrar.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                          sliver: SliverGrid.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  mainAxisExtent: 300,
                                ),
                            itemCount: _produtosVisiveis.length,
                            itemBuilder: (context, index) {
                              final produto = _produtosVisiveis[index];
                              final imagem = _urlImagem(produto);
                              final descontoAtivo = _descontoAtivo(produto);
                              final precoOriginal = _numero(
                                produto['vrprecoprod'],
                              );
                              final preco =
                                  (produto['vrprecofinal'] ??
                                          produto['vrprecoprod'] ??
                                          0)
                                      as num;
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => _abrirProduto(produto),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Stack(
                                        children: [
                                          SizedBox(
                                            width: double.infinity,
                                            height: 165,
                                            child: ColoredBox(
                                              color: Colors.white,
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                child: imagem == null
                                                    ? const ColoredBox(
                                                        color: ClubbarColors
                                                            .ambarClaro,
                                                        child: Icon(
                                                          Icons.restaurant_menu,
                                                          size: 44,
                                                        ),
                                                      )
                                                    : Image.network(
                                                        imagem,
                                                        fit: BoxFit.contain,
                                                        errorBuilder:
                                                            (
                                                              _,
                                                              _,
                                                              _,
                                                            ) => const Icon(
                                                              Icons
                                                                  .restaurant_menu,
                                                              size: 44,
                                                            ),
                                                      ),
                                              ),
                                            ),
                                          ),
                                          if (descontoAtivo)
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade700,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  _seloDesconto(produto),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (produto['nmproduto'] ??
                                                      'Produto')
                                                  .toString(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              (produto['dsproduto'] ?? '')
                                                  .toString(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: ClubbarColors
                                                    .textoSecundario,
                                              ),
                                            ),
                                            const SizedBox(height: 7),
                                            Row(
                                              children: [
                                                if (descontoAtivo) ...[
                                                  Text(
                                                    _moeda.format(
                                                      precoOriginal,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: ClubbarColors
                                                          .textoSecundario,
                                                      decoration: TextDecoration
                                                          .lineThrough,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                ],
                                                Flexible(
                                                  child: Text(
                                                    _moeda.format(preco),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: descontoAtivo
                                                          ? Colors.red.shade700
                                                          : ClubbarColors
                                                                .ambarEscuro,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );
}
