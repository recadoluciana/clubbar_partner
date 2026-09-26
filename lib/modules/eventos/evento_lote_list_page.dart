import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/evento_lote_repository.dart';
import '../../core/repositories/evento_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_action_bar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/evento_lote.dart';
import 'evento_lote_form_page.dart';

class EventoLoteListPage extends StatefulWidget {
  final int eventoId;
  final String eventoTitulo;
  final int organizacaoId;
  final int lojaId;
  final String? eventoInicio;
  final EventoSetor? setorParaGerenciar;
  final int abaInicial;

  const EventoLoteListPage({
    super.key,
    required this.eventoId,
    required this.eventoTitulo,
    required this.organizacaoId,
    required this.lojaId,
    this.eventoInicio,
    this.setorParaGerenciar,
    this.abaInicial = 0,
  });

  @override
  State<EventoLoteListPage> createState() => _EventoLoteListPageState();
}

class _EventoLoteListPageState extends State<EventoLoteListPage> {
  final _repo = EventoLoteRepository();
  final _eventoRepo = EventoRepository();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  bool _carregando = true;
  String? _erro;
  int _aba = 0;
  List<EventoSetor> _setores = [];
  List<EventoLoteGlobal> _globais = [];
  CapacidadeEvento? _capacidade;
  late String? _eventoInicio;

  @override
  void initState() {
    super.initState();
    _aba = widget.abaInicial.clamp(0, 1);
    _eventoInicio = widget.eventoInicio;
    _carregar();
  }

  String get _dataEvento {
    final data = DateTime.tryParse(_eventoInicio ?? '');
    return data == null
        ? 'Data e hora do evento não informadas'
        : DateFormat("dd/MM/yyyy 'às' HH:mm 'horas'").format(data);
  }

  String _data(String? valor) {
    final data = DateTime.tryParse(valor ?? '');
    return data == null ? 'Não informada' : DateFormat("dd/MM/yyyy 'às' HH:mm").format(data);
  }

