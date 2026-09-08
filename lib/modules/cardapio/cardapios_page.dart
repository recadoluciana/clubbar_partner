import 'package:flutter/material.dart';

import '../../core/repositories/cardapio_repository.dart';
import '../../core/repositories/produto_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_action_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';
import 'cardapio_digital_page.dart';

class CardapiosPage extends StatefulWidget {
  final Loja loja;
  final List<Loja> lojas;
  const CardapiosPage({super.key, required this.loja, this.lojas = const []});

  @override
  State<CardapiosPage> createState() => _CardapiosPageState();
}

class _CardapiosPageState extends State<CardapiosPage> {
  final _repo = CardapioRepository();
  final _produtosRepo = ProdutoRepository();
  late Loja _loja;
  List<Map<String, dynamic>> _itens = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loja = widget.loja;
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final itens = await _repo.listar(_loja.lojaId);
      if (mounted) setState(() => _itens = itens);
    } catch (e) {
      if (mounted)
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _trocar(int? id) async {
    if (id == null || id == _loja.lojaId) return;
    setState(() => _loja = widget.lojas.firstWhere((e) => e.lojaId == id));
    await _carregar();
  }

  Future<void> _novo() async {
    List<Map<String, dynamic>> padroes;
    try {
      padroes = await _repo.listarPadroes(_loja.organizacaoId);
    } catch (e) {
      if (mounted)
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    final nome = TextEditingController();
    String tipo = 'PRINCIPAL';
    int? padraoId;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setModal) => AlertDialog(
          title: const Text('Novo cardápio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (padroes.isNotEmpty) ...[
                DropdownButtonFormField<int?>(
                  initialValue: padraoId,
                  decoration: const InputDecoration(
                    labelText: 'Cardápio padrão da organização',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Criar um novo padrão'),
                    ),
                    ...padroes.map(
                      (e) => DropdownMenuItem<int?>(
                        value: int.parse('${e['cardapiomodelo_id']}'),
                        child: Text('${e['nmcardapio']}'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setModal(() => padraoId = v),
                ),
                const SizedBox(height: 12),
              ],
              if (padraoId == null) ...[
                TextField(
                  controller: nome,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      const {
                            'PRINCIPAL': 'Principal',
                            'ESPECIAL': 'Especial',
                            'SAZONAL': 'Sazonal',
                            'EVENTO': 'Evento',
                          }.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setModal(() => tipo = v ?? tipo),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
    if (confirmou != true || (padraoId == null && nome.text.trim().length < 2))
      return;
    try {
      final id =
          padraoId ??
          int.parse(
            '${(await _repo.criarPadrao(_loja.organizacaoId, nome.text.trim(), tipo))['cardapiomodelo_id']}',
          );
      await _repo.associar(_loja.lojaId, id);
      await _carregar();
    } catch (e) {
      if (mounted)
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Map<String, dynamic>? _rascunho(Map<String, dynamic> c) {
    for (final item in (c['versoes'] as List? ?? const [])) {
      final versao = Map<String, dynamic>.from(item as Map);
      if (versao['statusversao'] == 'RASCUNHO') return versao;
    }
    return null;
  }

  Future<int> _garantirRascunho(Map<String, dynamic> c) async {
    final atual = _rascunho(c);
    if (atual != null) return int.parse('${atual['cardapioversao_id']}');
    final nova = await _repo.novaVersao(int.parse('${c['cardapio_id']}'));
    return int.parse('${nova['cardapioversao_id']}');
  }

  Future<void> _sincronizar(Map<String, dynamic> c) async {
    try {
      final versao = await _garantirRascunho(c);
      final produtos = (await _produtosRepo.listar(_loja.lojaId))
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => (e['sitproduto'] ?? 'ATIVO').toString() == 'ATIVO')
          .toList();
      final agrupados = <int, List<Map<String, dynamic>>>{};
      for (final p in produtos) {
        final id = int.tryParse('${p['categoria_id']}');
        if (id != null) (agrupados[id] ??= []).add(p);
      }
      var ordem = 0;
      final categorias = agrupados.entries
          .map(
            (e) => {
              'categoria_id': e.key,
              'idordcategoria': ++ordem,
              'itens': e.value.indexed
                  .map(
                    (x) => {
                      'produto_id': int.parse('${x.$2['produto_id']}'),
                      'vrpreco':
                          double.tryParse(
                            '${x.$2['vrprecofinal'] ?? x.$2['vrprecoprod']}',
                          ) ??
                          0,
                      'idorditem': x.$1 + 1,
                    },
                  )
                  .toList(),
            },
          )
          .toList();
      await _repo.salvarConteudo(versao, categorias);
      await _carregar();
      if (mounted)
        AppSnackBar.sucesso(
          context,
          'Rascunho atualizado com os produtos atuais.',
        );
    } catch (e) {
      if (mounted)
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _publicar(Map<String, dynamic> c) async {
    try {
      final id = await _garantirRascunho(c);
      final msg = await _repo.publicar(id);
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, msg);
    } catch (e) {
      if (mounted)
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _reajustar(Map<String, dynamic> c) async {
    final ctrl = TextEditingController();
    final valor = await showDialog<double>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Reajustar preços'),
        content: TextField(
          controller: ctrl,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              d,
              double.tryParse(ctrl.text.replaceAll(',', '.')),
            ),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (valor == null || valor == 0) return;
    try {
      final id = await _garantirRascunho(c);
      final qtd = await _repo.reajustar(id, valor);
      if (mounted)
        AppSnackBar.sucesso(context, '$qtd preços reajustados no rascunho.');
    } catch (e) {
      if (mounted)
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      Card(
        child: ListTile(
          leading: const Icon(Icons.inventory_2_outlined, color: Colors.blue),
          title: const Text(
            'Catálogo de produtos',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text(
            'Cadastre categorias, produtos e imagens usados nas versões.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CardapioDigitalPage(loja: _loja)),
          ),
        ),
      ),
      if (_itens.isEmpty)
        const Padding(
          padding: EdgeInsets.all(36),
          child: Center(child: Text('Nenhum cardápio criado.')),
        ),
      ..._itens.map((cardapio) {
        final versoes = cardapio['versoes'] as List? ?? const [];
        final ultima = versoes.isEmpty
            ? null
            : Map<String, dynamic>.from(versoes.first as Map);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${cardapio['nmcardapio']}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    Chip(label: Text('${cardapio['tipocardapio']}')),
                  ],
                ),
                Text(
                  ultima == null
                      ? 'Sem versão'
                      : 'Versão ${ultima['nrversao']} • ${ultima['statusversao']}',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _sincronizar(cardapio),
                      icon: const Icon(Icons.sync),
                      label: const Text('Atualizar rascunho'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _reajustar(cardapio),
                      icon: const Icon(Icons.price_change_outlined),
                      label: const Text('Reajustar'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _publicar(cardapio),
                      icon: const Icon(Icons.publish),
                      label: const Text('Publicar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    ];
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      bottomNavigationBar: ClubbarActionBar(
        actions: [
          ClubbarAddButton(onPressed: _novo, label: 'Adicionar cardápio'),
        ],
      ),
      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: _loja.nmloja,
            subtitulo: 'Cardápios digitais',
            tituloStyle: const TextStyle(
              color: Colors.blue,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
            trailing: widget.lojas.length < 2
                ? null
                : PopupMenuButton<int>(
                    tooltip: 'Trocar estabelecimento',
                    icon: const Icon(
                      Icons.swap_horiz_rounded,
                      color: Colors.blue,
                    ),
                    onSelected: _trocar,
                    itemBuilder: (_) => widget.lojas
                        .map(
                          (loja) => PopupMenuItem(
                            value: loja.lojaId,
                            child: Text(loja.nmloja),
                          ),
                        )
                        .toList(),
                  ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _carregar,
                    child: ListView(
                      padding: const EdgeInsets.all(14),
                      children: cards,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
