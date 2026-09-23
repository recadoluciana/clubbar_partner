import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/atracao_repository.dart';
import '../../core/repositories/evento_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/atracao.dart';
import '../eventos/evento_lote_list_page.dart';

class EventoAgendadoDetalhePage extends StatefulWidget {
  final AgendaEvento evento;
  final int organizacaoId;
  final int lojaId;
  final bool somenteConsulta;

  const EventoAgendadoDetalhePage({
    super.key,
    required this.evento,
    required this.organizacaoId,
    required this.lojaId,
    required this.somenteConsulta,
  });

  @override
  State<EventoAgendadoDetalhePage> createState() =>
      _EventoAgendadoDetalhePageState();
}

class _EventoAgendadoDetalhePageState extends State<EventoAgendadoDetalhePage> {
  final _atracaoRepository = AtracaoRepository();
  final _eventoRepository = EventoRepository();
  late AgendaEvento _evento;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _evento = widget.evento;
  }

  Future<void> _recarregar() async {
    setState(() => _carregando = true);
    try {
      final agenda = await _atracaoRepository.agenda(
        widget.lojaId,
        _evento.inicio,
      );
      final atualizado = agenda.where(
        (item) => item.eventoId == _evento.eventoId,
      );
      if (atualizado.isEmpty) {
        if (mounted) Navigator.pop(context, true);
        return;
      }
      if (mounted) setState(() => _evento = atualizado.first);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<DateTime?> _selecionarDataHora(DateTime inicial) async {
    final data = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2200),
    );
    if (data == null || !mounted) return null;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(inicial),
    );
    if (hora == null) return null;
    return DateTime(data.year, data.month, data.day, hora.hour, hora.minute);
  }

  Future<void> _editarProgramacao([EventoAtracao? atual]) async {
    final atracoes = await _atracaoRepository.listar();
    if (!mounted) return;
    if (atracoes.isEmpty) {
      AppSnackBar.aviso(
        context,
        'Cadastre uma atração antes de incluí-la no evento.',
      );
      return;
    }

    var atracaoId = atual?.atracao.atracaoId ?? atracoes.first.atracaoId;
    var inicio = atual?.inicio ?? _evento.inicio;
    var fim = atual?.fim ?? inicio.add(const Duration(hours: 2));
    var salvando = false;
    final salvo = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, atualizar) => AlertDialog(
          title: Text(atual == null ? 'Adicionar atração' : 'Editar atração'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: atracaoId,
                  decoration: const InputDecoration(
                    labelText: 'Atração',
                    border: OutlineInputBorder(),
                  ),
                  items: atracoes
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.atracaoId,
                          child: Text(item.nome),
                        ),
                      )
                      .toList(),
                  onChanged: (valor) => atualizar(() => atracaoId = valor!),
                ),
                const SizedBox(height: 12),
                ListTile(
                  tileColor: ClubbarColors.fundo,
                  leading: const Icon(Icons.play_arrow_rounded),
                  title: const Text('Início'),
                  subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(inicio)),
                  onTap: () async {
                    final valor = await _selecionarDataHora(inicio);
                    if (valor != null) atualizar(() => inicio = valor);
                  },
                ),
                ListTile(
                  tileColor: ClubbarColors.fundo,
                  leading: const Icon(Icons.stop_rounded),
                  title: const Text('Fim'),
                  subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(fim)),
                  onTap: () async {
                    final valor = await _selecionarDataHora(fim);
                    if (valor != null) atualizar(() => fim = valor);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: salvando ? null : () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: salvando
                  ? null
                  : () async {
                      if (!fim.isAfter(inicio)) {
                        AppSnackBar.aviso(
                          context,
                          'O fim deve ser posterior ao início.',
                        );
                        return;
                      }
                      atualizar(() => salvando = true);
                      try {
                        if (atual == null) {
                          await _atracaoRepository.adicionar(
                            eventoId: _evento.eventoId,
                            atracaoId: atracaoId,
                            inicio: inicio,
                            fim: fim,
                          );
                        } else {
                          await _atracaoRepository.atualizarProgramacao(
                            id: atual.programacaoId,
                            atracaoId: atracaoId,
                            inicio: inicio,
                            fim: fim,
                          );
                        }
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        atualizar(() => salvando = false);
                        if (mounted) {
                          AppSnackBar.erro(
                            this.context,
                            e.toString().replaceFirst('Exception: ', ''),
                          );
                        }
                      }
                    },
              child: Text(salvando ? 'Salvando...' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
    if (salvo == true) await _recarregar();
  }

  Future<void> _removerAtracao(EventoAtracao atracao) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover atração?'),
        content: Text(
          'Deseja remover a atração “${atracao.atracao.nome}” deste evento? A data continuará na agenda.',
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
    if (confirmado != true || !mounted) return;
    try {
      await _atracaoRepository.removerProgramacao(atracao.programacaoId);
      await _recarregar();
      if (mounted) AppSnackBar.sucesso(context, 'Atração removida da agenda.');
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _excluirData() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir esta data?'),
        content: Text(
          'O evento “${_evento.titulo}” será removido somente de ${DateFormat('dd/MM/yyyy').format(_evento.inicio)}. O evento padrão e as demais datas não serão alterados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ClubbarColors.erro),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir esta data'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      await _eventoRepository.excluirOcorrencia(_evento.eventoId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: SafeArea(
      child: Column(
        children: [
          ClubbarPageHeader(
            titulo: _evento.titulo,
            subtitulo:
                'Evento agendado • ${DateFormat('dd/MM/yyyy às HH:mm').format(_evento.inicio)}',
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _recarregar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.somenteConsulta)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Evento encerrado • disponível somente para consulta.',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Text(
                    'Atrações',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_evento.atracoes.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Nenhuma atração programada.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ..._evento.atracoes.asMap().entries.map(
                    (entrada) => _atracaoCard(entrada.value, entrada.key),
                  ),
                  if (!widget.somenteConsulta) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _carregando
                          ? null
                          : () => _editarProgramacao(),
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar atração'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _carregando
                          ? null
                          : () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EventoLoteListPage(
                                    eventoId: _evento.eventoId,
                                    eventoTitulo: _evento.titulo,
                                    organizacaoId: widget.organizacaoId,
                                    lojaId: widget.lojaId,
                                    eventoInicio: _evento.inicio
                                        .toIso8601String(),
                                  ),
                                ),
                              );
                              if (mounted) await _recarregar();
                            },
                      icon: const Icon(Icons.confirmation_number_rounded),
                      label: const Text('Gerenciar ingressos e preços'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ClubbarColors.erro,
                      ),
                      onPressed: _carregando ? null : _excluirData,
                      child: const Text('Excluir esta data'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  String _duracaoPrevista(EventoAtracao item) {
    final duracao = item.fim.difference(item.inicio);
    if (duracao.inMinutes <= 0) return 'Duração prevista não informada';

    final horas = duracao.inHours;
    final minutos = duracao.inMinutes.remainder(60);
    final texto = horas == 0
        ? '$minutos min'
        : minutos == 0
        ? '${horas}h'
        : '${horas}h ${minutos}min';
    return 'Duração prevista: $texto';
  }

  Color _corAtracao(int indice) {
    final cores = <Color>[
      ClubbarColors.primaria,
      Colors.blue.shade700,
      Colors.deepPurple.shade600,
      Colors.deepOrange.shade700,
      Colors.teal.shade700,
    ];
    return cores[indice % cores.length];
  }

  Widget _atracaoCard(EventoAtracao item, int indice) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: _corAtracao(indice),
        foregroundColor: Colors.white,
        child: Text(
          '${indice + 1}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      title: Text(
        item.atracao.nome,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(_duracaoPrevista(item)),
      onTap: widget.somenteConsulta ? null : () => _editarProgramacao(item),
      trailing: widget.somenteConsulta
          ? const Icon(Icons.lock_outline, size: 20)
          : IconButton(
              tooltip: 'Remover atração',
              icon: const Icon(Icons.delete_outline, color: ClubbarColors.erro),
              onPressed: () => _removerAtracao(item),
            ),
    ),
  );
}