  Future<DateTime?> _selecionarDataHora(DateTime? atual) async {
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

  Future<void> _editarDataGlobal(EventoLoteGlobal lote, {required bool inicio}) async {
    final atual = DateTime.tryParse(inicio ? lote.inicioVendas ?? '' : lote.fimVendas ?? '');
    final escolhida = await _selecionarDataHora(atual);
    if (escolhida == null) return;
    final inicioAtual = inicio ? escolhida : DateTime.tryParse(lote.inicioVendas ?? '');
    final fimAtual = inicio ? DateTime.tryParse(lote.fimVendas ?? '') : escolhida;
    if (inicioAtual != null && fimAtual != null && !fimAtual.isAfter(inicioAtual)) {
      if (mounted) AppSnackBar.aviso(context, 'O fim das vendas deve ser posterior ao início.');
      return;
    }
    try {
      final valor = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(escolhida);
      await _repo.atualizarGlobal(
        loteGlobalId: lote.id,
        inicioVendas: inicio ? valor : null,
        fimVendas: inicio ? null : valor,
      );
      if (mounted) {
        AppSnackBar.sucesso(context, '${inicio ? 'Início' : 'Fim'} das vendas atualizado.');
        _carregar();
      }
    } catch (erro) {
      if (mounted) AppSnackBar.erro(context, erro.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final respostas = await Future.wait([
        _repo.listarSetores(widget.eventoId),
        _repo.listarGlobais(widget.eventoId),
        _repo.obterCapacidadeEvento(widget.eventoId),
      ]);
      if (!mounted) return;
      setState(() {
        _setores = respostas[0] as List<EventoSetor>;
        _globais = respostas[1] as List<EventoLoteGlobal>;
        _capacidade = respostas[2] as CapacidadeEvento;
        _carregando = false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = erro.toString().replaceFirst('Exception: ', '');
        _carregando = false;
      });
    }
  }

  int get _capacidadeEvento => _capacidade?.capacidadeTotal ?? 0;
  int get _capacidadeSetores => _setores
      .where((setor) => setor.situacao == 'ATIVO')
      .fold(0, (total, setor) => total + setor.capacidade);

  Future<void> _alterarCapacidade() async {
    final controller = TextEditingController(text: _capacidadeEvento.toString());
    final nova = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Capacidade total do evento'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantidade máxima de pessoas',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (nova == null || nova <= 0) return;
    try {
      await _repo.atualizarCapacidadeEvento(eventoId: widget.eventoId, capacidade: nova);
      if (mounted) {
        AppSnackBar.sucesso(context, 'Capacidade total atualizada.');
        _carregar();
      }
    } catch (erro) {
      if (mounted) AppSnackBar.erro(context, erro.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _alterarHorarioEvento() async {
    final atual = DateTime.tryParse(_eventoInicio ?? '') ?? DateTime.now();
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(atual),
    );
    if (hora == null) return;
    final nova = DateTime(atual.year, atual.month, atual.day, hora.hour, hora.minute);
    try {
      await _eventoRepo.atualizarHorarioEventoAgendado(
        eventoId: widget.eventoId,
        inicio: nova,
      );
      if (mounted) {
        setState(() => _eventoInicio = nova.toIso8601String());
        AppSnackBar.sucesso(context, 'Horário do evento atualizado.');
      }
    } catch (erro) {
      if (mounted) AppSnackBar.erro(context, erro.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _editarSetor(EventoSetor? existente) async {
    final nome = TextEditingController(text: existente?.nome ?? '');
    final capacidade = TextEditingController(text: existente?.capacidade.toString() ?? '');
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existente == null ? 'Adicionar setor' : 'Editar setor'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nome, decoration: const InputDecoration(labelText: 'Nome do setor')),
          const SizedBox(height: 12),
          TextField(
            controller: capacidade,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Capacidade máxima de pessoas'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final quantidade = int.tryParse(capacidade.text.trim());
              if (nome.text.trim().isEmpty || quantidade == null || quantidade <= 0) return;
              try {
                if (existente == null) {
                  await _repo.criarSetor(eventoId: widget.eventoId, nome: nome.text.trim(), capacidade: quantidade);
                } else {
                  await _repo.atualizarSetor(setor: existente, nome: nome.text.trim(), capacidade: quantidade);
                }
                if (context.mounted) Navigator.pop(context, true);
              } catch (erro) {
                if (context.mounted) AppSnackBar.erro(context, erro.toString().replaceFirst('Exception: ', ''));
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (resultado == true && mounted) _carregar();
  }

  Future<void> _novoLote() async {
    if (_setores.where((setor) => setor.situacao == 'ATIVO').isEmpty) {
      AppSnackBar.aviso(context, 'Cadastre pelo menos um setor antes de criar o lote global.');
      return;
    }
    final salvou = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => EventoLoteFormPage(
        eventoId: widget.eventoId,
        organizacaoId: widget.organizacaoId,
        lojaId: widget.lojaId,
        eventoTitulo: widget.eventoTitulo,
        eventoInicio: _eventoInicio,
        setores: _setores.where((setor) => setor.situacao == 'ATIVO').toList(),
        proximoNumeroLote: _globais.length + 1,
      ),
    ));
    if (salvou == true && mounted) _carregar();
  }

  Future<void> _editarLoteGlobal(EventoLoteGlobal lote) async {
    final salvou = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => EventoLoteFormPage(
        eventoId: widget.eventoId,
        organizacaoId: widget.organizacaoId,
        lojaId: widget.lojaId,
        eventoTitulo: widget.eventoTitulo,
        eventoInicio: _eventoInicio,
        setores: _setores.where((setor) => setor.situacao == 'ATIVO').toList(),
        proximoNumeroLote: lote.numero,
        loteGlobal: lote,
      ),
    ));
    if (salvou == true && mounted) _carregar();
  }

  Future<void> _editarConfiguracao(EventoLote configuracao) async {
    final limite = TextEditingController(text: configuracao.qttotallote.toString());
    final precoInteira = configuracao.precos.where((preco) => preco.tipo == 'INTEIRA').firstOrNull;
    final preco = TextEditingController(text: (precoInteira?.valor ?? 0).toStringAsFixed(2).replaceAll('.', ','));
    final salvou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lote ${configuracao.numeroLote} · ${configuracao.nomeSetor ?? 'Setor'}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: limite, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantidade neste lote')),
          const SizedBox(height: 12),
          TextField(controller: preco, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Preço da inteira')),
          const SizedBox(height: 10),
          const Text('Ao alterar a inteira, as modalidades existentes são mantidas. Edite cada modalidade no painel abaixo para alterar suas regras.'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final quantidade = int.tryParse(limite.text.trim());
              if (quantidade == null || quantidade <= 0) return;
              try {
                final valor = double.tryParse(preco.text.replaceAll('.', '').replaceAll(',', '.'));
                final modalidades = configuracao.precos.map((item) {
                  if (item.tipo != 'INTEIRA' || valor == null) return item;
                  return EventoLotePreco(
                    id: item.id, nome: item.nome, tipo: item.tipo, valor: valor,
                    aplicaCotaLegal: item.aplicaCotaLegal, exigeComprovante: item.exigeComprovante,
                    situacao: item.situacao, ordem: item.ordem,
                  );
                }).toList();
                await _repo.atualizarConfiguracaoSetor(loteId: configuracao.loteId, limite: quantidade, precos: modalidades);
                if (context.mounted) Navigator.pop(context, true);
              } catch (erro) {
                if (context.mounted) AppSnackBar.erro(context, erro.toString().replaceFirst('Exception: ', ''));
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (salvou == true && mounted) _carregar();
  }

  Future<void> _editarModalidade(EventoLote configuracao, EventoLotePreco atual) async {
    final nome = TextEditingController(text: atual.nome);
    final valor = TextEditingController(text: atual.valor.toStringAsFixed(2).replaceAll('.', ','));
    var usaCota = atual.aplicaCotaLegal;
    var exigeComprovante = atual.exigeComprovante;
    final salvou = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, atualizar) => AlertDialog(
        title: Text('Editar ${atual.nome}'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nome, decoration: const InputDecoration(labelText: 'Modalidade')),
          const SizedBox(height: 12),
          TextField(controller: valor, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Preço')),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: usaCota,
            onChanged: (novo) => atualizar(() => usaCota = novo ?? false),
            title: const Text('Usa a cota legal de meia-entrada'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: exigeComprovante,
            onChanged: (novo) => atualizar(() => exigeComprovante = novo ?? false),
            title: const Text('Exige comprovante'),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            final preco = double.tryParse(valor.text.replaceAll('.', '').replaceAll(',', '.'));
            if (nome.text.trim().isEmpty || preco == null || preco < 0) return;
            try {
              final modalidades = configuracao.precos.map((item) => item.id == atual.id
                  ? EventoLotePreco(id: item.id, nome: nome.text.trim(), tipo: item.tipo, valor: preco, aplicaCotaLegal: usaCota, exigeComprovante: exigeComprovante, situacao: item.situacao, ordem: item.ordem)
                  : item).toList();
              await _repo.atualizarConfiguracaoSetor(loteId: configuracao.loteId, precos: modalidades);
              if (context.mounted) Navigator.pop(context, true);
            } catch (erro) {
              if (context.mounted) AppSnackBar.erro(context, erro.toString().replaceFirst('Exception: ', ''));
            }
          }, child: const Text('Salvar')),
        ],
      )),
    );
    if (salvou == true && mounted) _carregar();
  }

  Future<void> _excluirGlobal(EventoLoteGlobal lote) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir ${lote.nome}?'),
        content: const Text('Todas as configurações de setor deste lote serão excluídas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _repo.excluirGlobal(lote.id);
      if (mounted) {
        AppSnackBar.sucesso(context, 'Lote global excluído.');
        _carregar();
      }
    } catch (erro) {
      if (mounted) AppSnackBar.erro(context, erro.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _resumo() => ListView(padding: const EdgeInsets.all(16), children: [
    Wrap(spacing: 10, runSpacing: 10, children: [
      _numero('Setores', _setores.where((setor) => setor.situacao == 'ATIVO').length.toString(), Icons.stadium_outlined),
      _numero(
        'Capacidade autorizada',
        '$_capacidadeEvento',
        Icons.groups_outlined,
        onEditar: _alterarCapacidade,
      ),
      _numero('Capacidade distribuída', '$_capacidadeSetores', Icons.pie_chart_outline),
      _numero('Lotes globais', _globais.length.toString(), Icons.confirmation_number_outlined),
    ]),
    const SizedBox(height: 18),
    ClubbarCard(child: Row(children: [
      const Icon(Icons.event_available_outlined, color: ClubbarColors.primariaEscuro),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Agendado para', style: TextStyle(fontSize: 12)),
        Text(_dataEvento, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ])),
      IconButton(
        onPressed: _alterarHorarioEvento,
        icon: const Icon(Icons.access_time_rounded, color: Colors.blue),
        tooltip: 'Alterar horário do evento',
      ),
    ])),
    const SizedBox(height: 18),
    const Text('Setores do evento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 6),
    const Text('A capacidade de cada setor define o máximo distribuível entre todos os lotes globais.'),
    const SizedBox(height: 12),
    ..._setores.map((setor) => ClubbarCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        const CircleAvatar(child: Icon(Icons.stadium_outlined)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(setor.nome, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text('Capacidade máxima: ${setor.capacidade} pessoas'),
        ])),
        IconButton(onPressed: () => _editarSetor(setor), icon: const Icon(Icons.edit_rounded, color: Colors.blue), tooltip: 'Editar setor'),
      ]),
    )),
  ]);

