import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/repositories/atracao_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/atracao.dart';
import '../../models/loja.dart';
import '../atracoes/atracao_list_page.dart';
import '../eventos/evento_list_page.dart';

class AgendaMensalPage extends StatefulWidget {
  final Loja loja;
  const AgendaMensalPage({super.key, required this.loja});
  @override
  State<AgendaMensalPage> createState() => _AgendaMensalPageState();
}

class _AgendaMensalPageState extends State<AgendaMensalPage> {
  static const _clubbarAppUrl = 'https://app.clubbar.com.br';
  final _repo = AtracaoRepository();
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  List<AgendaEvento> _eventos = [];
  bool _loading = true;
  String? _erro;
  String _nomeOrganizacao = 'Organização';

  @override
  void initState() {
    super.initState();
    _carregar();
    _carregarNomeOrganizacao();
  }

  Future<void> _carregarNomeOrganizacao() async {
    final nome = (await StorageService.getNomeOrganizacao() ?? '').trim();
    if (!mounted) return;
    setState(() {
      _nomeOrganizacao = nome.isEmpty ? 'Organização' : nome;
    });
  }

  Future<void> _carregar() async {
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      final es = await _repo.agenda(widget.loja.lojaId, _mes);
      if (mounted) {
        setState(() {
          _eventos = es;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _mudarMes(int delta) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + delta));
    _carregar();
  }

  Future<void> _compartilharAgenda() async {
    final loja = widget.loja;
    final eventos =
        _eventos.where((e) => (e.status).toUpperCase() == 'ATIVO').toList()
          ..sort((a, b) => a.inicio.compareTo(b.inicio));
    final meses = const [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];
    final cidade = loja.nmcidade?.trim();
    final texto = StringBuffer(
      'Veja a agenda do ${loja.nmloja}${cidade?.isNotEmpty == true ? ' em $cidade' : ''} para o mês de ${meses[_mes.month - 1]}:\n\n',
    );
    for (final evento in eventos) {
      final atracoes = [...evento.atracoes]
        ..sort((a, b) => a.inicio.compareTo(b.inicio));
      final inicio = atracoes.isEmpty ? evento.inicio : atracoes.first.inicio;
      if (inicio.year != _mes.year || inicio.month != _mes.month) continue;
      texto.writeln(
        '${DateFormat('dd/MM').format(inicio)} - ${const ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'][inicio.weekday - 1]} às ${DateFormat('HH:mm').format(inicio)}',
      );
      texto.writeln(evento.titulo);
      for (final atracao in atracoes) {
        final estilo = atracao.atracao.estiloMusical?.trim();
        texto.writeln(
          '• ${atracao.atracao.nome}${estilo?.isNotEmpty == true ? ', $estilo' : ''} (${DateFormat('HH:mm').format(atracao.inicio)}–${DateFormat('HH:mm').format(atracao.fim)})',
        );
      }
      texto.writeln();
    }
    texto
      ..writeln('Veja mais e compre seu ingresso digital pelo Clubbar App:')
      ..writeln('$_clubbarAppUrl/?loja_id=${loja.lojaId}');
    await Clipboard.setData(ClipboardData(text: texto.toString().trim()));
    if (mounted) {
      AppSnackBar.sucesso(
        context,
        'Agenda copiada. Cole no WhatsApp, Instagram ou onde desejar.',
      );
    }
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
                        if (mounted) {
                          AppSnackBar.erro(
                            context,
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
    if (ok == true) {
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, 'Programação atualizada.');
    }
  }

