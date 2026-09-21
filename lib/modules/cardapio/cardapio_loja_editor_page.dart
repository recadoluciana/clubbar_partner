import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/cardapio_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_action_bar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';

class CardapioLojaEditorPage extends StatefulWidget {
  final Loja loja;
  final int versaoId;
  final String nomeCardapio;

  const CardapioLojaEditorPage({
    super.key,
    required this.loja,
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

  int _id(Object? valor) => int.parse('$valor');
  double _valor(Object? valor) => double.tryParse('$valor') ?? 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final resultados = await Future.wait([
        _repo.consultarVersao(widget.versaoId),
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
        _categorias = categorias;
        _categoriasOrganizacao = List<Map<String, dynamic>>.from(
          resultados[1] as List,
        );
        _produtosOrganizacao = List<Map<String, dynamic>>.from(
          resultados[2] as List,
        );
        _alterado = false;
      });
    } catch (e) {
      if (mounted) {
        final texto = e.toString();
        AppSnackBar.erro(
          context,
          texto.contains('temporariamente indisponível')
              ? 'Seu cardápio não pode ser publicado. Sua conta no Asaas ainda não foi aprovada.\n\nAcesse o menu Titular financeiro e efetive a integração com o Asaas.'
              : texto.replaceFirst('Exception: ', ''),
          duration: const Duration(seconds: 10),
          mostrarFechar: true,
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<Map<String, dynamic>> _itens(Map<String, dynamic> categoria) =>
      List<Map<String, dynamic>>.from(categoria['itens'] as List? ?? const []);

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

  Future<void> _removerCategoria(int indice) async {
    final categoria = _categorias[indice];
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
              'sititem':
                  '${_itens(_categorias[categoriaIndice])[itemIndice]['sititem'] ?? 'ATIVO'}',
              'idorditem': itemIndice + 1,
            },
        ],
      },
  ];

  Future<bool> _salvar({bool avisar = true}) async {
    if (_salvando) return false;
    setState(() => _salvando = true);
    try {
      await _repo.salvarConteudo(widget.versaoId, _payload());
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
        AppSnackBar.erro(
          context,
          texto.contains('temporariamente indisponível')
              ? 'Seu cardápio não pode ser publicado. Sua conta no Asaas ainda não foi aprovada.\n\nAcesse o menu Titular financeiro e efetive a integração com o Asaas.'
              : texto.replaceFirst('Exception: ', ''),
          duration: const Duration(seconds: 10),
          mostrarFechar: true,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _publicar() async {
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
      final mensagem = await _repo.publicar(widget.versaoId);
      if (!mounted) return;
      AppSnackBar.sucesso(context, mensagem);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['nmproduto']}',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_moeda.format(_valor(item['vrpreco']))} neste estabelecimento',
                    style: const TextStyle(color: ClubbarColors.primariaEscuro),
                  ),
                  Text(
                    ativo ? 'Disponível' : 'Indisponível',
                    style: TextStyle(
                      color: ativo ? ClubbarColors.sucesso : ClubbarColors.erro,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: ativo,
              onChanged: (valor) {
                item['sititem'] = valor ? 'ATIVO' : 'INATIVO';
                _marcarAlterado();
              },
            ),
            PopupMenuButton<String>(
              tooltip: 'Ações do produto',
              onSelected: (acao) {
                if (acao == 'preco') _editarPreco(item);
                if (acao == 'subir') _moverProduto(categoria, indice, -1);
                if (acao == 'descer') _moverProduto(categoria, indice, 1);
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
                    leading: Icon(Icons.price_change, color: Colors.blue),
                    title: Text('Alterar preço'),
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
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Retirar do cardápio'),
                  ),
                ),
              ],
            ),
          ],
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
                  leading: Icon(Icons.arrow_upward),
                  title: Text('Mover para cima'),
                ),
              ),
            if (indice < _categorias.length - 1)
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
          onPressed: _salvando ? null : _publicar,
        ),
      ],
    ),
    body: Column(
      children: [
        ClubbarPageHeader(
          titulo: widget.loja.nmloja,
          subtitulo:
              '${widget.nomeCardapio} • versão ${_numeroVersao ?? '—'} em rascunho',
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
                                  'Estas alterações valem somente para este estabelecimento. O cardápio publicado continua funcionando até você publicar este rascunho.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_categorias.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Este rascunho ainda não possui categorias.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      for (var i = 0; i < _categorias.length; i++)
                        _categoriaCard(_categorias[i], i),
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