  Widget _numero(String titulo, String valor, IconData icone, {VoidCallback? onEditar}) => SizedBox(
    width: 205,
    child: ClubbarCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Icon(icone, color: ClubbarColors.primariaEscuro),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titulo, style: const TextStyle(fontSize: 11)), Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))])),
        if (onEditar != null) IconButton(onPressed: onEditar, icon: const Icon(Icons.edit_rounded, size: 19, color: Colors.blue), tooltip: 'Editar capacidade autorizada'),
      ]),
    ),
  );

  Widget _lotes() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Lotes globais do evento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 6),
    const Text('Cada lote abre ou encerra ao mesmo tempo para todos os setores. Um setor esgotado fica indisponível, sem mudar sozinho de lote.'),
    const SizedBox(height: 14),
    if (_globais.isEmpty) const ClubbarCard(child: Center(child: Padding(padding: EdgeInsets.all(18), child: Text('Nenhum lote global programado.')))),
    ..._globais.map(_cardLoteGlobal),
  ]);

  Widget _cardLoteGlobal(EventoLoteGlobal lote) => ClubbarCard(
    margin: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(backgroundColor: ClubbarColors.primariaClaro, child: Text('${lote.numero}', style: const TextStyle(fontWeight: FontWeight.w900))),
        const SizedBox(width: 10),
        Expanded(child: Text(lote.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        Chip(label: Text(lote.disponivelGlobalmente ? 'Em venda' : lote.situacao), backgroundColor: lote.disponivelGlobalmente ? Colors.green.shade50 : null),
        IconButton(onPressed: () => _editarLoteGlobal(lote), icon: const Icon(Icons.edit_rounded, color: Colors.blue), tooltip: 'Editar lote global'),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: lote.numero == 1
            ? _dataCard(
                Icons.play_circle_outline,
                'Início das vendas',
                _data(lote.inicioVendas),
                onEditar: () => _editarDataGlobal(lote, inicio: true),
              )
            : _dataCard(
                Icons.auto_mode_rounded,
                'Início das vendas',
                'Automático na virada do Lote ${lote.numero - 1}',
              )),
        const SizedBox(width: 10),
        Expanded(child: _dataCard(
          Icons.stop_circle_outlined,
          'Fim / virada',
          _data(lote.fimVendas),
          onEditar: () => _editarDataGlobal(lote, inicio: false),
        )),
      ]),
      const SizedBox(height: 10),
      Text('Virada: ${lote.gatilhoVirada == 'DATA' ? 'na data final' : lote.gatilhoVirada == 'ESGOTAMENTO' ? 'quando todos os setores esgotarem' : 'na primeira condição: data final ou esgotamento global'}'),
      const SizedBox(height: 10),
      ...lote.setores.map((configuracao) => _setorNoLote(configuracao)),
      const SizedBox(height: 8),
      Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => _excluirGlobal(lote), icon: const Icon(Icons.delete_outline, color: Colors.red), label: const Text('Excluir lote', style: TextStyle(color: Colors.red)))),
    ]),
  );

  Widget _dataCard(IconData icone, String titulo, String valor, {VoidCallback? onEditar}) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: ClubbarColors.fundo, borderRadius: BorderRadius.circular(12), border: Border.all(color: ClubbarColors.borda)),
    child: Row(children: [
      Icon(icone, color: ClubbarColors.primariaEscuro),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titulo, style: const TextStyle(fontSize: 11)), Text(valor, style: const TextStyle(fontWeight: FontWeight.w800))])),
      if (onEditar != null) IconButton(onPressed: onEditar, icon: const Icon(Icons.calendar_month_rounded, color: Colors.blue), tooltip: 'Alterar data e hora'),
    ]),
  );

  Widget _setorNoLote(EventoLote configuracao) => Container(
    margin: const EdgeInsets.only(top: 10),
    decoration: BoxDecoration(border: Border.all(color: ClubbarColors.borda), borderRadius: BorderRadius.circular(12)),
    child: ExpansionTile(
      title: Text(configuracao.nomeSetor ?? 'Setor', style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${configuracao.qttotallote} ingressos neste lote · ${configuracao.qtvendidalote} vendidos · ${configuracao.qtReservadaLote} reservados'),
      trailing: IconButton(onPressed: () => _editarConfiguracao(configuracao), icon: const Icon(Icons.edit_rounded, color: Colors.blue), tooltip: 'Editar setor neste lote'),
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: Column(children: configuracao.precos.map((preco) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: ClubbarColors.fundo, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(preco.nome, style: const TextStyle(fontWeight: FontWeight.w800))),
              IconButton(onPressed: () => _editarModalidade(configuracao, preco), icon: const Icon(Icons.edit_rounded, color: Colors.blue), tooltip: 'Editar modalidade'),
            ]),
            Text('Preço: ${_moeda.format(preco.valor)}'),
            Text(preco.aplicaCotaLegal ? 'Regra: usa a cota legal de meia-entrada' : preco.exigeComprovante ? 'Regra: comprovante obrigatório' : 'Regra: sem exigência'),
          ]),
        )).toList())),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: _aba,
    child: Scaffold(
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: Column(children: [
      ClubbarPageHeader(titulo: widget.eventoTitulo, subtitulo: 'Gerenciar evento, setores, lotes e preços', trailing: IconButton(onPressed: _carregar, icon: const Icon(Icons.refresh_rounded))),
      TabBar(
        onTap: (indice) => setState(() => _aba = indice),
        tabs: const [Tab(text: 'Resumo do Evento'), Tab(text: 'Lotes globais e preços')],
      ),
      Expanded(child: _carregando ? const Center(child: CircularProgressIndicator()) : _erro != null ? Center(child: Text(_erro!)) : _aba == 0 ? _resumo() : _lotes()),
    ]),
    bottomNavigationBar: ClubbarActionBar(actions: [
      if (_aba == 0) ClubbarAddButton(label: 'Adicionar setor', onPressed: () => _editarSetor(null)),
      if (_aba == 1) ClubbarAddButton(label: 'Adicionar lote global', onPressed: _novoLote),
    ]),
    ),
  );
}
