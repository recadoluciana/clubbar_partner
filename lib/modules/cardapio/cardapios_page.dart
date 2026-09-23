import 'package:flutter/material.dart';

import '../../core/repositories/cardapio_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/asaas_pendente_dialog.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../core/services/storage_service.dart';
import '../../models/loja.dart';
import 'cardapio_loja_editor_page.dart';

class CardapiosPage extends StatefulWidget {
  final Loja loja;
  final List<Loja> lojas;
  const CardapiosPage({super.key, required this.loja, this.lojas = const []});

  @override
  State<CardapiosPage> createState() => _CardapiosPageState();
}

class _CardapiosPageState extends State<CardapiosPage> {
  final _repo = CardapioRepository();
  late List<Loja> _lojas;
  final Map<int, List<Map<String, dynamic>>> _itensPorLoja = {};
  String _nomeOrganizacao = 'Organização';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _lojas = widget.lojas.isEmpty ? [widget.loja] : widget.lojas;
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final resultados = await Future.wait(
        _lojas.map((loja) => _repo.listar(loja.lojaId)),
      );
      final nomeOrganizacao = await StorageService.getNomeOrganizacao();
      if (mounted) {
        setState(() {
          _nomeOrganizacao = nomeOrganizacao?.trim().isNotEmpty == true
              ? nomeOrganizacao!.trim()
              : 'Organização';
          for (var i = 0; i < _lojas.length; i++) {
            _itensPorLoja[_lojas[i].lojaId] = resultados[i];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _novo(Loja loja) async {
    List<Map<String, dynamic>> padroes;
    try {
      padroes = await _repo.listarPadroes(loja.organizacaoId);
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
      await _repo.associar(loja.lojaId, selecionado);
      await _carregar();
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
        if (erroIndicaPendenteAsaas(e)) {
          await mostrarDialogoAsaasPendente(context, recurso: 'este cardápio');
        } else {
          AppSnackBar.erro(
            context,
            e.toString().replaceFirst('Exception: ', ''),
          );
        }
      }
    }
  }

  Future<void> _retirarPublicacao(Map<String, dynamic> cardapio) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar publicação?'),
        content: Text(
          '“${cardapio['nmcardapio']}” deixará de ficar disponível para os clientes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirar publicação'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      final mensagem = await _repo.retirarPublicacao(
        int.parse('${cardapio['cardapio_id']}'),
      );
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, mensagem);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  String _data(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

  Future<void> _programarExibicao(Map<String, dynamic> cardapio) async {
    final hoje = DateTime.now();
    final inicio = await showDatePicker(
      context: context,
      initialDate: hoje,
      firstDate: DateTime(hoje.year - 1),
      lastDate: DateTime(hoje.year + 5),
      helpText: 'Início da exibição da temporada',
    );
    if (inicio == null || !mounted) return;
    final fim = await showDatePicker(
      context: context,
      initialDate: inicio,
      firstDate: inicio,
      lastDate: DateTime(inicio.year + 5),
      helpText: 'Fim da exibição (opcional)',
    );
    if (!mounted) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Programar exibição'),
        content: Text(
          fim == null
              ? 'Este cardápio ficará disponível a partir de ${_data(inicio)} até você retirar a programação.'
              : 'Este cardápio ficará disponível de ${_data(inicio)} até ${_data(fim)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Programar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _repo.programarExibicao(
        int.parse('${cardapio['cardapio_id']}'),
        inicio: inicio,
        fim: fim,
      );
      if (mounted) AppSnackBar.sucesso(context, 'Exibição programada.');
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _verProgramacoes(Map<String, dynamic> cardapio) async {
    final cardapioId = int.parse('${cardapio['cardapio_id']}');
    try {
      final itens = await _repo.listarProgramacoes(cardapioId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Programações de exibição'),
          content: SizedBox(
            width: 420,
            child: itens.isEmpty
                ? const Text('Não há programação ativa para este cardápio.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: itens.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (_, index) {
                      final item = itens[index];
                      final inicio = '${item['dtinicio'] ?? 'agora'}';
                      final fim = '${item['dtfim'] ?? 'sem data final'}';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('$inicio até $fim'),
                        trailing: IconButton(
                          tooltip: 'Remover programação',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            try {
                              await _repo.removerProgramacao(
                                cardapioId,
                                int.parse('${item['cardapioprogramacao_id']}'),
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              await _carregar();
                              if (mounted) {
                                AppSnackBar.sucesso(
                                  context,
                                  'Programação removida.',
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                AppSnackBar.erro(
                                  context,
                                  e.toString().replaceFirst('Exception: ', ''),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _editar(Loja loja, Map<String, dynamic> cardapio) async {
    try {
      final versaoId = await _garantirRascunho(cardapio);
      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CardapioLojaEditorPage(
            loja: loja,
            versaoId: versaoId,
            nomeCardapio: '${cardapio['nmcardapio']}',
          ),
        ),
      );
      await _carregar();
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
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: _nomeOrganizacao,
            subtitulo: 'Cardápios digitais dos estabelecimentos',
            tituloStyle: const TextStyle(
              color: ClubbarColors.primariaEscuro,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _carregar,
                    child: ListView(
                      padding: const EdgeInsets.all(14),
                      children: [for (final loja in _lojas) _cardLoja(loja)],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _cardLoja(Loja loja) {
    final cardapios = _itensPorLoja[loja.lojaId] ?? const [];

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.restaurant_menu_rounded,
                  color: ClubbarColors.primariaEscuro,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cardápio padrão - ${loja.nmloja}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            if (cardapios.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nenhum cardápio criado para este estabelecimento.',
                ),
              ),
            for (var i = 0; i < cardapios.length; i++) ...[
              _conteudoCardapio(loja, cardapios[i]),
              if (i < cardapios.length - 1) const Divider(height: 24),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _novo(loja),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Usar cardápio padrão'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conteudoCardapio(Loja loja, Map<String, dynamic> cardapio) {
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
    final publicado = publicadas.isNotEmpty || programadas.isNotEmpty;
    final rascunho = _rascunho(cardapio);
    final sazonal = cardapio['tipocardapio'] != 'PRINCIPAL';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${cardapio['nmcardapio']}',
                style: const TextStyle(fontWeight: FontWeight.w800),
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
            FilledButton.icon(
              onPressed: () => _editar(loja, cardapio),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar cardápio'),
            ),
            OutlinedButton.icon(
              onPressed: () => _reajustar(cardapio),
              icon: const Icon(Icons.price_change_outlined),
              label: const Text('Reajustar'),
            ),
            if (rascunho != null)
              FilledButton.icon(
                onPressed: () => _publicar(cardapio),
                icon: const Icon(Icons.publish),
                label: const Text('Publicar alterações'),
              ),
            if (publicado)
              OutlinedButton.icon(
                onPressed: () => _retirarPublicacao(cardapio),
                icon: const Icon(Icons.visibility_off_outlined),
                label: const Text('Retirar publicação'),
              ),
            if (sazonal && publicado)
              FilledButton.icon(
                onPressed: () => _programarExibicao(cardapio),
                icon: const Icon(Icons.schedule_outlined),
                label: const Text('Programar exibição'),
              ),
            if (sazonal)
              OutlinedButton.icon(
                onPressed: () => _verProgramacoes(cardapio),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Ver programações'),
              ),
          ],
        ),
      ],
    );
  }
}
