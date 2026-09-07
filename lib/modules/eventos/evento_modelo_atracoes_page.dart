import 'package:flutter/material.dart';

import '../../core/repositories/evento_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/atracao.dart';

class EventoModeloAtracoesPage extends StatefulWidget {
  final int modeloId;
  final String titulo;
  const EventoModeloAtracoesPage({
    super.key,
    required this.modeloId,
    required this.titulo,
  });

  @override
  State<EventoModeloAtracoesPage> createState() =>
      _EventoModeloAtracoesPageState();
}

class _EventoModeloAtracoesPageState extends State<EventoModeloAtracoesPage> {
  final _eventos = EventoRepository();
  List<EventoModeloAtracao> _itens = [];
  List<Atracao> _catalogo = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final resultados = await Future.wait([
        _eventos.listarAtracoesPadrao(widget.modeloId),
        _eventos.listarAtracoesDisponiveis(widget.modeloId),
      ]);
      if (!mounted) return;
      setState(() {
        _itens = resultados[0] as List<EventoModeloAtracao>;
        _catalogo = resultados[1] as List<Atracao>;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _tempo(int minutos) => minutos < 60
      ? '$minutos min'
      : '${minutos ~/ 60}h${minutos % 60 == 0 ? '' : ' ${minutos % 60}min'}';

  Future<void> _editar([EventoModeloAtracao? atual]) async {
    if (_catalogo.isEmpty) {
      AppSnackBar.aviso(
        context,
        'Nenhuma atração cadastrada para esta organização.',
      );
      return;
    }
    int atracaoId = atual?.atracaoId ?? _catalogo.first.atracaoId;
    final ordem = TextEditingController(
      text: '${atual?.ordem ?? (_itens.length + 1)}',
    );
    final inicio = TextEditingController(text: '${atual?.minutoInicio ?? 0}');
    final duracao = TextEditingController(
      text: '${atual?.minutoDuracao ?? 120}',
    );
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: Text(
            atual == null
                ? 'Adicionar atração padrão'
                : 'Editar atração padrão',
          ),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: atracaoId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Atração',
                      border: OutlineInputBorder(),
                    ),
                    items: _catalogo
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.atracaoId,
                            child: Text(a.nome),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => atracaoId = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ordem,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ordem de apresentação',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: inicio,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Começa quantos minutos após o evento?',
                      suffixText: 'min',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: duracao,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duração prevista',
                      suffixText: 'min',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (confirmou != true || !mounted) return;
    final o = int.tryParse(ordem.text),
        i = int.tryParse(inicio.text),
        d = int.tryParse(duracao.text);
    if (o == null || o < 1 || i == null || i < 0 || d == null || d < 1) {
      AppSnackBar.aviso(context, 'Confira a ordem e os tempos informados.');
      return;
    }
    try {
      await _eventos.salvarAtracaoPadrao(
        modeloId: widget.modeloId,
        item: atual,
        atracaoId: atracaoId,
        ordem: o,
        minutoInicio: i,
        minutoDuracao: d,
      );
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, 'Atração padrão salva.');
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _excluir(EventoModeloAtracao item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir atração padrão?'),
        content: Text(
          'A atração “${item.nomeAtracao}” deixará de ser copiada para as próximas datas. Eventos já agendados não serão alterados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _eventos.excluirAtracaoPadrao(item.id);
      await _carregar();
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
    body: Column(
      children: [
        ClubbarPageHeader(
          titulo: widget.titulo,
          subtitulo: 'Atrações padrão',
          tituloWidget: Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Evento padrão: ',
                  style: TextStyle(color: Colors.black),
                ),
                TextSpan(
                  text: widget.titulo,
                  style: const TextStyle(color: Colors.blue),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : _itens.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Nenhuma atração padrão. Cadastre aqui as atrações que devem ser copiadas ao agendar uma nova data.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _itens.length,
                    itemBuilder: (c, index) {
                      final x = _itens[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${x.ordem}')),
                          title: Text(
                            x.nomeAtracao,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Início: ${_tempo(x.minutoInicio)} após o evento • Duração: ${_tempo(x.minutoDuracao)}',
                          ),
                          onTap: () => _editar(x),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Editar atração',
                                onPressed: () => _editar(x),
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.blue,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Excluir atração',
                                onPressed: () => _excluir(x),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: ClubbarColors.erro,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _carregando ? null : () => _editar(),
      icon: const Icon(Icons.add),
      label: const Text('Adicionar atração'),
    ),
  );
}
