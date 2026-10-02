import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/cardapio_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/asaas_pendente_dialog.dart';
import '../../core/widgets/clubbar_action_bar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';

class CardapioLojaEditorPage extends StatefulWidget {
  final Loja loja;
  final int cardapioId;
  final int versaoId;
  final String nomeCardapio;

  const CardapioLojaEditorPage({
    super.key,
    required this.loja,
    required this.cardapioId,
    required this.versaoId,
    required this.nomeCardapio,
  });

  @override
  State<CardapioLojaEditorPage> createState() => _CardapioLojaEditorPageState();
}

class _CardapioLojaEditorPageState extends State<CardapioLojaEditorPage> {
  final _repo = CardapioRepository();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _categoriasOrganizacao = [];
  List<Map<String, dynamic>> _produtosOrganizacao = [];
  bool _carregando = true;
  bool _salvando = false;
  bool _alterado = false;
  int? _numeroVersao;
  int? _categoriaSelecionadaId;
  late int _versaoEdicaoId;
  bool _versaoEhRascunho = false;

  int _id(Object? valor) => int.parse('$valor');
  double _valor(Object? valor) => double.tryParse('$valor') ?? 0;

  double _precoPromocional(Map<String, dynamic> item) {
    final preco = _valor(item['vrpreco']);
    final desconto = _valor(item['vrdesconto']);
    switch ('${item['tipodesconto'] ?? 'NENHUM'}'.toUpperCase()) {
      case 'PERCENTUAL':
        return (preco * (1 - desconto / 100)).clamp(0, preco);
      case 'VALOR':
        return (preco - desconto).clamp(0, preco);
      default:
        return preco;
    }
  }

  bool _temDesconto(Map<String, dynamic> item) =>
      '${item['tipodesconto'] ?? 'NENHUM'}'.toUpperCase() != 'NENHUM' &&
      _valor(item['vrdesconto']) > 0;

  String _seloDesconto(Map<String, dynamic> item) {
    final desconto = _valor(item['vrdesconto']);
    return '${item['tipodesconto']}'.toString().toUpperCase() == 'PERCENTUAL'
        ? '${desconto.toStringAsFixed(0)}% OFF'
        : '${_moeda.format(desconto)} OFF';
  }

