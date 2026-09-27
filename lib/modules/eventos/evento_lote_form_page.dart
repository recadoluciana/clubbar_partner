import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/evento_lote_repository.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_action_bar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/evento_lote.dart';

class EventoLoteFormPage extends StatefulWidget {
  final int eventoId;
  final int organizacaoId;
  final int lojaId;
  final String eventoTitulo;
  final String? eventoInicio;
  final List<EventoSetor> setores;
  final int proximoNumeroLote;
  final EventoLoteGlobal? loteGlobal;

  const EventoLoteFormPage({
    super.key,
    required this.eventoId,
    required this.organizacaoId,
    required this.lojaId,
    required this.eventoTitulo,
    required this.setores,
    required this.proximoNumeroLote,
    this.eventoInicio,
    this.loteGlobal,
  });

  @override
  State<EventoLoteFormPage> createState() => _EventoLoteFormPageState();
}

class _EventoLoteFormPageState extends State<EventoLoteFormPage> {
  final _repo = EventoLoteRepository();
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _inicio = TextEditingController();
  final _fim = TextEditingController();
  final Map<int, TextEditingController> _quantidades = {};
  final Map<int, TextEditingController> _inteiras = {};
  DateTime? _inicioSelecionado;
  DateTime? _fimSelecionado;
  bool _salvando = false;
  String _gatilho = 'HIBRIDO';

  bool get _editando => widget.loteGlobal != null;
  int get _numero => widget.loteGlobal?.numero ?? widget.proximoNumeroLote;
  bool get _temInicioProprio => _numero == 1;

  @override
  void initState() {
    super.initState();
    final lote = widget.loteGlobal;
    _nome.text = lote?.nome ?? 'Lote $_numero';
    _gatilho = lote?.gatilhoVirada ?? 'HIBRIDO';
    _inicioSelecionado = _temInicioProprio
        ? DateTime.tryParse(lote?.inicioVendas ?? '')
        : null;
    _fimSelecionado = DateTime.tryParse(lote?.fimVendas ?? '');
    if (_inicioSelecionado != null) _inicio.text = _br(_inicioSelecionado!);
    if (_fimSelecionado != null) _fim.text = _br(_fimSelecionado!);
    for (final setor in widget.setores) {
      final configuracao = lote?.setores.where((item) => item.eventoSetorId == setor.id).firstOrNull;
      _quantidades[setor.id] = TextEditingController(text: '${configuracao?.qttotallote ?? setor.capacidade}');
      final inteira = configuracao?.precos.where((preco) => preco.tipo == 'INTEIRA').firstOrNull;
      _inteiras[setor.id] = TextEditingController(text: (inteira?.valor ?? 0).toStringAsFixed(2).replaceAll('.', ','));
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _inicio.dispose();
    _fim.dispose();
    for (final controller in _quantidades.values) { controller.dispose(); }
    for (final controller in _inteiras.values) { controller.dispose(); }
    super.dispose();
  }

  String _br(DateTime data) => DateFormat("dd/MM/yyyy 'às' HH:mm").format(data);
  String _api(DateTime data) => DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(data);

  Future<DateTime?> _selecionar(DateTime? atual) async {
    final data = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data == null || !mounted) return null;
    final hora = await showTimePicker(
      context: context,
      initialTime: atual == null ? TimeOfDay.now() : TimeOfDay.fromDateTime(atual),
    );
    if (hora == null) return null;
    return DateTime(data.year, data.month, data.day, hora.hour, hora.minute);
  }

  Future<void> _selecionarInicio() async {
    final data = await _selecionar(_inicioSelecionado);
    if (data != null && mounted) setState(() { _inicioSelecionado = data; _inicio.text = _br(data); });
  }

  Future<void> _selecionarFim() async {
    final data = await _selecionar(_fimSelecionado ?? _inicioSelecionado);
    if (data != null && mounted) setState(() { _fimSelecionado = data; _fim.text = _br(data); });
  }

