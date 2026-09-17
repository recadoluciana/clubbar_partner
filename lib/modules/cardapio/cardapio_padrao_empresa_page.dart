import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/cardapio_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../categorias/categorias_produtos_page.dart';
import 'produto_padrao_form_page.dart';

class CardapioPadraoEmpresaPage extends StatefulWidget {
  final int organizacaoId;
  final String nomeOrganizacao;

  const CardapioPadraoEmpresaPage({
    super.key,
    required this.organizacaoId,
    required this.nomeOrganizacao,
  });

  @override
  State<CardapioPadraoEmpresaPage> createState() =>
      _CardapioPadraoEmpresaPageState();
}

class _CardapioPadraoEmpresaPageState extends State<CardapioPadraoEmpresaPage> {
  final _repo = CardapioRepository();
  List<Map<String, dynamic>> _padroes = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final itens = await _repo.listarPadroes(widget.organizacaoId);
      if (mounted) setState(() => _padroes = itens);
    } catch (e) {
      if (mounted)
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _novo() async {
    final nome = TextEditingController();
    var tipo = 'PRINCIPAL';
    final resultado = await showDialog<(String, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, atualizar) => AlertDialog(
          title: const Text('Cardápio padrão da empresa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nome,
                autofocus: true,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Nome do cardápio',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(
                    value: 'PRINCIPAL',
                    child: Text('Principal'),
                  ),
                  DropdownMenuItem(value: 'ESPECIAL', child: Text('Especial')),
                  DropdownMenuItem(value: 'SAZONAL', child: Text('Sazonal')),
                  DropdownMenuItem(value: 'EVENTO', child: Text('Evento')),
                ],
                onChanged: (valor) => atualizar(() => tipo = valor ?? tipo),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (nome.text.trim().length >= 2)
                  Navigator.pop(context, (nome.text.trim(), tipo));
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
    nome.dispose();
    if (resultado == null || !mounted) return;
    try {
      await _repo.criarPadrao(widget.organizacaoId, resultado.$1, resultado.$2);
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, 'Cardápio padrão criado.');
    } catch (e) {
      if (mounted)
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: Column(
      children: [
        ClubbarPageHeader(
          titulo: widget.nomeOrganizacao,
          subtitulo: 'Cardápio padrão empresa',
          tituloStyle: const TextStyle(
            color: ClubbarColors.info,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Cadastre os produtos aqui, sem escolher estabelecimento. Ao usar um padrão em uma loja, o conteúdo é copiado para o cardápio dela; alterações posteriores no padrão não modificam lojas já configuradas.',
                          ),
                        ),
                      ),
                      if (_padroes.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'A empresa ainda não possui cardápio padrão. Crie o primeiro para disponibilizá-lo aos estabelecimentos.',
                            ),
                          ),
                        ),
                      for (final padrao in _padroes)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.menu_book_rounded),
                            title: Text('${padrao['nmcardapio']}'),
                            subtitle: Text(
                              '${padrao['tipocardapio']} • ${padrao['quantidade_produtos']} produtos',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _ItensPadraoPage(
                                    organizacaoId: widget.organizacaoId,
                                    modeloId: int.parse(
                                      '${padrao['cardapiomodelo_id']}',
                                    ),
                                    nome: '${padrao['nmcardapio']}',
                                  ),
                                ),
                              );
                              if (mounted) await _carregar();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _novo,
      icon: const Icon(Icons.add),
      label: const Text('Adicionar cardápio'),
    ),
  );
}

class _ItensPadraoPage extends StatefulWidget {
  final int organizacaoId;
  final int modeloId;
  final String nome;

  const _ItensPadraoPage({
    required this.organizacaoId,
    required this.modeloId,
    required this.nome,
  });

  @override
  State<_ItensPadraoPage> createState() => _ItensPadraoPageState();
}