  @override
  void initState() {
    super.initState();
    _versaoEdicaoId = widget.versaoId;
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final resultados = await Future.wait([
        _repo.consultarVersao(_versaoEdicaoId),
        _repo.listarCategoriasOrganizacao(widget.loja.organizacaoId),
        _repo.listarProdutosPadraoOrganizacao(widget.loja.organizacaoId),
      ]);
      final conteudo = Map<String, dynamic>.from(resultados[0] as Map);
      final categorias = (conteudo['categorias'] as List? ?? const []).map((
        categoria,
      ) {
        final mapa = Map<String, dynamic>.from(categoria as Map);
        mapa['itens'] = (mapa['itens'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        return mapa;
      }).toList();
      if (!mounted) return;
      setState(() {
        _numeroVersao = (conteudo['nrversao'] as num?)?.toInt();
        _versaoEhRascunho = conteudo['statusversao'] == 'RASCUNHO';
        _categorias = categorias;
        _categoriasOrganizacao = List<Map<String, dynamic>>.from(
          resultados[1] as List,
        );
        _produtosOrganizacao = List<Map<String, dynamic>>.from(
          resultados[2] as List,
        );
        final categoriaSelecionadaExiste =
            _categoriaSelecionadaId != null &&
            categorias.any(
              (categoria) =>
                  _id(categoria['categoria_id']) == _categoriaSelecionadaId,
            );
        if (!categoriaSelecionadaExiste) {
          _categoriaSelecionadaId = categorias.isEmpty
              ? null
              : _id(categorias.first['categoria_id']);
        }
        _alterado = false;
      });
    } catch (e) {
      if (mounted) {
        final texto = e.toString();
        if (erroIndicaPendenteAsaas(e)) {
          await mostrarDialogoAsaasPendente(context, recurso: 'este cardápio');
        } else {
          AppSnackBar.erro(
            context,
            texto.replaceFirst('Exception: ', ''),
            duration: const Duration(seconds: 10),
            mostrarFechar: true,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<Map<String, dynamic>> _itens(Map<String, dynamic> categoria) =>
      List<Map<String, dynamic>>.from(categoria['itens'] as List? ?? const []);

  List<MapEntry<int, Map<String, dynamic>>> get _categoriasExibidas =>
      _categorias
          .asMap()
          .entries
          .where(
            (entrada) =>
                _categoriaSelecionadaId == null ||
                _id(entrada.value['categoria_id']) == _categoriaSelecionadaId,
          )
          .toList();

  void _marcarAlterado() => setState(() => _alterado = true);

  Future<void> _adicionarCategoria() async {
    final usadas = _categorias.map((e) => _id(e['categoria_id'])).toSet();
    final disponiveis = _categoriasOrganizacao
        .where((e) => !usadas.contains(_id(e['categoria_id'])))
        .toList();
    if (disponiveis.isEmpty) {
      AppSnackBar.aviso(
        context,
        'Todas as categorias ativas da empresa já estão neste cardápio.',
      );
      return;
    }
    final selecionada = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Adicionar categoria'),
        children: [
          for (final categoria in disponiveis)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, categoria),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('${categoria['nmcategoria']}'),
              ),
            ),
        ],
      ),
    );
    if (selecionada == null || !mounted) return;
    setState(() {
      _categorias.add({
        'categoria_id': selecionada['categoria_id'],
        'nmcategoria': selecionada['nmcategoria'],
        'dsicone': selecionada['dsicone'],
        'itens': <Map<String, dynamic>>[],
      });
      _categoriaSelecionadaId = _id(selecionada['categoria_id']);
      _alterado = true;
    });
  }

  Future<Map<String, dynamic>?> _escolherProduto(
    Map<String, dynamic> categoria,
  ) async {
    final idsUsados = _itens(
      categoria,
    ).map((item) => _id(item['produto_id'])).toSet();
    final disponiveis = _produtosOrganizacao
        .where(
          (produto) =>
              '${produto['sitproduto']}' == 'ATIVO' &&
              !idsUsados.contains(_id(produto['produto_id'])),
        )
        .toList();
    if (disponiveis.isEmpty) {
      AppSnackBar.aviso(
        context,
        'Não há outros produtos ativos disponíveis para esta categoria.',
      );
      return null;
    }
    var filtro = '';
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, atualizar) {
          final filtrados = disponiveis
              .where(
                (produto) => '${produto['nmproduto']}'.toLowerCase().contains(
                  filtro.toLowerCase(),
                ),
              )
              .toList();
          return AlertDialog(
            title: const Text('Adicionar produto'),
            content: SizedBox(
              width: 440,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Buscar produto',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (valor) => atualizar(() => filtro = valor),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtrados.length,
                      itemBuilder: (_, indice) {
                        final produto = filtrados[indice];
                        return ListTile(
                          title: Text('${produto['nmproduto']}'),
                          subtitle: Text(
                            _moeda.format(_valor(produto['vrprecoprod'])),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(dialogContext, produto),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _adicionarProduto(Map<String, dynamic> categoria) async {
    final produto = await _escolherProduto(categoria);
    if (produto == null || !mounted) return;
    setState(() {
      final itens = _itens(categoria);
      itens.add({
        ...produto,
        'vrpreco': _valor(produto['vrprecoprod']),
        'tipodesconto': produto['tipodesconto'] ?? 'NENHUM',
        'vrdesconto': _valor(produto['vrdesconto']),
        'dtinidesconto': produto['dtinidesconto'],
        'dtfimdesconto': produto['dtfimdesconto'],
        'sititem': 'ATIVO',
      });
      categoria['itens'] = itens;
      _alterado = true;
    });
  }

  Future<void> _editarPreco(Map<String, dynamic> item) async {
    final controller = TextEditingController(
      text: _valor(item['vrpreco']).toStringAsFixed(2).replaceAll('.', ','),
    );
    final valor = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${item['nmproduto']}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Preço neste estabelecimento',
            prefixText: 'R\$ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final numero = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              if (numero != null && numero >= 0) {
                Navigator.pop(dialogContext, numero);
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (valor == null || !mounted) return;
    setState(() {
      item['vrpreco'] = valor;
      _alterado = true;
    });
  }

  Future<void> _editarDesconto(Map<String, dynamic> item) async {
    var tipo = '${item['tipodesconto'] ?? 'NENHUM'}'.toUpperCase();
    final valorController = TextEditingController(
      text: _valor(item['vrdesconto']).toStringAsFixed(2).replaceAll('.', ','),
    );
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, atualizar) {
          final porPercentual = tipo == 'PERCENTUAL';
          final semDesconto = tipo == 'NENHUM';
          return AlertDialog(
            title: Text('Desconto • ${item['nmproduto']}'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: tipo,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de desconto',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'NENHUM',
                        child: Text('Sem desconto'),
                      ),
                      DropdownMenuItem(
                        value: 'PERCENTUAL',
                        child: Text('Percentual (%)'),
                      ),
                      DropdownMenuItem(
                        value: 'VALOR',
                        child: Text('Valor fixo (R\$)'),
                      ),
                    ],
                    onChanged: (valor) =>
                        atualizar(() => tipo = valor ?? 'NENHUM'),
                  ),
                  if (!semDesconto) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: valorController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: porPercentual
                            ? 'Percentual de desconto'
                            : 'Valor do desconto',
                        prefixText: porPercentual ? null : 'R\$ ',
                        suffixText: porPercentual ? '%' : null,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Preço atual: ${_moeda.format(_valor(item['vrpreco']))}',
                      style: const TextStyle(
                        color: ClubbarColors.textoSecundario,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final desconto = semDesconto
                      ? 0.0
                      : double.tryParse(
                          valorController.text.replaceAll(',', '.'),
                        );
                  if (desconto == null ||
                      desconto < 0 ||
                      (porPercentual && desconto > 100) ||
                      (!porPercentual && desconto > _valor(item['vrpreco']))) {
                    AppSnackBar.aviso(
                      context,
                      porPercentual
                          ? 'Informe um percentual entre 0 e 100.'
                          : 'O desconto não pode ser maior que o preço.',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, {
                    'tipodesconto': tipo,
                    'vrdesconto': desconto,
                  });
                },
                child: const Text('Aplicar desconto'),
              ),
            ],
          );
        },
      ),
    );
    valorController.dispose();
    if (resultado == null || !mounted) return;
    setState(() {
      item['tipodesconto'] = resultado['tipodesconto'];
      item['vrdesconto'] = resultado['vrdesconto'];
      if (resultado['tipodesconto'] == 'NENHUM') {
        item['dtinidesconto'] = null;
        item['dtfimdesconto'] = null;
      }
      _alterado = true;
    });
  }

  Future<void> _removerCategoria(int indice) async {
    final categoria = _categorias[indice];
    final categoriaId = _id(categoria['categoria_id']);
    final quantidade = _itens(categoria).length;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Retirar ${categoria['nmcategoria']}?'),
        content: Text(
          quantidade == 0
              ? 'A categoria será retirada somente deste cardápio.'
              : 'A categoria e seus $quantidade produtos serão retirados somente deste cardápio. Os cadastros da empresa permanecerão intactos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ClubbarColors.erro),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() {
      _categorias.removeAt(indice);
      if (_categoriaSelecionadaId == categoriaId) {
        _categoriaSelecionadaId = _categorias.isEmpty
            ? null
            : _id(_categorias.first['categoria_id']);
      }
      _alterado = true;
    });
  }