  double _valor(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

  List<Map<String, dynamic>> _setoresPayload() => widget.setores.map((setor) {
    final inteira = _valor(_inteiras[setor.id]!);
    final meia = inteira / 2;
    return {
      'eventosetor_id': setor.id,
      'qtlimite': int.tryParse(_quantidades[setor.id]!.text.trim()) ?? 0,
      'precos': [
        {'nmpreco': 'Inteira', 'tipopreco': 'INTEIRA', 'vrpreco': inteira, 'aplicacotalegal': false, 'exigecomprovante': false, 'nrordem': 1},
        {'nmpreco': 'Meia-entrada', 'tipopreco': 'MEIA_LEGAL', 'vrpreco': meia, 'aplicacotalegal': true, 'exigecomprovante': true, 'nrordem': 2},
        {'nmpreco': 'Pessoa idosa', 'tipopreco': 'MEIA_IDOSO', 'vrpreco': meia, 'aplicacotalegal': false, 'exigecomprovante': true, 'nrordem': 3},
      ],
    };
  }).toList();

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if ((_temInicioProprio && _inicioSelecionado == null) || _fimSelecionado == null ||
        (_temInicioProprio && !_fimSelecionado!.isAfter(_inicioSelecionado!))) {
      AppSnackBar.aviso(context, _temInicioProprio
          ? 'Informe início e fim das vendas, com fim posterior ao início.'
          : 'Informe o fim das vendas deste lote. O início será automático.');
      return;
    }
    if (!_editando && _setoresPayload().any((setor) => (setor['qtlimite'] as int) <= 0 || ((setor['precos'] as List).first['vrpreco'] as double) < 0)) {
      AppSnackBar.aviso(context, 'Informe uma quantidade e um preço válidos para cada setor.');
      return;
    }
    setState(() => _salvando = true);
    try {
      if (_editando) {
        await _repo.atualizarGlobal(
          loteGlobalId: widget.loteGlobal!.id,
          nome: _nome.text.trim(),
          inicioVendas: _temInicioProprio ? _api(_inicioSelecionado!) : null,
          fimVendas: _api(_fimSelecionado!),
          gatilhoVirada: _gatilho,
        );
      } else {
        await _repo.criarGlobal(
          eventoId: widget.eventoId,
          organizacaoId: widget.organizacaoId,
          lojaId: widget.lojaId,
          nome: _nome.text.trim(),
          inicioVendas: _temInicioProprio ? _api(_inicioSelecionado!) : null,
          fimVendas: _api(_fimSelecionado!),
          gatilhoVirada: _gatilho,
          setores: _setoresPayload(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (erro) {
      if (mounted) AppSnackBar.erro(context, erro.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: Column(children: [
      ClubbarPageHeader(
        titulo: _editando ? 'Editar Lote $_numero' : 'Novo Lote $_numero',
        subtitulo: widget.eventoTitulo,
      ),
      Expanded(child: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          ClubbarCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Etapa global de vendas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Quando este lote estiver em venda, todos os setores vendem nesta mesma etapa. A passagem para o próximo lote é única para todo o evento.'),
            const SizedBox(height: 14),
            TextFormField(controller: _nome, decoration: const InputDecoration(labelText: 'Nome do lote'), validator: (valor) => valor == null || valor.trim().isEmpty ? 'Informe o nome do lote' : null),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _gatilho,
              decoration: const InputDecoration(labelText: 'Como virar para o próximo lote'),
              items: const [
                DropdownMenuItem(value: 'HIBRIDO', child: Text('Na data final ou quando todos os setores esgotarem')),
                DropdownMenuItem(value: 'DATA', child: Text('Somente na data final')),
                DropdownMenuItem(value: 'ESGOTAMENTO', child: Text('Somente quando todos os setores esgotarem')),
              ],
              onChanged: (valor) => setState(() => _gatilho = valor ?? 'HIBRIDO'),
            ),
            const SizedBox(height: 12),
            if (_temInicioProprio)
              TextFormField(controller: _inicio, readOnly: true, onTap: _selecionarInicio, decoration: const InputDecoration(labelText: 'Início das vendas', suffixIcon: Icon(Icons.calendar_month_outlined)))
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.auto_mode_rounded),
                  title: Text('Início automático'),
                  subtitle: Text('Este lote começa quando o lote anterior virar; não há intervalo sem vendas.'),
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(controller: _fim, readOnly: true, onTap: _selecionarFim, decoration: const InputDecoration(labelText: 'Fim das vendas / limite de virada', suffixIcon: Icon(Icons.calendar_month_outlined))),
          ])),
          if (!_editando) ...[
            const SizedBox(height: 16),
            const Text('Configuração deste lote por setor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Defina o máximo que cada setor poderá vender enquanto este lote estiver vigente. O estoque é compartilhado: as vendas dos lotes anteriores reduzem automaticamente a disponibilidade do próximo lote. A inteira cria automaticamente Meia-entrada e Pessoa idosa a 50%; você poderá ajustar cada modalidade depois.'),
            const SizedBox(height: 10),
            ...widget.setores.map((setor) => ClubbarCard(
              margin: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(setor.nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                Text('Capacidade total do setor: ${setor.capacidade} pessoas'),
                const SizedBox(height: 12),
                TextFormField(controller: _quantidades[setor.id], keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: 'Máximo deste setor no Lote $_numero', helperText: 'Até ${setor.capacidade} ingressos, conforme o estoque restante do setor.'), validator: (valor) => (int.tryParse(valor ?? '') ?? 0) <= 0 ? 'Informe a quantidade' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _inteiras[setor.id], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Preço da inteira'), validator: (valor) => _valor(_inteiras[setor.id]!) < 0 ? 'Preço inválido' : null),
              ]),
            )),
          ],
        ]),
      )),
    ]),
    bottomNavigationBar: ClubbarActionBar(actions: [
      FilledButton.icon(onPressed: _salvando ? null : _salvar, icon: _salvando ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded), label: const Text('Salvar lote global')),
    ]),
  );
}
