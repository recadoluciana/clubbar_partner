import 'package:flutter/material.dart';

import '../../core/repositories/cardapio_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/asaas_pendente_dialog.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_calendar_delegate.dart';
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
        _lojas.map((loja) async {
          final cardapios = await _repo.listar(loja.lojaId);
          return Future.wait(
            cardapios.map((cardapio) async {
              if (cardapio['tipocardapio'] == 'PRINCIPAL') {
                return cardapio;
              }
              final programacoes = await _repo.listarProgramacoes(
                int.parse('${cardapio['cardapio_id']}'),
              );
              return {...cardapio, 'programacoes': programacoes};
            }),
          );
        }),
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
              (item['quantidade_produtos'] as num? ?? 0) > 0 &&
              !(_itensPorLoja[loja.lojaId] ?? const []).any(
                (cardapio) =>
                    '${cardapio['cardapiomodelo_id']}' ==
                    '${item['cardapiomodelo_id']}',
              ),
        )
        .toList();
    if (padroes.isEmpty) {
      if (mounted) {
        AppSnackBar.aviso(
          context,
          'Não há outro cardápio padrão ativo com produtos disponível para esta loja.',
        );
      }
      return;
    }
    final selecionado = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Adicionar cardápio à loja'),
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

  String _hora(TimeOfDay hora) =>
      '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

  DateTime _unirDataHora(DateTime data, TimeOfDay hora) =>
      DateTime(data.year, data.month, data.day, hora.hour, hora.minute);

  String _formatarDataProgramacao(dynamic valor) {
    if (valor == null || '$valor'.trim().isEmpty) return 'sem data inicial';
    final data = DateTime.tryParse('$valor');
    return data == null ? '$valor' : _data(data);
  }

  String _formatarHoraProgramacao(dynamic valor) {
    final texto = '${valor ?? ''}'.trim();
    if (texto.isEmpty || texto == 'null') return '';
    final partes = texto.split(':');
    return partes.length >= 2 ? '${partes[0]}:${partes[1]}' : texto;
  }

  String _intervaloProgramacao(Map<String, dynamic> programacao) {
    final inicio = _formatarDataProgramacao(programacao['dtinicio']);
    final horaInicio = _formatarHoraProgramacao(programacao['hrinicio']);
    final fim = _formatarDataProgramacao(programacao['dtfim']);
    final horaFim = _formatarHoraProgramacao(programacao['hrfim']);
    final inicioCompleto = horaInicio.isEmpty
        ? inicio
        : '$inicio às $horaInicio';
    if (programacao['dtfim'] == null || '${programacao['dtfim']}'.isEmpty) {
      return '$inicioCompleto até você retirar a programação';
    }
    final fimCompleto = horaFim.isEmpty ? fim : '$fim às $horaFim';
    return '$inicioCompleto até $fimCompleto';
  }

  Future<void> _programarExibicao(Map<String, dynamic> cardapio) async {
    final hoje = DateTime.now();
    final inicio = await showDatePicker(
      context: context,
      initialDate: hoje,
      firstDate: DateTime(hoje.year - 1),
      lastDate: DateTime(hoje.year + 5),
      calendarDelegate: const ClubbarCalendarDelegate(),
      helpText: 'Início da exibição da temporada',
    );
    if (inicio == null || !mounted) return;

    final horaInicio = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(hoje),
      helpText: 'Horário de início da exibição',
    );
    if (horaInicio == null || !mounted) return;

    final definirFim = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Encerramento da exibição'),
        content: const Text(
          'Deseja informar a data e a hora em que este cardápio deixará de ser exibido?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Sem data final'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Informar encerramento'),
          ),
        ],
      ),
    );
    if (definirFim == null || !mounted) return;

    DateTime? fim;
    TimeOfDay? horaFim;
    if (definirFim) {
      fim = await showDatePicker(
        context: context,
        initialDate: inicio,
        firstDate: inicio,
        lastDate: DateTime(inicio.year + 5),
        calendarDelegate: const ClubbarCalendarDelegate(),
        helpText: 'Fim da exibição',
      );
      if (fim == null || !mounted) return;
      horaFim = await showTimePicker(
        context: context,
        initialTime: horaInicio,
        helpText: 'Horário de fim da exibição',
      );
      if (horaFim == null || !mounted) return;
      if (!_unirDataHora(
        fim,
        horaFim,
      ).isAfter(_unirDataHora(inicio, horaInicio))) {
        AppSnackBar.aviso(
          context,
          'O encerramento deve ser posterior ao início da exibição.',
        );
        return;
      }
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Programar exibição'),
        content: Text(
          fim == null
              ? 'Este cardápio será exibido a partir de ${_data(inicio)} às ${_hora(horaInicio)} até você retirar a programação.'
              : 'Este cardápio será exibido de ${_data(inicio)} às ${_hora(horaInicio)} até ${_data(fim)} às ${_hora(horaFim!)}.',
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
        horaInicio: horaInicio,
        fim: fim,
        horaFim: horaFim,
      );
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, 'Exibição programada.');
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _removerProgramacao(
    Map<String, dynamic> cardapio,
    Map<String, dynamic> programacao,
  ) async {
    try {
      await _repo.removerProgramacao(
        int.parse('${cardapio['cardapio_id']}'),
        int.parse('${programacao['cardapioprogramacao_id']}'),
      );
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, 'Programação removida.');
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _gerenciar(Loja loja, Map<String, dynamic> cardapio) async {
    try {
      final versaoId = await _garantirRascunho(cardapio);
      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CardapioLojaEditorPage(
            loja: loja,
            cardapioId: int.parse('${cardapio['cardapio_id']}'),
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

  Future<void> _excluirCardapio(Map<String, dynamic> cardapio) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir cardápio da loja?'),
        content: Text(
          '“${cardapio['nmcardapio']}” será removido somente desta loja. O cardápio padrão da empresa e seus produtos serão mantidos.',
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
    if (confirmar != true || !mounted) return;
    try {
      await _repo.excluirCardapio(int.parse('${cardapio['cardapio_id']}'));
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, 'Cardápio excluído da loja.');
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
                    'Cardápios do Estabelecimento - ${loja.nmloja}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ClubbarColors.infoClaro,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 20),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'O cardápio principal fica disponível continuamente. Cardápios especiais substituem o principal somente durante os períodos programados.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _novo(loja),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar cardápio à loja'),
              ),
            ),
            const SizedBox(height: 12),
            if (cardapios.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nenhum cardápio criado para este estabelecimento.',
                ),
              ),
            for (var i = 0; i < cardapios.length; i++) ...[
              _conteudoCardapio(loja, cardapios[i]),
              if (i < cardapios.length - 1) const SizedBox(height: 12),
            ],
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
    final especial = cardapio['tipocardapio'] == 'ESPECIAL';
    final programacoes = (cardapio['programacoes'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: especial
                      ? Colors.purple.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  especial ? Icons.auto_awesome_rounded : Icons.home_rounded,
                  color: especial
                      ? Colors.purple.shade700
                      : Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cardapio['nmcardapio']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      especial
                          ? 'Exibido somente durante a programação definida'
                          : 'Cardápio permanente do estabelecimento',
                      style: const TextStyle(
                        color: ClubbarColors.textoSecundario,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: especial
                      ? Colors.purple.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: especial
                        ? Colors.purple.shade200
                        : Colors.green.shade200,
                  ),
                ),
                child: Text(
                  especial ? 'ESPECIAL' : 'PRINCIPAL',
                  style: TextStyle(
                    color: especial
                        ? Colors.purple.shade800
                        : Colors.green.shade800,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          if (especial) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    programacoes.isEmpty
                        ? 'Programação ainda não definida'
                        : 'Período de exibição do cardápio especial',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  if (programacoes.isEmpty)
                    const Text(
                      'Defina a data e a hora antes de publicar este cardápio.',
                      style: TextStyle(fontSize: 13),
                    ),
                  for (final programacao in programacoes)
                    Row(
                      children: [
                        const Icon(Icons.schedule_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _intervaloProgramacao(programacao),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remover programação',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              _removerProgramacao(cardapio, programacao),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _gerenciar(loja, cardapio),
                icon: const Icon(Icons.restaurant_menu_outlined),
                label: const Text('Editar cardápio'),
              ),
              FilledButton.icon(
                onPressed:
                    rascunho == null || (especial && programacoes.isEmpty)
                    ? null
                    : () => _publicar(cardapio),
                icon: const Icon(Icons.publish),
                label: const Text('Publicar alterações'),
              ),
              if (publicado)
                OutlinedButton.icon(
                  onPressed: () => _retirarPublicacao(cardapio),
                  icon: const Icon(Icons.visibility_off_outlined),
                  label: const Text('Retirar publicação'),
                ),
              if (especial)
                FilledButton.icon(
                  onPressed: () => _programarExibicao(cardapio),
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(
                    programacoes.isEmpty
                        ? 'Definir programação'
                        : 'Alterar programação',
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => _excluirCardapio(cardapio),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Excluir cardápio'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
