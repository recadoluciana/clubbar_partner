import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/evento_lote_repository.dart';
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
  final bool abrirAlteracaoCapacidade;

  const EventoLoteListPage({super.key, required this.eventoId, required this.eventoTitulo, required this.organizacaoId, required this.lojaId, this.eventoInicio, this.setorParaGerenciar, this.abaInicial = 0, this.abrirAlteracaoCapacidade = false});

  @override
  State<EventoLoteListPage> createState() => _EventoLoteListPageState();
}

class _EventoLoteListPageState extends State<EventoLoteListPage> {
  final EventoLoteRepository _repo = EventoLoteRepository();
  final TextEditingController _buscaController = TextEditingController();
  final NumberFormat _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  bool _carregando = true;
  bool _excluindo = false;
  bool _dialogCapacidadeAberto = false;
  String? _erro;
  int _abaAtual = 0;
  List<EventoLote> _lotes = [];
  List<EventoSetor> _setores = [];

  @override
  void initState() { super.initState(); _abaAtual = widget.abaInicial.clamp(0, 1); _carregar(); }
  @override
  void dispose() { _buscaController.dispose(); super.dispose(); }

  String _mensagemErro(Object erro) {
    final texto = erro.toString().replaceFirst('Exception: ', '').trim();
    return texto.isEmpty ? 'Ocorreu um erro inesperado.' : texto;
  }

