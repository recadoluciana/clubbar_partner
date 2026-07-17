import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/evento_lote_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
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

  const EventoLoteListPage({
    super.key,
    required this.eventoId,
    required this.eventoTitulo,
    required this.organizacaoId,
    required this.lojaId,
  });

  @override
  State<EventoLoteListPage> createState() => _EventoLoteListPageState();
}

class _EventoLoteListPageState extends State<EventoLoteListPage> {
  final EventoLoteRepository _repo = EventoLoteRepository();
  final TextEditingController _buscaController = TextEditingController();
  final NumberFormat _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  bool _carregando = true;
  bool _excluindo = false;
  String? _erro;
  List<EventoLote> _lotes = [];
  List<EventoLote> _lotesFiltrados = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  String _mensagemErro(Object erro) {
    final texto = erro.toString().replaceFirst('Exception: ', '').trim();
    return texto.isEmpty ? 'Ocorreu um erro inesperado.' : texto;
  }

  int get _totalIngressos => _lotes.fold(0, (total, lote) => total + lote.qttotallote);
  int get _totalVendidos => _lotes.fold(0, (total, lote) => total + lote.qtvendidalote);
  int get _totalDisponiveis => (_totalIngressos - _totalVendidos).clamp(0, _totalIngressos);

  double get _menorPreco {
    if (_lotes.isEmpty) return 0;
    final precos = _lotes.map((lote) => lote.vrprecolote).toList()..sort();
    return precos.first;
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final lista = await _repo.listar(widget.eventoId);
      if (!mounted) return;
      setState(() {
        _lotes = lista;
        _lotesFiltrados = _aplicarFiltro(lista, _buscaController.text);
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      final mensagem = _mensagemErro(e);
      setState(() {
        _carregando = false;
        _erro = mensagem;
      });
      AppSnackBar.erro(context, mensagem);
    }
  }

  List<EventoLote> _aplicarFiltro(List<EventoLote> lotes, String texto) {
    final busca = texto.trim().toLowerCase();
    if (busca.isEmpty) return List<EventoLote>.from(lotes);

    return lotes.where((lote) {
      return lote.loteId.toString().contains(busca) ||
          lote.nmlote.toLowerCase().contains(busca) ||
          lote.vrprecolote.toString().contains(busca) ||
          lote.qttotallote.toString().contains(busca) ||
          lote.qtvendidalote.toString().contains(busca) ||
          (lote.statuslote ?? '').toLowerCase().contains(busca);
    }).toList();
  }

  void _filtrar(String texto) {
    setState(() {
      _lotesFiltrados = _aplicarFiltro(_lotes, texto);
    });
  }

  void _limparBusca() {
    _buscaController.clear();
    _filtrar('');
    FocusScope.of(context).unfocus();
  }

  String _formatarData(String? valor) {
    if (valor == null || valor.trim().isEmpty) return 'Não informada';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(valor));
    } catch (_) {
      return valor;
    }
  }

  Future<void> _novoLote() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventoLoteFormPage(
          eventoId: widget.eventoId,
          organizacaoId: widget.organizacaoId,
          lojaId: widget.lojaId,
        ),
      ),
    );
    if (resultado == true) await _carregar();
  }

  Future<void> _editarLote(EventoLote lote) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventoLoteFormPage(
          eventoId: widget.eventoId,
          organizacaoId: widget.organizacaoId,
          lojaId: widget.lojaId,
          lote: lote,
        ),
      ),
    );
    if (resultado == true) await _carregar();
  }

  Future<void> _excluirLote(EventoLote lote) async {
    if (_excluindo) return;

    final confirmou = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ClubbarColors.fundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: ClubbarColors.erro, size: 30),
            SizedBox(width: 10),
            Expanded(child: Text('Excluir lote', style: TextStyle(fontWeight: FontWeight.w900))),
          ],
        ),
        content: Text(
          'Deseja realmente excluir o lote "${lote.nmlote}"?\n\n'
          'A exclusão poderá ser bloqueada se já houver ingressos vendidos.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, false),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_rounded),
            label: const Text('Excluir', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: ClubbarColors.erro,
              foregroundColor: ClubbarColors.branco,
            ),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    setState(() => _excluindo = true);
    try {
      await _repo.excluir(lote.loteId);
      if (!mounted) return;
      AppSnackBar.sucesso(context, 'Lote excluído com sucesso.');
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.erro(context, _mensagemErro(e));
    } finally {
      if (mounted) setState(() => _excluindo = false);
    }
  }

  Widget _campoBusca() {
    return TextField(
      controller: _buscaController,
      onChanged: _filtrar,
      decoration: InputDecoration(
        hintText: 'Buscar lote',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _buscaController.text.isNotEmpty
            ? IconButton(onPressed: _limparBusca, icon: const Icon(Icons.close_rounded))
            : null,
        filled: true,
        fillColor: ClubbarColors.branco,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ClubbarColors.ambar, width: 2),
        ),
      ),
    );
  }

  Widget _acoesTopo() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _novoLote,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Novo lote', style: TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ClubbarColors.ambar,
                foregroundColor: ClubbarColors.preto,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 50,
          height: 50,
          child: OutlinedButton(
            onPressed: _carregando ? null : _carregar,
            child: const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
    );
  }

  Widget _itemResumo(String titulo, String valor, IconData icone) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ClubbarColors.branco,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ClubbarColors.borda),
      ),
      child: Row(
        children: [
          Icon(icone, size: 21, color: ClubbarColors.ambarEscuro),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 11, color: ClubbarColors.textoSecundario)),
                Text(valor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardResumo() {
    return ClubbarCard(
      elevation: 1,
      backgroundColor: ClubbarColors.avisoClaro,
      borderColor: ClubbarColors.ambar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.eventoTitulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _itemResumo('Lotes', '${_lotes.length}', Icons.confirmation_number_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _itemResumo('Ingressos', '$_totalIngressos', Icons.groups_rounded)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _itemResumo('Vendidos', '$_totalVendidos', Icons.check_circle_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _itemResumo('Disponíveis', '$_totalDisponiveis', Icons.inventory_2_rounded)),
            ],
          ),
          if (_lotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: _itemResumo('A partir de', _moeda.format(_menorPreco), Icons.sell_rounded),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chipStatus(EventoLote lote) {
    final ativo = (lote.statuslote ?? 'ATIVO').toUpperCase() == 'ATIVO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ativo ? ClubbarColors.sucessoClaro : ClubbarColors.erroClaro,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        ativo ? 'Ativo' : 'Inativo',
        style: TextStyle(
          color: ativo ? ClubbarColors.sucesso : ClubbarColors.erro,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _cardLote(EventoLote lote) {
    final disponiveis = (lote.qttotallote - lote.qtvendidalote).clamp(0, lote.qttotallote);

    return ClubbarCard(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      onTap: () => _editarLote(lote),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(color: ClubbarColors.ambarClaro, shape: BoxShape.circle),
                child: const Icon(Icons.confirmation_number_rounded, size: 30),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lote.nmlote, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(
                      _moeda.format(lote.vrprecolote),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ClubbarColors.sucesso),
                    ),
                  ],
                ),
              ),
              _chipStatus(lote),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.groups_outlined, size: 18, color: ClubbarColors.textoSecundario),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${lote.qttotallote} ingressos • ${lote.qtvendidalote} vendidos • $disponiveis disponíveis',
                  style: const TextStyle(fontSize: 13, color: ClubbarColors.textoSecundario),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.calendar_month_outlined, size: 18, color: ClubbarColors.textoSecundario),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Vendas: ${_formatarData(lote.dtiniciovenda)} até ${_formatarData(lote.dtfimvenda)}',
                  style: const TextStyle(fontSize: 13, color: ClubbarColors.textoSecundario),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _excluindo ? null : () => _editarLote(lote),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Editar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _excluindo ? null : () => _excluirLote(lote),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Excluir', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ClubbarColors.erroClaro,
                    foregroundColor: ClubbarColors.erro,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _conteudoLista() {
    if (_carregando) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: ClubbarColors.ambar)),
      );
    }

    if (_erro != null) {
      return ClubbarCard(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56),
            const SizedBox(height: 12),
            Text(_erro!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _carregar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_lotesFiltrados.isEmpty) {
      return ClubbarCard(
        child: Column(
          children: [
            const Icon(Icons.confirmation_number_rounded, size: 56),
            const SizedBox(height: 12),
            Text(
              _buscaController.text.trim().isEmpty
                  ? 'Nenhum lote cadastrado.'
                  : 'Nenhum lote encontrado.',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            if (_buscaController.text.trim().isEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _novoLote,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Cadastrar lote'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(children: _lotesFiltrados.map(_cardLote).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: 'Lotes do Evento',
              subtitulo: widget.eventoTitulo,
              icone: Icons.confirmation_number_rounded,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                children: [
                  _cardResumo(),
                  const SizedBox(height: 12),
                  _campoBusca(),
                  const SizedBox(height: 12),
                  _acoesTopo(),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _carregar,
                color: ClubbarColors.ambar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  children: [_conteudoLista()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
