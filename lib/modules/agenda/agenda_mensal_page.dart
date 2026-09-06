import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/repositories/atracao_repository.dart';
import '../../core/repositories/evento_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/atracao.dart';
import '../../models/loja.dart';
import '../atracoes/atracao_list_page.dart';
import '../eventos/evento_list_page.dart';
import '../eventos/evento_lote_list_page.dart';

class AgendaMensalPage extends StatefulWidget {
  final Loja loja;
  final List<Loja> lojas;
  const AgendaMensalPage({
    super.key,
    required this.loja,
    this.lojas = const [],
  });
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
  late Loja _loja;

  @override
  void initState() {
    super.initState();
    _loja = widget.loja;
    _carregar();
  }

  Future<void> _selecionarLoja(int? lojaId) async {
    if (lojaId == null || lojaId == _loja.lojaId) return;
    setState(
      () => _loja = widget.lojas.firstWhere((item) => item.lojaId == lojaId),
    );
    await _carregar();
  }

  Future<void> _abrirGerenciarEventos() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventoListPage(
          organizacaoId: _loja.organizacaoId,
          lojaIdInicial: _loja.lojaId,
          fixarLoja: true,
        ),
      ),
    );
    if (mounted) await _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      final es = await _repo.agenda(_loja.lojaId, _mes);
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
    final loja = _loja;
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

  bool _diaPassado(DateTime dia) {
    final hoje = DateTime.now();
    final dataHoje = DateTime(hoje.year, hoje.month, hoje.day);
    final dataDia = DateTime(dia.year, dia.month, dia.day);
    return dataDia.isBefore(dataHoje);
  }

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
    if (_diaPassado(dia)) {
      AppSnackBar.aviso(
        context,
        'Não é permitido criar eventos em datas passadas.',
      );
      return;
    }

    final lojaId = _loja.lojaId;
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
    final nomeEventoController = TextEditingController();
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
                  TextField(
                    controller: nomeEventoController,
                    autofocus: true,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome do evento',
                      hintText: 'Ex.: Noite do Samba',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                      final nomeEvento = nomeEventoController.text.trim();
                      final preco = double.tryParse(
                        precoController.text.trim().replaceAll(',', '.'),
                      );
                      if (nomeEvento.isEmpty) {
                        AppSnackBar.aviso(context, 'Informe o nome do evento.');
                        return;
                      }
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
                          nomeEvento: nomeEvento,
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
    nomeEventoController.dispose();
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
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover atração?'),
        content: Text(
          'Deseja remover a atração "${p.atracao.nome}" deste evento? A data do evento permanecerá na agenda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
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
      AppSnackBar.sucesso(context, 'Atração removida da agenda.');
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, e.toString());
    }
  }

  Future<void> _excluirOcorrencia(AgendaEvento evento) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir esta data?'),
        content: Text(
          'O evento “${evento.titulo}” será removido somente de ${DateFormat('dd/MM/yyyy').format(evento.inicio)}. O evento padrão e as outras datas não serão alterados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ClubbarColors.erro),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Excluir esta data'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      await EventoRepository().excluirOcorrencia(evento.eventoId);
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, 'Data removida da agenda.');
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _abrirEvento(AgendaEvento e, {bool somenteConsulta = false}) {
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
                if (somenteConsulta)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Data encerrada • disponível somente para consulta',
                      style: TextStyle(
                        color: ClubbarColors.textoSecundario,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
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
                    onTap: somenteConsulta
                        ? null
                        : () {
                            Navigator.pop(sheet);
                            _editarProgramacao(e, p);
                          },
                    trailing: somenteConsulta
                        ? const Icon(Icons.lock_outline, size: 20)
                        : IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: ClubbarColors.erro,
                            ),
                            onPressed: () => _remover(e, p),
                          ),
                  ),
                ),
                if (!somenteConsulta) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheet);
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EventoLoteListPage(
                            eventoId: e.eventoId,
                            eventoTitulo: e.titulo,
                            organizacaoId: _loja.organizacaoId,
                            lojaId: _loja.lojaId,
                            eventoInicio: e.inicio.toIso8601String(),
                          ),
                        ),
                      );
                      if (mounted) await _carregar();
                    },
                    icon: const Icon(Icons.confirmation_number_rounded),
                    label: const Text('Gerenciar ingressos e preços'),
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
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ClubbarColors.erro,
                    ),
                    onPressed: () {
                      Navigator.pop(sheet);
                      _excluirOcorrencia(e);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Excluir esta data'),
                  ),
                ],
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
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          ClubbarPageHeader(
            titulo: _loja.nmloja,
            subtitulo: 'Agenda Mensal',
            tituloStyle: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Colors.blue,
            ),
            padding: const EdgeInsets.fromLTRB(18, 9, 12, 10),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.lojas.length > 1)
                  PopupMenuButton<int>(
                    tooltip: 'Trocar estabelecimento',
                    icon: const Icon(Icons.storefront_rounded),
                    onSelected: _selecionarLoja,
                    itemBuilder: (_) => widget.lojas
                        .map(
                          (loja) => PopupMenuItem<int>(
                            value: loja.lojaId,
                            child: Text(loja.nmloja),
                          ),
                        )
                        .toList(),
                  ),
                FilledButton.icon(
                  onPressed: _loading ? null : _abrirGerenciarEventos,
                  icon: const Icon(Icons.event_note_rounded, size: 18),
                  label: const Text('Gerenciar eventos'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 38),
                  ),
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
                  eventos = _doDia(data),
                  passado = _diaPassado(data);
              return InkWell(
                onTap: eventos.isEmpty && !passado
                    ? () => _criarEventoNoDia(data)
                    : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: passado
                        ? const Color(0xFFE9ECEF)
                        : eventos.isEmpty
                        ? ClubbarColors.branco
                        : ClubbarColors.fundoCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: passado
                          ? const Color(0xFFD2D6DA)
                          : eventos.isEmpty
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
                                onTap: () =>
                                    _abrirEvento(e, somenteConsulta: passado),
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
                      if (eventos.isEmpty && !passado)
                        const Align(
                          alignment: Alignment.bottomRight,
                          child: Icon(
                            Icons.add_circle_outline,
                            size: 16,
                            color: ClubbarColors.ambarEscuro,
                          ),
                        ),
                      if (eventos.isEmpty && passado)
                        const Align(
                          alignment: Alignment.bottomRight,
                          child: Icon(
                            Icons.lock_outline,
                            size: 15,
                            color: ClubbarColors.textoSecundario,
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