  Future<void> _criarEventoNoDia(DateTime dia) async {
    final lojaId = widget.loja.lojaId;
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
    int selecionada = atracoes.first.atracaoId;
    DateTime inicio = DateTime(dia.year, dia.month, dia.day, 20);
    DateTime fim = inicio.add(const Duration(hours: 2));
    final precoController = TextEditingController();
    bool salvando = false;
    final criado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: Text(
            'Criar evento em ${DateFormat('dd/MM/yyyy').format(dia)}',
          ),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selecionada,
                    decoration: const InputDecoration(
                      labelText: 'Primeira atração',
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
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(inicio),
                    ),
                    onTap: () async {
                      final valor = await _dataHora(inicio);
                      if (valor != null) setLocal(() => inicio = valor);
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    tileColor: ClubbarColors.fundo,
                    leading: const Icon(Icons.stop),
                    title: const Text('Fim'),
                    subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(fim)),
                    onTap: () async {
                      final valor = await _dataHora(fim);
                      if (valor != null) setLocal(() => fim = valor);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: precoController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Preço do Lote Único',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'O evento será criado como ativo e o lote ficará disponível para venda imediatamente.',
                    style: TextStyle(color: ClubbarColors.textoSecundario),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: salvando ? null : () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: salvando
                  ? null
                  : () async {
                      final preco = double.tryParse(
                        precoController.text.trim().replaceAll(',', '.'),
                      );
                      if (!fim.isAfter(inicio)) {
                        AppSnackBar.aviso(
                          context,
                          'O fim deve ser posterior ao início.',
                        );
                        return;
                      }
                      if (preco == null || preco < 0) {
                        AppSnackBar.aviso(context, 'Informe um preço válido.');
                        return;
                      }
                      setLocal(() => salvando = true);
                      try {
                        await _repo.criarEventoRapido(
                          lojaId: lojaId,
                          atracaoId: selecionada,
                          inicio: inicio,
                          fim: fim,
                          preco: preco,
                        );
                        if (c.mounted) Navigator.pop(c, true);
                      } catch (e) {
                        setLocal(() => salvando = false);
                        if (mounted) {
                          AppSnackBar.erro(
                            context,
                            e.toString().replaceFirst('Exception: ', ''),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.auto_awesome),
              label: Text(salvando ? 'Criando...' : 'Criar evento'),
            ),
          ],
        ),
      ),
    );
    precoController.dispose();
    if (criado == true) {
      await _carregar();
      if (mounted) {
        AppSnackBar.sucesso(
          context,
          'Evento, atração e lote criados com sucesso.',
        );
      }
    }
  }

  Future<void> _remover(AgendaEvento evento, EventoAtracao p) async {
    final excluiEvento = evento.atracoes.length == 1;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          excluiEvento ? 'Excluir evento completo?' : 'Remover atração?',
        ),
        content: Text(
          excluiEvento
              ? 'Esta é a última atração do evento. Ao continuar, todos os lotes serão excluídos primeiro e depois o evento "${evento.titulo}" será excluído por completo. Esta operação não pode ser desfeita.'
              : 'Deseja remover a atração "${p.atracao.nome}" deste evento?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: excluiEvento
                ? FilledButton.styleFrom(backgroundColor: ClubbarColors.erro)
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(excluiEvento ? 'Excluir evento' : 'Remover'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      await _repo.removerProgramacao(p.programacaoId);
      if (!mounted) return;
      Navigator.pop(context);
      await _carregar();
      if (!mounted) return;
      AppSnackBar.sucesso(
        context,
        excluiEvento
            ? 'Lotes e evento excluídos com sucesso.'
            : 'Atração removida da agenda.',
      );
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
                      onPressed: () => _remover(e, p),
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
    appBar: ClubbarAppBar(
      mostrarVoltar: true,
      actions: [
        IconButton(
          tooltip: 'Compartilhar agenda',
          onPressed: _compartilharAgenda,
          icon: const Icon(Icons.share),
        ),
        PopupMenuButton<String>(
          tooltip: 'Mais opções',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (valor) async {
            if (valor != 'eventos') return;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EventoListPage(
                  organizacaoId: widget.loja.organizacaoId,
                  lojaIdInicial: widget.loja.lojaId,
                  fixarLoja: true,
                ),
              ),
            );
            if (mounted) await _carregar();
          },
          itemBuilder: (_) => const [
            PopupMenuItem<String>(
              value: 'eventos',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.event_note_rounded),
                title: Text('Gerenciar eventos'),
              ),
            ),
          ],
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          ClubbarPageHeader(
            titulo: 'Agenda Mensal - ${widget.loja.nmloja}',
            subtitulo: _nomeOrganizacao,
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
              return InkWell(
                onTap: eventos.isEmpty ? () => _criarEventoNoDia(data) : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: eventos.isEmpty
                        ? ClubbarColors.branco
                        : ClubbarColors.fundoCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: eventos.isEmpty
                          ? ClubbarColors.ambarClaro
                          : ClubbarColors.borda,
                    ),
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
                      if (eventos.isEmpty) const Spacer(),
                      if (eventos.isEmpty)
                        const Align(
                          alignment: Alignment.bottomRight,
                          child: Icon(
                            Icons.add_circle_outline,
                            size: 16,
                            color: ClubbarColors.ambarEscuro,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
