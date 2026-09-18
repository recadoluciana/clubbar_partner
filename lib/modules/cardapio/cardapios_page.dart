import 'package:flutter/material.dart';

import '../../core/repositories/cardapio_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_action_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';

class CardapiosPage extends StatefulWidget {
  final Loja loja;
  final List<Loja> lojas;
  const CardapiosPage({super.key, required this.loja, this.lojas = const []});

  @override
  State<CardapiosPage> createState() => _CardapiosPageState();
}

class _CardapiosPageState extends State<CardapiosPage> {
  final _repo = CardapioRepository();
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
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
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
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
      return;
    }
    if (!mounted) return;
    padroes = padroes
        .where(
          (item) =>
              item['sitcardapio'] == 'ATIVO' &&
              (item['quantidade_produtos'] as num? ?? 0) > 0,
        )
        .toList();
    if (padroes.isEmpty) {
      if (mounted) {
        AppSnackBar.aviso(
          context,
          'Crie um cardápio padrão com produtos no menu da empresa antes de utilizá-lo nesta loja.',
        );
      }
      return;
    }
    final selecionado = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Escolher cardápio padrão da empresa'),
        children: padroes
            .map(
              (padrao) => SimpleDialogOption(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  int.parse('${padrao['cardapiomodelo_id']}'),
                ),
                child: Text(
                  '${padrao['nmcardapio']} • ${padrao['quantidade_produtos']} produtos',
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selecionado == null) return;
    try {
      await _repo.associar(_loja.lojaId, selecionado);
      await _carregar();
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
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

  Future<void> _publicar(Map<String, dynamic> c) async {
    try {
      final id = await _garantirRascunho(c);
      final msg = await _repo.publicar(id);
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, msg);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
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
      if (mounted) {
        AppSnackBar.sucesso(context, '$qtd preços reajustados no rascunho.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (_itens.isEmpty)
        const Padding(
          padding: EdgeInsets.all(36),
          child: Center(child: Text('Nenhum cardápio criado.')),
        ),
      ..._itens.map((cardapio) {
        final versoes = cardapio['versoes'] as List? ?? const [];
        final publicadas = versoes
            .where((v) => v['statusversao'] == 'PUBLICADA')
            .toList();
        final rascunhos = versoes
            .where((v) => v['statusversao'] == 'RASCUNHO')
            .toList();
        final programadas = versoes
            .where((v) => v['statusversao'] == 'PROGRAMADA')
            .toList();
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (publicadas.isEmpty)
                      const Chip(
                        avatar: Icon(Icons.visibility_off_outlined, size: 18),
                        label: Text('Não publicado'),
                      ),
                    for (final versao in publicadas)
                      Chip(
                        backgroundColor: Colors.green.shade50,
                        avatar: Icon(
                          Icons.check_circle,
                          color: Colors.green.shade800,
                          size: 18,
                        ),
                        label: Text(
                          'Publicado — versão ${versao['nrversao']}',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    for (final versao in rascunhos)
                      Chip(
                        backgroundColor: ClubbarColors.primariaClaro,
                        avatar: const Icon(Icons.edit_note, size: 18),
                        label: Text(
                          'Alterações em rascunho — versão ${versao['nrversao']}',
                        ),
                      ),
                    for (final versao in programadas)
                      Chip(
                        avatar: const Icon(Icons.schedule, size: 18),
                        label: Text(
                          'Publicação programada — versão ${versao['nrversao']}',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
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
          ClubbarAddButton(onPressed: _novo, label: 'Usar cardápio padrão'),
        ],
      ),
      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: _loja.nmloja,
            subtitulo: 'Cardápios digitais',
            tituloStyle: const TextStyle(
              color: ClubbarColors.primariaEscuro,
              fontSize: 17,
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
