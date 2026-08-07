import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/repositories/atracao_repository.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/atracao.dart';
import '../../models/loja.dart';
import '../atracoes/atracao_list_page.dart';

class AgendaMensalPage extends StatefulWidget {
  final int organizacaoId;
  const AgendaMensalPage({super.key, required this.organizacaoId});
  @override
  State<AgendaMensalPage> createState() => _AgendaMensalPageState();
}

class _AgendaMensalPageState extends State<AgendaMensalPage> {
  final _repo = AtracaoRepository(), _lojasRepo = LojaRepository();
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  List<Loja> _lojas = [];
  List<AgendaEvento> _eventos = [];
  int? _lojaId;
  bool _loading = true;
  String? _erro;
  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      final ls = await _lojasRepo.listar(widget.organizacaoId);
      if (!mounted) return;
      setState(() {
        _lojas = ls;
        _lojaId = ls.isEmpty ? null : ls.first.lojaId;
      });
      await _carregar();
    } catch (e) {
      if (mounted)
        setState(() {
          _erro = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _carregar() async {
    if (_lojaId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      final es = await _repo.agenda(_lojaId!, _mes);
      if (mounted)
        setState(() {
          _eventos = es;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _erro = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
    }
  }

  void _mudarMes(int delta) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + delta));
    _carregar();
  }

  List<AgendaEvento> _doDia(DateTime d) => _eventos.where((e) {
    bool mesmoDia(DateTime valor) =>
        valor.year == d.year && valor.month == d.month && valor.day == d.day;
    return mesmoDia(e.inicio) ||
        e.atracoes.any((item) => mesmoDia(item.inicio));
  }).toList();
  DateTime _horarioNoDia(AgendaEvento evento, DateTime dia) {
    final horarios =
        evento.atracoes
            .where(
              (item) =>
                  item.inicio.year == dia.year &&
                  item.inicio.month == dia.month &&
                  item.inicio.day == dia.day,
            )
            .map((item) => item.inicio)
            .toList()
          ..sort();
    return horarios.isEmpty ? evento.inicio : horarios.first;
  }

  Future<DateTime?> _dataHora(DateTime inicial) async {
    final d = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2200),
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(inicial),
    );
    return t == null
        ? null
        : DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _editarProgramacao(
    AgendaEvento evento, [
    EventoAtracao? atual,
  ]) async {
    final atracoes = await _repo.listar();
    if (!mounted) return;
    if (atracoes.isEmpty) {
      AppSnackBar.aviso(context, 'Cadastre uma atração primeiro.');
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AtracaoListPage()),
      );
      return;
    }
    int selecionada = atual?.atracao.atracaoId ?? atracoes.first.atracaoId;
    DateTime inicio = atual?.inicio ?? evento.inicio;
    DateTime fim = atual?.fim ?? inicio.add(const Duration(hours: 2));
    bool salvando = false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: Text(atual == null ? 'Adicionar atração' : 'Editar horário'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selecionada,
                  decoration: const InputDecoration(
                    labelText: 'Atração',
                    border: OutlineInputBorder(),
                  ),
                  items: atracoes
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.atracaoId,
                          child: Text(a.nome),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => selecionada = v!),
                ),
                const SizedBox(height: 12),
                ListTile(
                  tileColor: ClubbarColors.fundo,
                  leading: const Icon(Icons.play_arrow),
                  title: const Text('Início'),
                  subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(inicio)),
                  onTap: () async {
                    final x = await _dataHora(inicio);
                    if (x != null) setLocal(() => inicio = x);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  tileColor: ClubbarColors.fundo,
                  leading: const Icon(Icons.stop),
                  title: const Text('Fim'),
                  subtitle: Text(
                    '${DateFormat('dd/MM/yyyy HH:mm').format(fim)}${fim.day != inicio.day ? ' • dia seguinte' : ''}',
                  ),
                  onTap: () async {
                    final x = await _dataHora(fim);
                    if (x != null) setLocal(() => fim = x);
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'O fim pode ser no dia seguinte, por exemplo 23:00 até 06:00.',
                  style: TextStyle(color: ClubbarColors.textoSecundario),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: salvando ? null : () => Navigator.pop(c, false),
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
                      setLocal(() => salvando = true);
                      try {
                        if (atual == null) {
                          await _repo.adicionar(
                            eventoId: evento.eventoId,
                            atracaoId: selecionada,
                            inicio: inicio,
                            fim: fim,
                          );
                        } else {
                          await _repo.atualizarProgramacao(
                            id: atual.programacaoId,
                            atracaoId: selecionada,
                            inicio: inicio,
                            fim: fim,
                          );
                        }
                        if (c.mounted) Navigator.pop(c, true);
                      } catch (e) {
                        setLocal(() => salvando = false);
                        if (mounted)
                          AppSnackBar.erro(
                            context,
                            e.toString().replaceFirst('Exception: ', ''),
                          );
                      }
                    },
              child: Text(salvando ? 'Salvando...' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, 'Programação atualizada.');
    }
  }

  Future<void> _remover(EventoAtracao p) async {
    try {
      await _repo.removerProgramacao(p.programacaoId);
      if (mounted) {
        Navigator.pop(context);
        await _carregar();
        AppSnackBar.sucesso(context, 'Atração removida da agenda.');
      }
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, e.toString());
    }
  }

  void _abrirEvento(AgendaEvento e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheet) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.titulo,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(DateFormat('dd/MM/yyyy HH:mm').format(e.inicio)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheet),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                if (e.atracoes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Nenhuma atração programada.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ...e.atracoes.map(
                  (p) => ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.music_note)),
                    title: Text(
                      p.atracao.nome,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${DateFormat('dd/MM HH:mm').format(p.inicio)} → ${DateFormat('dd/MM HH:mm').format(p.fim)}',
                    ),
                    onTap: () {
                      Navigator.pop(sheet);
                      _editarProgramacao(e, p);
                    },
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: ClubbarColors.erro,
                      ),
                      onPressed: () => _remover(p),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheet);
                    _editarProgramacao(e);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar atração'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: SafeArea(
      child: Column(
        children: [
          ClubbarPageHeader(
            titulo: 'Agenda Mensal',
            subtitulo: 'Monte a programação de atrações dos seus eventos',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _lojaId,
                    decoration: const InputDecoration(
                      labelText: 'Loja',
                      border: OutlineInputBorder(),
                    ),
                    items: _lojas
                        .map(
                          (l) => DropdownMenuItem(
                            value: l.lojaId,
                            child: Text(l.nmloja),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() => _lojaId = v);
                      _carregar();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AtracaoListPage(),
                      ),
                    );
                    _carregar();
                  },
                  icon: const Icon(Icons.mic),
                  label: const Text('Atrações'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _mudarMes(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                SizedBox(
                  width: 180,
                  child: Text(
                    '${const ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'][_mes.month - 1]} ${_mes.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _mudarMes(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _erro != null
                ? Center(child: Text(_erro!))
                : LayoutBuilder(builder: (c, b) => _calendario(b.maxWidth)),
          ),
        ],
      ),
    ),
  );
  Widget _calendario(double largura) {
    final primeiro = DateTime(_mes.year, _mes.month, 1),
        dias = DateTime(_mes.year, _mes.month + 1, 0).day,
        vazios = primeiro.weekday % 7,
        total = ((vazios + dias + 6) ~/ 7) * 7;
    final nomes = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    return Column(
      children: [
        Row(
          children: nomes
              .map(
                (d) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: largura < 700 ? 0.62 : 1.05,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: total,
            itemBuilder: (c, i) {
              final n = i - vazios + 1;
              if (n < 1 || n > dias) return const SizedBox();
              final data = DateTime(_mes.year, _mes.month, n),
                  eventos = _doDia(data);
              return Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: ClubbarColors.branco,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ClubbarColors.borda),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$n',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    ...eventos
                        .take(largura < 700 ? 2 : 4)
                        .map(
                          (e) => Expanded(
                            child: InkWell(
                              onTap: () => _abrirEvento(e),
                              child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 3),
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: ClubbarColors.ambarClaro,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '${DateFormat('HH:mm').format(_horarioNoDia(e, data))} ${e.titulo}\n${e.atracoes.length} atração(ões)',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