  void _moverCategoria(int indice, int deslocamento) {
    final destino = indice + deslocamento;
    if (destino < 0 || destino >= _categorias.length) return;
    setState(() {
      final item = _categorias.removeAt(indice);
      _categorias.insert(destino, item);
      _alterado = true;
    });
  }

  Widget _filtroCategorias() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        for (final categoria in _categorias) ...[
          ChoiceChip(
            label: Text('${categoria['nmcategoria']}'),
            selected: _categoriaSelecionadaId == _id(categoria['categoria_id']),
            onSelected: (_) => setState(
              () => _categoriaSelecionadaId = _id(categoria['categoria_id']),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ],
    ),
  );

  void _moverProduto(
    Map<String, dynamic> categoria,
    int indice,
    int deslocamento,
  ) {
    final itens = _itens(categoria);
    final destino = indice + deslocamento;
    if (destino < 0 || destino >= itens.length) return;
    setState(() {
      final item = itens.removeAt(indice);
      itens.insert(destino, item);
      categoria['itens'] = itens;
      _alterado = true;
    });
  }

  Future<void> _reajustarPrecos() async {
    final categoriaSelecionada = _categorias
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (categoria) =>
              _id(categoria?['categoria_id']) == _categoriaSelecionadaId,
          orElse: () => null,
        );
    if (categoriaSelecionada == null) {
      AppSnackBar.aviso(context, 'Selecione uma categoria para reajustar.');
      return;
    }
    final nomeCategoria = '${categoriaSelecionada['nmcategoria']}';
    final controlador = TextEditingController();
    final percentual = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reajustar preços'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Categoria que será reajustada: $nomeCategoria'),
            const SizedBox(height: 16),
            TextField(
              controller: controlador,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Percentual (use - para reduzir)',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controlador.text.replaceAll(',', '.')),
            ),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    controlador.dispose();
    if (percentual == null || percentual == 0 || !mounted) return;

    var quantidade = 0;
    setState(() {
      final itens = _itens(categoriaSelecionada);
      for (final item in itens) {
        final reajustado = (_valor(item['vrpreco']) * (1 + percentual / 100))
            .clamp(0, double.infinity);
        item['vrpreco'] = double.parse(reajustado.toStringAsFixed(2));
        quantidade++;
      }
      categoriaSelecionada['itens'] = itens;
      _alterado = true;
    });
    AppSnackBar.sucesso(
      context,
      '$quantidade ${quantidade == 1 ? 'preço reajustado' : 'preços reajustados'} na categoria $nomeCategoria. Salve ou publique quando estiver pronto.',
    );
  }

  List<Map<String, dynamic>> _payload() => [
    for (
      var categoriaIndice = 0;
      categoriaIndice < _categorias.length;
      categoriaIndice++
    )
      {
        'categoria_id': _id(_categorias[categoriaIndice]['categoria_id']),
        'idordcategoria': categoriaIndice + 1,
        'itens': [
          for (
            var itemIndice = 0;
            itemIndice < _itens(_categorias[categoriaIndice]).length;
            itemIndice++
          )
            {
              'produto_id': _id(
                _itens(_categorias[categoriaIndice])[itemIndice]['produto_id'],
              ),
              'vrpreco': _valor(
                _itens(_categorias[categoriaIndice])[itemIndice]['vrpreco'],
              ),
              'tipodesconto':
                  '${_itens(_categorias[categoriaIndice])[itemIndice]['tipodesconto'] ?? 'NENHUM'}',
              'vrdesconto': _valor(
                _itens(_categorias[categoriaIndice])[itemIndice]['vrdesconto'],
              ),
              'dtinidesconto': _itens(
                _categorias[categoriaIndice],
              )[itemIndice]['dtinidesconto'],
              'dtfimdesconto': _itens(
                _categorias[categoriaIndice],
              )[itemIndice]['dtfimdesconto'],
              'sititem':
                  '${_itens(_categorias[categoriaIndice])[itemIndice]['sititem'] ?? 'ATIVO'}',
              'idorditem': itemIndice + 1,
            },
        ],
      },
  ];

  Future<bool> _garantirRascunho() async {
    if (_versaoEhRascunho) return true;
    try {
      final nova = await _repo.novaVersao(widget.cardapioId);
      if (!mounted) return false;
      setState(() {
        _versaoEdicaoId = int.parse('${nova['cardapioversao_id']}');
        _numeroVersao = (nova['nrversao'] as num?)?.toInt();
        _versaoEhRascunho = true;
      });
      return true;
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
      return false;
    }
  }

  Future<bool> _salvar({bool avisar = true}) async {
    if (_salvando) return false;
    if (!_alterado && !_versaoEhRascunho) return true;
    setState(() => _salvando = true);
    try {
      if (!await _garantirRascunho()) return false;
      await _repo.salvarConteudo(_versaoEdicaoId, _payload());
      if (!mounted) return true;
      setState(() => _alterado = false);
      if (avisar) {
        AppSnackBar.sucesso(
          context,
          'Rascunho salvo. O cardápio publicado não foi alterado.',
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        final texto = e.toString();
        if (erroIndicaPendenteAsaas(e)) {
          await mostrarDialogoAsaasPendente(context, recurso: 'este cardápio');
        } else {
          AppSnackBar.erro(
            context,
            texto.replaceFirst('Exception: ', ''),
            duration: const Duration(seconds: 10),
            mostrarFechar: true,
          );
        }
      }
      return false;
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _publicar() async {
    if (!_alterado && !_versaoEhRascunho) {
      AppSnackBar.aviso(context, 'Faça uma alteração antes de publicar.');
      return;
    }
    final ativos = _categorias.fold<int>(
      0,
      (total, categoria) =>
          total +
          _itens(
            categoria,
          ).where((item) => '${item['sititem']}' == 'ATIVO').length,
    );
    if (ativos == 0) {
      AppSnackBar.aviso(
        context,
        'Mantenha pelo menos um produto disponível antes de publicar.',
      );
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Publicar alterações?'),
        content: Text(
          'A versão atual de ${widget.nomeCardapio} será substituída por este rascunho somente no estabelecimento ${widget.loja.nmloja}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    if (!await _salvar(avisar: false)) return;
    setState(() => _salvando = true);
    try {
      final mensagem = await _repo.publicar(_versaoEdicaoId);
      if (!mounted) return;
      AppSnackBar.sucesso(context, mensagem);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        if (erroIndicaPendenteAsaas(e)) {
          await mostrarDialogoAsaasPendente(context, recurso: 'este cardápio');
        } else {
          AppSnackBar.erro(
            context,
            e.toString().replaceFirst('Exception: ', ''),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _produtoCard(
    Map<String, dynamic> categoria,
    Map<String, dynamic> item,
    int indice,
  ) {
    final ativo = '${item['sititem'] ?? 'ATIVO'}' == 'ATIVO';
    final itens = _itens(categoria);
    final temDesconto = _temDesconto(item);
    final foto = '${item['urlfotoproduto'] ?? ''}'.trim();
    final urlFoto = foto.isEmpty ? '' : ApiConfig.buildUrl(foto);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 132,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 124,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    urlFoto.isEmpty
                        ? Container(
                            color: ClubbarColors.fundo,
                            child: const Icon(
                              Icons.fastfood_outlined,
                              size: 38,
                            ),
                          )
                        : Image.network(
                            urlFoto,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: ClubbarColors.fundo,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                              ),
                            ),
                          ),
                    if (temDesconto)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ClubbarColors.erro,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _seloDesconto(item),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item['nmproduto']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Editar produto',
                            onSelected: (acao) {
                              if (acao == 'preco') {
                                _editarPreco(item);
                              }
                              if (acao == 'desconto') {
                                _editarDesconto(item);
                              }
                              if (acao == 'subir') {
                                _moverProduto(categoria, indice, -1);
                              }
                              if (acao == 'descer') {
                                _moverProduto(categoria, indice, 1);
                              }
                              if (acao == 'remover') {
                                setState(() {
                                  itens.removeAt(indice);
                                  categoria['itens'] = itens;
                                  _alterado = true;
                                });
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'preco',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.price_change,
                                    color: Colors.blue,
                                  ),
                                  title: Text('Alterar preço'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'desconto',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.sell_outlined,
                                    color: ClubbarColors.erro,
                                  ),
                                  title: Text('Desconto'),
                                ),
                              ),
                              if (indice > 0)
                                const PopupMenuItem(
                                  value: 'subir',
                                  child: ListTile(
                                    leading: Icon(Icons.arrow_upward),
                                    title: Text('Mover para cima'),
                                  ),
                                ),
                              if (indice < itens.length - 1)
                                const PopupMenuItem(
                                  value: 'descer',
                                  child: ListTile(
                                    leading: Icon(Icons.arrow_downward),
                                    title: Text('Mover para baixo'),
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'remover',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  title: Text('Retirar do cardápio'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if ('${item['dsproduto'] ?? ''}'.trim().isNotEmpty)
                        Text(
                          '${item['dsproduto']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ClubbarColors.textoSecundario,
                            fontSize: 12,
                          ),
                        ),
                      const Spacer(),
                      if (temDesconto)
                        Text(
                          _moeda.format(_valor(item['vrpreco'])),
                          style: const TextStyle(
                            color: ClubbarColors.textoSecundario,
                            decoration: TextDecoration.lineThrough,
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        _moeda.format(_precoPromocional(item)),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: temDesconto
                              ? ClubbarColors.erro
                              : ClubbarColors.textoPrincipal,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            ativo
                                ? Icons.check_circle_outline
                                : Icons.remove_circle_outline,
                            size: 16,
                            color: ativo
                                ? ClubbarColors.sucesso
                                : ClubbarColors.erro,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            ativo ? 'Disponível' : 'Indisponível',
                            style: TextStyle(
                              color: ativo
                                  ? ClubbarColors.sucesso
                                  : ClubbarColors.erro,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Switch.adaptive(
                            value: ativo,
                            onChanged: (valor) {
                              item['sititem'] = valor ? 'ATIVO' : 'INATIVO';
                              _marcarAlterado();
                            },
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
      ),
    );
  }

  Widget _categoriaCard(Map<String, dynamic> categoria, int indice) {
    final itens = _itens(categoria);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const CircleAvatar(
          backgroundColor: ClubbarColors.primariaClaro,
          child: Icon(Icons.category_outlined, color: ClubbarColors.primaria),
        ),
        title: Text('${categoria['nmcategoria']}'),
        subtitle: Text(
          '${itens.length} ${itens.length == 1 ? 'produto' : 'produtos'}',
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Ações da categoria',
          onSelected: (acao) {
            if (acao == 'adicionar') _adicionarProduto(categoria);
            if (acao == 'subir') _moverCategoria(indice, -1);
            if (acao == 'descer') _moverCategoria(indice, 1);
            if (acao == 'remover') _removerCategoria(indice);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'adicionar',
              child: ListTile(
                leading: Icon(Icons.add, color: ClubbarColors.primaria),
                title: Text('Adicionar produto'),
              ),
            ),
            if (indice > 0)
              const PopupMenuItem(
                value: 'subir',
                child: ListTile(
                  leading: Icon(Icons.arrow_back),
                  title: Text('Mover para a esquerda'),
                ),
              ),
            if (indice < _categorias.length - 1)
              const PopupMenuItem(
                value: 'descer',
                child: ListTile(
                  leading: Icon(Icons.arrow_forward),
                  title: Text('Mover para a direita'),
                ),
              ),
            const PopupMenuItem(
              value: 'remover',
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Retirar categoria'),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                if (itens.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text('Nenhum produto nesta categoria.'),
                  ),
                for (var i = 0; i < itens.length; i++)
                  _produtoCard(categoria, itens[i], i),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _adicionarProduto(categoria),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar produto'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    bottomNavigationBar: ClubbarActionBar(
      actions: [
        ClubbarAddButton(
          label: _salvando ? 'Salvando...' : 'Salvar rascunho',
          icon: Icons.save_outlined,
          primary: false,
          onPressed: _salvando || !_alterado ? null : () => _salvar(),
        ),
        ClubbarAddButton(
          label: 'Publicar alterações',
          icon: Icons.publish,
          onPressed: _salvando || (!_alterado && !_versaoEhRascunho)
              ? null
              : _publicar,
        ),
      ],
    ),
    body: Column(
      children: [
        ClubbarPageHeader(
          titulo: widget.loja.nmloja,
          subtitulo:
              '${widget.nomeCardapio} • versão ${_numeroVersao ?? '—'}${_versaoEhRascunho ? ' em rascunho' : ''}',
        ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      const Card(
                        color: ClubbarColors.infoClaro,
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: ClubbarColors.info,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Você pode consultar e ajustar este cardápio para este estabelecimento. O cardápio publicado só muda quando as alterações forem publicadas.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_categorias.isNotEmpty) ...[
                        _filtroCategorias(),
                        const SizedBox(height: 8),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _reajustarPrecos,
                          icon: const Icon(Icons.price_change_outlined),
                          label: const Text('Reajustar preços'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_categorias.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Este cardápio ainda não possui categorias.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      for (final entrada in _categoriasExibidas)
                        _categoriaCard(entrada.value, entrada.key),
                      OutlinedButton.icon(
                        onPressed: _adicionarCategoria,
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar categoria'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );
}
