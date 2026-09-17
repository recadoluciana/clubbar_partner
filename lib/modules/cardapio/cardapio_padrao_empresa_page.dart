import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/cardapio_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
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
  final _repo = CardapioRepository();
  List<Map<String, dynamic>> _itens = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final itens = await _repo.listarItensPadrao(
        widget.organizacaoId,
        widget.modeloId,
      );
      if (mounted) setState(() => _itens = itens);
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: Column(
      children: [
        ClubbarPageHeader(
          titulo: widget.nome,
          subtitulo: 'Cardápio padrão da empresa',
        ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_itens.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Adicione produtos para poder utilizar este cardápio nos estabelecimentos.',
                            ),
                          ),
                        ),
                      for (final item in _itens)
                        Card(
                          child: ListTile(
                            leading: SizedBox.square(
                              dimension: 44,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child:
                                    (item['urlfotoproduto'] ?? '')
                                        .toString()
                                        .trim()
                                        .isEmpty
                                    ? const Icon(Icons.inventory_2_outlined)
                                    : Image.network(
                                        (item['urlfotoproduto'] as String)
                                                .startsWith('http')
                                            ? item['urlfotoproduto'] as String
                                            : ApiConfig.buildUrl(
                                                item['urlfotoproduto']
                                                    as String,
                                              ),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      ),
                              ),
                            ),
                            title: Text('${item['nmproduto']}'),
                            subtitle: Text(
                              '${item['nmcategoria']}${item['skuproduto'] == null ? '' : ' • SKU ${item['skuproduto']}'} • ${item['sitproduto']}',
                            ),
                            onTap: () => _abrirFormulario(item),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'R\$ ${double.parse('${item['vrpreco']}').toStringAsFixed(2).replaceAll('.', ',')}',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Editar produto',
                                  onPressed: () => _abrirFormulario(item),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  tooltip: 'Remover',
                                  onPressed: () => _remover(item),
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
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _abrirFormulario(),
      icon: const Icon(Icons.add),
      label: const Text('Adicionar produto'),
    ),
  );
}