class _ItensPadraoPageState extends State<_ItensPadraoPage> {
  static const _iconesCategoria = <String, IconData>{
    'water_drop': Icons.water_drop_rounded,
    'local_drink': Icons.local_drink_rounded,
    'local_cafe': Icons.local_cafe_rounded,
    'sports_bar': Icons.sports_bar_rounded,
    'local_bar': Icons.local_bar_rounded,
    'liquor': Icons.liquor_rounded,
    'wine_bar': Icons.wine_bar_rounded,
    'coffee': Icons.coffee_rounded,
    'soup_kitchen': Icons.soup_kitchen_rounded,
    'tapas': Icons.tapas_rounded,
    'restaurant': Icons.restaurant_rounded,
    'lunch_dining': Icons.lunch_dining_rounded,
    'outdoor_grill': Icons.outdoor_grill_rounded,
    'fastfood': Icons.fastfood_rounded,
    'local_pizza': Icons.local_pizza_rounded,
    'dinner_dining': Icons.dinner_dining_rounded,
    'eco': Icons.eco_rounded,
    'cake': Icons.cake_rounded,
    'icecream': Icons.icecream_rounded,
    'inventory_2': Icons.inventory_2_rounded,
    'celebration': Icons.celebration_rounded,
  };
  final _repo = CardapioRepository();
  List<Map<String, dynamic>> _itens = [];
  List<Map<String, dynamic>> _categorias = [];
  int? _categoriaSelecionada;
  String _busca = '';
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
        _repo.listarItensPadrao(widget.organizacaoId, widget.modeloId),
        _repo.listarCategoriasOrganizacao(widget.organizacaoId),
      ]);
      if (!mounted) return;
      setState(() {
        _itens = resultados[0];
        _categorias = resultados[1];
        if (_categoriaSelecionada != null &&
            !_categorias.any(
              (categoria) => categoria['categoria_id'] == _categoriaSelecionada,
            )) {
          _categoriaSelecionada = null;
        }
      });
    } catch (e) {
      if (mounted)
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrirFormulario([Map<String, dynamic>? item]) async {
    final alterou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProdutoPadraoFormPage(
          organizacaoId: widget.organizacaoId,
          modeloId: widget.modeloId,
          item: item,
        ),
      ),
    );
    if (alterou == true && mounted) await _carregar();
  }

  Future<void> _gerenciarCategorias() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CategoriasProdutosPage(organizacaoId: widget.organizacaoId),
      ),
    );
    if (mounted) await _carregar();
  }

  String _moeda(Object? valor) {
    final numero = double.tryParse('$valor') ?? 0;
    return 'R\$ ${numero.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  double _precoFinal(Map<String, dynamic> item) {
    final preco = double.tryParse('${item['vrprecoprod']}') ?? 0;
    final desconto = double.tryParse('${item['vrdesconto']}') ?? 0;
    final agora = DateTime.now();
    final inicio = DateTime.tryParse('${item['dtinidesconto'] ?? ''}');
    final fim = DateTime.tryParse('${item['dtfimdesconto'] ?? ''}');
    if (desconto <= 0 ||
        (inicio != null && agora.isBefore(inicio)) ||
        (fim != null && agora.isAfter(fim))) {
      return preco;
    }
    return switch (item['tipodesconto']) {
      'PERCENTUAL' => preco * (1 - desconto / 100),
      'VALOR' => preco - desconto,
      _ => preco,
    };
  }

  Widget _chipCategoria(int? id, String nome, IconData icone) {
    final selecionada = _categoriaSelecionada == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => setState(() => _categoriaSelecionada = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 82,
          height: 64,
          decoration: BoxDecoration(
            color: selecionada ? Colors.amber : Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selecionada ? Colors.amber : Colors.grey.shade300,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 20),
              const SizedBox(height: 3),
              Text(
                nome,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardProduto(Map<String, dynamic> item) {
    final foto = '${item['urlfotoproduto'] ?? ''}'.trim();
    final preco = double.tryParse('${item['vrprecoprod']}') ?? 0;
    final precoFinal = _precoFinal(item);
    final temDesconto = precoFinal < preco;
    final inativo = item['sitproduto'] == 'INATIVO';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrirFormulario(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 112,
                  child: foto.isEmpty
                      ? ColoredBox(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.fastfood_outlined, size: 36),
                        )
                      : Image.network(
                          foto.startsWith('http')
                              ? foto
                              : ApiConfig.buildUrl(foto),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFEEEEEE),
                            child: Icon(Icons.image_not_supported_outlined),
                          ),
                        ),
                ),
                if (temDesconto)
                  Positioned(
                    left: 7,
                    top: 7,
                    child: Chip(
                      label: Text(
                        item['tipodesconto'] == 'PERCENTUAL'
                            ? '${item['vrdesconto']}% OFF'
                            : '${_moeda(item['vrdesconto'])} OFF',
                      ),
                      backgroundColor: Colors.red.shade100,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (inativo)
                  Positioned(
                    right: 7,
                    top: 7,
                    child: Chip(
                      label: const Text('Inativo'),
                      backgroundColor: Colors.grey.shade200,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['nmproduto']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (temDesconto)
                      Text(
                        _moeda(preco),
                        style: const TextStyle(
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                          fontSize: 11,
                        ),
                      ),
                    Text(
                      _moeda(precoFinal),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: temDesconto
                            ? Colors.green.shade700
                            : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item['dsproduto'] ?? ''}'.trim().isEmpty
                          ? 'Sem descrição'
                          : '${item['dsproduto']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _abrirFormulario(item),
                            child: const Text('Editar'),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _remover(item),
                          tooltip: 'Remover produto',
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
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

  Future<void> _remover(Map<String, dynamic> item) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover do cardápio padrão?'),
        content: Text(
          'O produto ${item['nmproduto']} será removido do padrão. Cardápios já associados às lojas não serão alterados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await _repo.removerItemPadrao(
        widget.organizacaoId,
        widget.modeloId,
        int.parse('${item['cardapiomodeloitem_id']}'),
      );
      await _carregar();
    } catch (e) {
      if (mounted)
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busca = _busca.trim().toLowerCase();
    final filtrados = _itens.where((item) {
      final categoriaId = (item['categoria_id'] as num?)?.toInt();
      if (_categoriaSelecionada != null &&
          categoriaId != _categoriaSelecionada) {
        return false;
      }
      return busca.isEmpty ||
          '${item['nmproduto']} ${item['dsproduto'] ?? ''} ${item['nmcategoria']}'
              .toLowerCase()
              .contains(busca);
    }).toList();
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: widget.nome,
            subtitulo: 'Cardápio padrão da empresa',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar produto',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (valor) => setState(() => _busca = valor),
            ),
          ),
          if (!_carregando)
            SizedBox(
              height: 70,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _chipCategoria(null, 'Todos', Icons.restaurant_menu_rounded),
                  for (final categoria in _categorias)
                    _chipCategoria(
                      (categoria['categoria_id'] as num).toInt(),
                      '${categoria['nmcategoria']}',
                      _iconesCategoria['${categoria['dsicone']}'] ??
                          Icons.category_outlined,
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${filtrados.length} ${filtrados.length == 1 ? 'produto' : 'produtos'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: _gerenciarCategorias,
                  icon: const Icon(Icons.category_outlined),
                  label: const Text('Categorias'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _carregar,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final largura = constraints.maxWidth;
                        final colunas = largura < 600
                            ? 2
                            : largura < 900
                            ? 3
                            : largura < 1200
                            ? 4
                            : 5;
                        return GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: filtrados.isEmpty ? 1 : filtrados.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: colunas,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                mainAxisExtent: 315,
                              ),
                          itemBuilder: (context, index) => filtrados.isEmpty
                              ? Card(
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        _itens.isEmpty
                                            ? 'Nenhum produto cadastrado. Adicione o primeiro produto ao cardápio.'
                                            : 'Nenhum produto nesta categoria.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                )
                              : _cardProduto(filtrados[index]),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar produto'),
      ),
    );
  }
}
