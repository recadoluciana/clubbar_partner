import 'package:flutter/material.dart';

import '../../core/repositories/cardapio_repository.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/asaas_pendente_dialog.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';
import 'cardapio_loja_editor_page.dart';

/// Centraliza a gestão de um cardápio compartilhado e seus vínculos por loja.
class CardapioGestaoEmpresaPage extends StatefulWidget {
  final int organizacaoId;
  final String nomeOrganizacao;
  final int cardapioId;

  const CardapioGestaoEmpresaPage({
    super.key,
    required this.organizacaoId,
    required this.nomeOrganizacao,
    required this.cardapioId,
  });

  @override
  State<CardapioGestaoEmpresaPage> createState() =>
      _CardapioGestaoEmpresaPageState();
}

class _CardapioGestaoEmpresaPageState extends State<CardapioGestaoEmpresaPage> {
  final _repo = CardapioRepository();
  final _lojaRepo = LojaRepository();
  Map<String, dynamic>? _cardapio;
  List<Loja> _lojas = [];
  bool _carregando = true;

  int _id(Object? value) => int.parse('$value');

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final resultados = await Future.wait([
        _repo.listarCardapiosEmpresa(widget.organizacaoId),
        _lojaRepo.listar(widget.organizacaoId),
      ]);
      final cardapio = (resultados[0] as List<Map<String, dynamic>>)
          .where((item) => _id(item['cardapio_id']) == widget.cardapioId)
          .cast<Map<String, dynamic>>()
          .firstOrNull;
      if (!mounted) return;
      if (cardapio == null) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _cardapio = cardapio;
        _lojas = resultados[1] as List<Loja>;
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<Map<String, dynamic>> get _associacoes =>
      ((_cardapio?['lojas'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Map<String, dynamic>? _associacao(Loja loja) {
    for (final item in _associacoes) {
      if (_id(item['loja_id']) == loja.lojaId) return item;
    }
    return null;
  }

  List<Map<String, dynamic>> get _versoes =>
      ((_cardapio?['versoes'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Map<String, dynamic>? get _rascunho {
    for (final versao in _versoes) {
      if (versao['statusversao'] == 'RASCUNHO') return versao;
    }
    return null;
  }

  bool get _publicado => _versoes.any(
    (versao) =>
        versao['statusversao'] == 'PUBLICADA' ||
        versao['statusversao'] == 'PROGRAMADA',
  );

  Future<int> _garantirRascunho() async {
    final atual = _rascunho;
    if (atual != null) return _id(atual['cardapioversao_id']);
    final criado = await _repo.novaVersao(widget.cardapioId);
    return _id(criado['cardapioversao_id']);
  }

  Future<void> _editarConteudo() async {
    final associadas = _lojas
        .where((loja) => _associacao(loja) != null)
        .toList(growable: false);
    try {
      final versaoId = await _garantirRascunho();
      if (!mounted || _cardapio == null) return;
      // O conteúdo pertence ao cardápio da empresa, portanto pode ser
      // preparado antes de ele ser associado a uma loja. O editor usa a loja
      // apenas como contexto visual e para obter a organização.
      final contexto = associadas.isEmpty
          ? Loja(
              lojaId: 0,
              organizacaoId: widget.organizacaoId,
              nmloja: 'Cardápio da empresa',
            )
          : associadas.first;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CardapioLojaEditorPage(
            loja: contexto,
            cardapioId: widget.cardapioId,
            versaoId: versaoId,
            nomeCardapio: '${_cardapio!['nmcardapio']}',
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

  Future<void> _renomear() async {
    if (_cardapio == null) return;
    final controller = TextEditingController(
      text: '${_cardapio!['nmcardapio']}',
    );
    final nome = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar cardápio'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Nome do cardápio',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nome == null || nome.length < 2) return;
    try {
      await _repo.renomearCardapio(widget.cardapioId, nome);
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, 'Cardápio atualizado.');
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _associar(Loja loja) async {
    try {
      await _repo.associar(loja.lojaId, widget.cardapioId);
      await _carregar();
      if (mounted) {
        AppSnackBar.sucesso(context, 'Cardápio associado a ${loja.nmloja}.');
      }
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

  Future<void> _desassociar(Loja loja) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desassociar loja?'),
        content: Text(
          'O cardápio deixará de ficar disponível em “${loja.nmloja}”.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Desassociar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _repo.removerAssociacao(loja.lojaId, widget.cardapioId);
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, 'Loja desassociada.');
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  List<Map<String, dynamic>> _programacoes(Map<String, dynamic> associacao) =>
      ((associacao['programacoes'] as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  String _dataHora(dynamic data, dynamic hora) {
    final valor = DateTime.tryParse('$data');
    final dataTexto = valor == null
        ? '$data'
        : '${valor.day.toString().padLeft(2, '0')}/${valor.month.toString().padLeft(2, '0')}/${valor.year}';
    final partes = '$hora'.split(':');
    final horaTexto = partes.length >= 2
        ? '${partes[0]}:${partes[1]}'
        : '$hora';
    return '$dataTexto às $horaTexto';
  }

  Future<void> _programarExibicao(Loja loja) async {
    final agora = DateTime.now();
    final inicio = await showDatePicker(
      context: context,
      initialDate: agora,
      firstDate: DateTime(agora.year - 1),
      lastDate: DateTime(agora.year + 5),
      helpText: 'Início da exibição',
    );
    if (inicio == null || !mounted) return;
    final horaInicio = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(agora),
      helpText: 'Horário de início',
    );
    if (horaInicio == null || !mounted) return;
    final fim = await showDatePicker(
      context: context,
      initialDate: inicio,
      firstDate: inicio,
      lastDate: DateTime(inicio.year + 5),
      helpText: 'Fim da exibição',
    );
    if (fim == null || !mounted) return;
    final horaFim = await showTimePicker(
      context: context,
      initialTime: horaInicio,
      helpText: 'Horário de fim',
    );
    if (horaFim == null || !mounted) return;
    final inicioCompleto = DateTime(
      inicio.year,
      inicio.month,
      inicio.day,
      horaInicio.hour,
      horaInicio.minute,
    );
    final fimCompleto = DateTime(
      fim.year,
      fim.month,
      fim.day,
      horaFim.hour,
      horaFim.minute,
    );
    if (!fimCompleto.isAfter(inicioCompleto)) {
      AppSnackBar.aviso(context, 'O fim deve ser posterior ao início.');
      return;
    }
    try {
      await _repo.programarExibicao(
        widget.cardapioId,
        lojaId: loja.lojaId,
        inicio: inicio,
        horaInicio: horaInicio,
        fim: fim,
        horaFim: horaFim,
      );
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, 'Período de exibição salvo.');
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _removerProgramacao(Loja loja, int programacaoId) async {
    try {
      await _repo.removerProgramacao(
        widget.cardapioId,
        programacaoId,
        lojaId: loja.lojaId,
      );
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, 'Período removido.');
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _publicar() async {
    try {
      final versaoId = await _garantirRascunho();
      final mensagem = await _repo.publicar(versaoId);
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, mensagem);
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

  Future<void> _retirarPublicacao() async {
    try {
      final mensagem = await _repo.retirarPublicacao(widget.cardapioId);
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, mensagem);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _excluir() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir cardápio?'),
        content: const Text(
          'Esta ação excluirá o cardápio, seus produtos configurados e todas as associações com lojas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Excluir cardápio'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _repo.excluirCardapio(widget.cardapioId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardapio = _cardapio;
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: _carregando || cardapio == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                ClubbarPageHeader(
                  titulo: widget.nomeOrganizacao,
                  subtitulo: 'Gerencie conteúdo, publicação e lojas',
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _carregar,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _resumo(cardapio),
                        const SizedBox(height: 20),
                        const Text(
                          'Lojas associadas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Escolha em quais lojas este cardápio ficará disponível.',
                          style: TextStyle(
                            color: ClubbarColors.textoSecundario,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final loja in _lojas) ...[
                          _cardLoja(loja),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 26),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _resumo(Map<String, dynamic> cardapio) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                color: ClubbarColors.primaria,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cardapio['nmcardapio']}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _badgeTipo('${cardapio['tipocardapio']}'),
                        Text(
                          '${cardapio['quantidade_produtos'] ?? 0} produtos • ${_associacoes.length} lojas',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar nome do cardápio',
                onPressed: _renomear,
                color: Colors.blue.shade700,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Excluir cardápio',
                onPressed: _excluir,
                color: Colors.red.shade700,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Chip(
            avatar: Icon(
              _publicado ? Icons.check_circle : Icons.visibility_off_outlined,
              size: 18,
              color: _publicado ? Colors.green.shade700 : null,
            ),
            label: Text(_publicado ? 'Publicado' : 'Não publicado'),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _editarConteudo,
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('Montar cardápio'),
              ),
              FilledButton.icon(
                onPressed: _rascunho == null ? null : _publicar,
                icon: const Icon(Icons.publish_outlined),
                label: const Text('Publicar cardápio'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
              if (_publicado)
                OutlinedButton.icon(
                  onPressed: _retirarPublicacao,
                  icon: const Icon(Icons.visibility_off_outlined),
                  label: const Text('Retirar publicação'),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _badgeTipo(String tipo) {
    final principal = tipo == 'PRINCIPAL';
    final cor = principal ? ClubbarColors.info : Colors.amber.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        principal ? 'Principal' : 'Especial',
        style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _cardLoja(Loja loja) {
    final associacao = _associacao(loja);
    final associada = associacao != null;
    final especial = _cardapio?['tipocardapio'] == 'ESPECIAL';
    final programacoes = associacao == null
        ? const <Map<String, dynamic>>[]
        : _programacoes(associacao);
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              associada ? Icons.storefront_rounded : Icons.storefront_outlined,
              color: associada
                  ? ClubbarColors.primaria
                  : ClubbarColors.textoSecundario,
            ),
            title: Text(loja.nmloja),
            subtitle: associada
                ? const Text('Associado')
                : const Text('Não associado'),
            trailing: Switch(
              value: associada,
              onChanged: (value) =>
                  value ? _associar(loja) : _desassociar(loja),
            ),
            onTap: associada ? null : () => _associar(loja),
          ),
          if (especial && associada)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const Text(
                    'Período de exibição',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (programacoes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Nenhum período definido.',
                        style: TextStyle(color: ClubbarColors.textoSecundario),
                      ),
                    ),
                  for (final programacao in programacoes)
                    Row(
                      children: [
                        const Icon(Icons.schedule_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_dataHora(programacao['dtinicio'], programacao['hrinicio'])} até ${_dataHora(programacao['dtfim'], programacao['hrfim'])}',
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remover período',
                          onPressed: () => _removerProgramacao(
                            loja,
                            _id(programacao['cardapioprogramacao_id']),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () => _programarExibicao(loja),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar período'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