  Future<void> _carregar() async {
    setState(() { _carregando = true; _erro = null; });
    try {
      final respostas = await Future.wait([_repo.listar(widget.eventoId), _repo.listarSetores(widget.eventoId)]);
      if (!mounted) return;
      setState(() { _lotes = respostas[0] as List<EventoLote>; _setores = respostas[1] as List<EventoSetor>; _carregando = false; });
      if (widget.abrirAlteracaoCapacidade && !_dialogCapacidadeAberto) {
        _dialogCapacidadeAberto = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _alterarCapacidadeTotal();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _erro = _mensagemErro(e); _carregando = false; });
      AppSnackBar.erro(context, _erro!);
    }
  }

  int get _capacidadeEvento => _setores.where((s) => s.situacao == 'ATIVO').fold(0, (total, s) => total + s.capacidade);
  int get _vendidos => _lotes.fold(0, (total, lote) => total + lote.qtvendidalote);
  int get _reservados => _lotes.fold(0, (total, lote) => total + lote.qtReservadaLote);
  int get _cotaLegal => (_capacidadeEvento * .40).floor();
  int get _cotaUsada => _lotes.isEmpty ? 0 : _lotes.first.quantidadeVendidaCotaLegal + _lotes.first.quantidadeReservadaCotaLegal;

  String get _dataHoraEvento {
    final inicio = DateTime.tryParse(widget.eventoInicio ?? '');
    return inicio == null ? 'Não informadas' : DateFormat('dd/MM/yyyy às HH:mm').format(inicio);
  }
  String _formatarData(String? valor) {
    final data = valor == null ? null : DateTime.tryParse(valor);
    return data == null ? 'Não informada' : DateFormat('dd/MM/yyyy às HH:mm').format(data);
  }
  List<EventoLote> _lotesDoSetor(int setorId) {
    final lotes = _lotes.where((lote) => lote.eventoSetorId == setorId).toList()..sort((a, b) => a.numeroLote.compareTo(b.numeroLote));
    return lotes;
  }
  DateTime _sugestaoInicio(EventoSetor setor) {
    final lotes = _lotesDoSetor(setor.id);
    if (lotes.isNotEmpty) {
      final fim = DateTime.tryParse(lotes.last.dtfimvenda ?? '');
      if (fim != null) return fim.add(const Duration(minutes: 1));
    }
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day, agora.hour, agora.minute);
  }

  Future<void> _novoLote(EventoSetor setor) async {
    final lotes = _lotesDoSetor(setor.id);
    final resultado = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EventoLoteFormPage(
      eventoId: widget.eventoId, organizacaoId: widget.organizacaoId, lojaId: widget.lojaId,
      eventoTitulo: widget.eventoTitulo, eventoInicio: widget.eventoInicio, setorInicialId: setor.id,
      proximoNumeroLote: lotes.isEmpty ? 1 : lotes.last.numeroLote + 1, inicioVendaSugerido: _sugestaoInicio(setor),
    )));
    if (resultado == true) await _carregar();
  }
  Future<void> _editarLote(EventoLote lote) async {
    final resultado = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EventoLoteFormPage(
      eventoId: widget.eventoId, organizacaoId: widget.organizacaoId, lojaId: widget.lojaId,
      eventoTitulo: widget.eventoTitulo, eventoInicio: widget.eventoInicio, setorInicialId: lote.eventoSetorId, lote: lote,
    )));
    if (resultado == true) await _carregar();
  }

  Future<void> _novoSetor() async {
    final nome = TextEditingController(); final capacidade = TextEditingController();
    final confirmou = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Novo setor do evento'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nome, decoration: const InputDecoration(labelText: 'Nome do setor')),
        const SizedBox(height: 12), TextField(controller: capacidade, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacidade máxima')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Criar setor'))],
    ));
    if (confirmou == true) {
      try {
        await _repo.criarSetor(eventoId: widget.eventoId, nome: nome.text.trim(), capacidade: int.tryParse(capacidade.text.trim()) ?? 0);
        if (!mounted) return;
        AppSnackBar.sucesso(context, 'Setor criado. Agora você pode programar os lotes dele.'); await _carregar();
      } catch (e) { if (mounted) AppSnackBar.erro(context, _mensagemErro(e)); }
    }
    nome.dispose(); capacidade.dispose();
  }

  Future<void> _editarSetor(EventoSetor setor) async {
    final nome = TextEditingController(text: setor.nome);
    final capacidade = TextEditingController(text: '${setor.capacidade}');
    final confirmou = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Editar setor'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nome, decoration: const InputDecoration(labelText: 'Nome do setor')),
        const SizedBox(height: 12),
        TextField(controller: capacidade, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantidade máxima de pessoas')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salvar'))],
    ));
    if (confirmou == true) {
      try {
        await _repo.atualizarSetor(setor: setor, nome: nome.text, capacidade: int.tryParse(capacidade.text.trim()) ?? 0);
        if (!mounted) return;
        AppSnackBar.sucesso(context, 'Setor atualizado.');
        await _carregar();
      } catch (e) { if (mounted) AppSnackBar.erro(context, _mensagemErro(e)); }
    }
    nome.dispose(); capacidade.dispose();
  }

  Future<void> _alterarCapacidadeTotal() async {
    final setoresAtivos = _setores.where((setor) => setor.situacao == 'ATIVO').toList();
    if (setoresAtivos.isEmpty) {
      AppSnackBar.aviso(context, 'Crie ao menos um setor antes de definir a capacidade total.');
      return;
    }
    final total = TextEditingController(text: '$_capacidadeEvento');
    var setorId = setoresAtivos.first.id;
    final confirmou = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (context, atualizar) => AlertDialog(
      title: const Text('Alterar capacidade total'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('A capacidade total é a soma dos setores. Escolha qual setor receberá o ajuste.'),
        const SizedBox(height: 14),
        TextField(controller: total, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total de pessoas no evento')),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(initialValue: setorId, decoration: const InputDecoration(labelText: 'Setor que será ajustado'), items: setoresAtivos.map((setor) => DropdownMenuItem(value: setor.id, child: Text(setor.nome))).toList(), onChanged: (valor) => atualizar(() => setorId = valor!)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salvar capacidade'))],
    )));
    if (confirmou == true) {
      final novoTotal = int.tryParse(total.text.trim()) ?? 0;
      final setor = setoresAtivos.firstWhere((item) => item.id == setorId);
      final outros = _capacidadeEvento - setor.capacidade;
      final novaCapacidadeSetor = novoTotal - outros;
      if (novaCapacidadeSetor <= 0) {
        if (mounted) AppSnackBar.aviso(context, 'O total informado é menor que a soma dos demais setores.');
      } else {
        try {
          await _repo.atualizarSetor(setor: setor, nome: setor.nome, capacidade: novaCapacidadeSetor);
          if (!mounted) return;
          AppSnackBar.sucesso(context, 'Capacidade total atualizada para $novoTotal pessoas.');
          await _carregar();
        } catch (e) { if (mounted) AppSnackBar.erro(context, _mensagemErro(e)); }
      }
    }
    total.dispose();
  }

  Future<void> _gerenciarLotesDoSetor(EventoSetor setor) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventoLoteListPage(
      eventoId: widget.eventoId, eventoTitulo: widget.eventoTitulo, organizacaoId: widget.organizacaoId,
      lojaId: widget.lojaId, eventoInicio: widget.eventoInicio, setorParaGerenciar: setor,
    )));
    if (mounted) await _carregar();
  }

  Future<void> _excluirLote(EventoLote lote) async {
    if (_excluindo) return;
    final confirmou = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Excluir lote'), content: Text('Deseja excluir ${lote.nmlote}? Não é possível excluir um lote que já tenha vendas.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(style: FilledButton.styleFrom(backgroundColor: ClubbarColors.erro), onPressed: () => Navigator.pop(c, true), child: const Text('Excluir'))],
    ));
    if (confirmou != true) return;
    setState(() => _excluindo = true);
    try { await _repo.excluir(lote.loteId); if (!mounted) return; AppSnackBar.sucesso(context, 'Lote excluído.'); await _carregar(); }
    catch (e) { if (mounted) AppSnackBar.erro(context, _mensagemErro(e)); }
    finally { if (mounted) setState(() => _excluindo = false); }
  }

  Widget _itemResumo(String titulo, String valor, IconData icone) => Container(
    padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: ClubbarColors.branco, borderRadius: BorderRadius.circular(14), border: Border.all(color: ClubbarColors.borda)),
    child: Row(children: [Icon(icone, color: ClubbarColors.info), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titulo, style: const TextStyle(fontSize: 11, color: ClubbarColors.textoSecundario)), Text(valor, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))])]),
  );

  Widget _abaResumo() {
    final disponiveis = (_capacidadeEvento - _vendidos - _reservados).clamp(0, _capacidadeEvento);
    final restanteCota = (_cotaLegal - _cotaUsada).clamp(0, _cotaLegal);
    return RefreshIndicator(onRefresh: _carregar, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(20, 16, 20, 30), children: [
      ClubbarCard(backgroundColor: ClubbarColors.infoClaro, borderColor: ClubbarColors.info, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Evento', style: TextStyle(color: ClubbarColors.textoSecundario)), const SizedBox(height: 3), Text(widget.eventoTitulo, style: const TextStyle(color: ClubbarColors.info, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12), Row(children: [const Icon(Icons.calendar_month_rounded, color: ClubbarColors.info), const SizedBox(width: 8), Expanded(child: Text('Data e hora: $_dataHoraEvento', style: const TextStyle(fontWeight: FontWeight.w800)))]),
      ])),
      const SizedBox(height: 12), Wrap(spacing: 10, runSpacing: 10, children: [
        SizedBox(width: 190, child: _itemResumo('Setores', '${_setores.length}', Icons.stadium_rounded)), SizedBox(width: 190, child: _itemResumo('Capacidade total', '$_capacidadeEvento', Icons.groups_rounded)),
        SizedBox(width: 190, child: _itemResumo('Ingressos disponíveis', '$disponiveis', Icons.confirmation_number_rounded)), SizedBox(width: 190, child: _itemResumo('Lotes programados', '${_lotes.length}', Icons.sell_rounded)),
      ]),
      const SizedBox(height: 12), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _carregando ? null : _alterarCapacidadeTotal, icon: const Icon(Icons.groups_rounded), label: const Text('Alterar capacidade total de pessoas'))),
      const SizedBox(height: 12), ClubbarCard(backgroundColor: ClubbarColors.avisoClaro, borderColor: ClubbarColors.ambar, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.gavel_rounded), SizedBox(width: 8), Text('Regras de venda', style: TextStyle(fontWeight: FontWeight.w900))]), const SizedBox(height: 10),
        Text('Cota de meia-entrada: $_cotaLegal ingressos • ainda disponíveis: $restanteCota', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 7),
        const Text('Cada lote oferece Inteira, Meia-entrada e Pessoa idosa. A meia legal ocupa a cota de 40% do evento; a pessoa idosa tem 50% de desconto e não consome essa cota.'), const SizedBox(height: 7),
        const Text('Em cada setor, os lotes são sequenciais. O próximo inicia exatamente um minuto após o horário final do anterior, sem sobreposição nem interrupção de vendas.'),
      ])),
    ]));
  }

  Widget _cardSetor(EventoSetor setor) {
    final lotes = _lotesDoSetor(setor.id);
    return ClubbarCard(margin: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: ClubbarColors.infoClaro, shape: BoxShape.circle), child: const Icon(Icons.stadium_rounded, color: ClubbarColors.info)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(setor.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text('Capacidade máxima: ${setor.capacidade} pessoas', style: const TextStyle(color: ClubbarColors.textoSecundario))])), IconButton(onPressed: _carregando ? null : () => _editarSetor(setor), tooltip: 'Editar nome e capacidade do setor', icon: const Icon(Icons.edit_outlined, color: ClubbarColors.info))]),
      const SizedBox(height: 12), Text(lotes.isEmpty ? 'Nenhum lote programado neste setor.' : '${lotes.length} lote(s) programado(s)', style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _carregando ? null : () => _gerenciarLotesDoSetor(setor), icon: const Icon(Icons.confirmation_number_rounded), label: const Text('Gerenciar lotes'), style: ElevatedButton.styleFrom(backgroundColor: ClubbarColors.sucesso, foregroundColor: ClubbarColors.branco))),
    ]));
  }

  Widget _abaSetores() {
    if (_carregando) return const Center(child: CircularProgressIndicator()); if (_erro != null) return _erroWidget();
    return RefreshIndicator(onRefresh: _carregar, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(20, 16, 20, 90), children: [
      const Text('Setores do evento', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 4), const Text('Cadastre os setores e a capacidade máxima de cada um.', style: TextStyle(color: ClubbarColors.textoSecundario)), const SizedBox(height: 14),
      if (_setores.isEmpty) ClubbarCard(child: const Padding(padding: EdgeInsets.all(16), child: Text('Ainda não há setores. Crie o primeiro setor para começar a programar os ingressos.', textAlign: TextAlign.center))) else ..._setores.map(_cardSetor),
    ]));
  }

  Widget _chipStatus(EventoLote lote) {
    final ativo = (lote.statuslote ?? 'ATIVO').toUpperCase() == 'ATIVO';
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: ativo ? ClubbarColors.sucessoClaro : ClubbarColors.erroClaro, borderRadius: BorderRadius.circular(18)), child: Text(ativo ? 'Ativo' : 'Inativo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ativo ? ClubbarColors.sucesso : ClubbarColors.erro)));
  }
  Widget _cardLote(EventoLote lote) {
    final inteira = lote.precos.where((preco) => preco.tipo == 'INTEIRA').firstOrNull;
    final disponiveis = lote.usarCapacidadeRestante ? lote.qtCapacidadeRestante ?? 0 : (lote.qttotallote - lote.qtvendidalote - lote.qtReservadaLote).clamp(0, lote.qttotallote);
    return ClubbarCard(margin: const EdgeInsets.only(bottom: 12), onTap: () => _editarLote(lote), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: ClubbarColors.ambarClaro, shape: BoxShape.circle), child: Text('${lote.numeroLote}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(lote.nmlote, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), Text('Inteira: ${_moeda.format(inteira?.valor ?? lote.vrprecolote)} • $disponiveis disponíveis', style: const TextStyle(color: ClubbarColors.textoSecundario))])), _chipStatus(lote)]),
      const SizedBox(height: 14), Container(width: double.infinity, padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: ClubbarColors.fundo, borderRadius: BorderRadius.circular(12), border: Border.all(color: ClubbarColors.borda)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Início das vendas: ${_formatarData(lote.dtiniciovenda)}', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text('Fim das vendas: ${_formatarData(lote.dtfimvenda)}', style: const TextStyle(fontWeight: FontWeight.w800))])),
      const SizedBox(height: 12), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => _editarLote(lote), icon: const Icon(Icons.edit_rounded), label: const Text('Editar'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: _excluindo ? null : () => _excluirLote(lote), icon: const Icon(Icons.delete_outline_rounded), label: const Text('Excluir'), style: OutlinedButton.styleFrom(foregroundColor: ClubbarColors.erro)))]),
    ]));
  }

  Widget _paginaLotesDoSetor(EventoSetor setor) {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_erro != null) return _erroWidget();
    final busca = _buscaController.text.trim().toLowerCase();
    final lotes = _lotesDoSetor(setor.id).where((lote) => busca.isEmpty || lote.nmlote.toLowerCase().contains(busca)).toList();
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      bottomNavigationBar: ClubbarActionBar(actions: [ClubbarAddButton(onPressed: () => _novoLote(setor), label: 'Adicionar lote')]),
      body: SafeArea(child: Column(children: [
        ClubbarPageHeader(titulo: setor.nome, tituloWidget: Text(setor.nome, style: const TextStyle(color: ClubbarColors.info, fontSize: 20, fontWeight: FontWeight.w900)), subtitulo: 'Setor • capacidade máxima: ${setor.capacidade} pessoas', trailing: IconButton(onPressed: _carregar, icon: const Icon(Icons.refresh_rounded))),
        Expanded(child: RefreshIndicator(onRefresh: _carregar, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(20, 16, 20, 90), children: [
          TextField(controller: _buscaController, onChanged: (_) => setState(() {}), decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'Buscar lote', filled: true, fillColor: ClubbarColors.branco, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
          const SizedBox(height: 16),
          if (lotes.isEmpty) ClubbarCard(child: const Padding(padding: EdgeInsets.all(18), child: Text('Nenhum lote programado neste setor.', textAlign: TextAlign.center))) else ...lotes.map(_cardLote),
        ]))),
      ])),
    );
  }
  Widget _erroWidget() => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_erro!, textAlign: TextAlign.center), const SizedBox(height: 12), ElevatedButton.icon(onPressed: _carregar, icon: const Icon(Icons.refresh_rounded), label: const Text('Tentar novamente'))])));

  @override
  Widget build(BuildContext context) {
    if (widget.setorParaGerenciar != null) {
      return _paginaLotesDoSetor(widget.setorParaGerenciar!);
    }
    return DefaultTabController(initialIndex: _abaAtual, length: 2, child: Scaffold(
    backgroundColor: ClubbarColors.fundo, appBar: const ClubbarAppBar(mostrarVoltar: true),
    bottomNavigationBar: _abaAtual == 1 ? ClubbarActionBar(actions: [ClubbarAddButton(onPressed: _novoSetor, label: 'Adicionar setor')]) : null,
    body: SafeArea(child: Column(children: [
      ClubbarPageHeader(titulo: widget.eventoTitulo, tituloWidget: Text(widget.eventoTitulo, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClubbarColors.info, fontSize: 20, fontWeight: FontWeight.w900)), subtitulo: 'Data e hora do evento: $_dataHoraEvento', trailing: IconButton(onPressed: _carregando ? null : _carregar, icon: const Icon(Icons.refresh_rounded))),
      Material(color: ClubbarColors.branco, child: TabBar(onTap: (indice) => setState(() => _abaAtual = indice), labelColor: ClubbarColors.info, unselectedLabelColor: ClubbarColors.textoSecundario, tabs: const [Tab(text: 'Resumo'), Tab(text: 'Setores')])),
      Expanded(child: TabBarView(children: [_abaResumo(), _abaSetores()])),
    ])),
  ));
  }
}
