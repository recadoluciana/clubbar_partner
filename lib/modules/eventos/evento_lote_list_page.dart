import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/evento_lote_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_action_bar.dart';
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

  const EventoLoteListPage({
    super.key,
    required this.eventoId,
    required this.eventoTitulo,
    required this.organizacaoId,
    required this.lojaId,
    this.eventoInicio,
  });

  @override
  State<EventoLoteListPage> createState() => _EventoLoteListPageState();
}

class _EventoLoteListPageState extends State<EventoLoteListPage> {
  final EventoLoteRepository _repo = EventoLoteRepository();
  final TextEditingController _buscaController = TextEditingController();
  final NumberFormat _moeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  bool _carregando = true;
  bool _excluindo = false;
  String? _erro;
  List<EventoLote> _lotes = [];
  List<EventoLote> _lotesFiltrados = [];
  List<EventoSetor> _setores = [];

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

  int get _totalIngressos {
    return _setores.fold(0, (soma, setor) => soma + setor.capacidade);
  }

  int get _totalVendidos =>
      _lotes.fold(0, (total, lote) => total + lote.qtvendidalote);
  int get _totalDisponiveis {
    return (_totalIngressos -
            _totalVendidos -
            _lotes.fold(0, (total, lote) => total + lote.qtReservadaLote))
        .clamp(0, _totalIngressos)
        .toInt();
  }

  int get _cotaLegal => _lotes.isEmpty ? (_totalIngressos * .40).floor() : _lotes.first.cotaLegal;
  int get _cotaLegalUsada => _lotes.isEmpty ? 0 : _lotes.first.quantidadeVendidaCotaLegal + _lotes.first.quantidadeReservadaCotaLegal;

  double get _menorPreco {
    if (_lotes.isEmpty) return 0;
    final precos = _lotes
        .expand(
          (lote) => lote.precos
              .where((preco) => preco.situacao == 'ATIVO')
              .map((preco) => preco.valor),
        )
        .toList();
    if (precos.isEmpty) {
      precos.addAll(_lotes.map((lote) => lote.vrprecolote));
    }
    precos.sort();
    return precos.first;
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final respostas = await Future.wait([
        _repo.listar(widget.eventoId),
        _repo.listarSetores(widget.eventoId),
      ]);
      final lista = respostas[0] as List<EventoLote>;
      final setores = respostas[1] as List<EventoSetor>;
      if (!mounted) return;
      setState(() {
        _lotes = lista;
        _setores = setores;
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

  String get _dataHoraEvento {
    final inicio = DateTime.tryParse(widget.eventoInicio ?? '');
    if (inicio == null) return 'Data e hora não informadas';
    return '${DateFormat('dd/MM/yyyy').format(inicio)} às ${DateFormat('HH:mm').format(inicio)}';
  }

  Future<void> _novoLote() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventoLoteFormPage(
          eventoId: widget.eventoId,
          organizacaoId: widget.organizacaoId,
          lojaId: widget.lojaId,
          eventoInicio: widget.eventoInicio,
        ),
      ),
    );
    if (resultado == true) await _carregar();
  }

  Future<void> _novoSetor() async {
    final nome = TextEditingController();
    final capacidade = TextEditingController();
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Novo setor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nome, decoration: const InputDecoration(labelText: 'Nome do setor')),
            const SizedBox(height: 12),
            TextField(
              controller: capacidade,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacidade total'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Criar setor')),
        ],
      ),
    );
    if (confirmou == true) {
      try {
        await _repo.criarSetor(
          eventoId: widget.eventoId,
          nome: nome.text.trim(),
          capacidade: int.tryParse(capacidade.text.trim()) ?? 0,
        );
        if (!mounted) return;
        AppSnackBar.sucesso(context, 'Setor criado. Agora cadastre os lotes dele.');
        await _carregar();
      } catch (e) {
        if (mounted) AppSnackBar.erro(context, _mensagemErro(e));
      }
    }
    nome.dispose();
    capacidade.dispose();
  }

  Future<void> _editarLote(EventoLote lote) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventoLoteFormPage(
          eventoId: widget.eventoId,
          organizacaoId: widget.organizacaoId,
          lojaId: widget.lojaId,
          eventoInicio: widget.eventoInicio,
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
            Icon(
              Icons.warning_amber_rounded,
              color: ClubbarColors.erro,
              size: 30,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Excluir lote',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
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
            label: const Text(
              'Cancelar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_rounded),
            label: const Text(
              'Excluir',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
            ? IconButton(
                onPressed: _limparBusca,
                icon: const Icon(Icons.close_rounded),
              )
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

  Widget _botaoCircularHeader({
    required String tooltip,
    required IconData icone,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 40,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icone, size: 22),
          color: ClubbarColors.preto,
          disabledColor: ClubbarColors.textoSecundario,
          style: IconButton.styleFrom(
            backgroundColor: ClubbarColors.ambar,
            disabledBackgroundColor: ClubbarColors.borda,
            shape: const CircleBorder(),
          ),
        ),
      ),
    );
  }

  Widget _acoesHeader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _botaoCircularHeader(
          tooltip: 'Atualizar',
          icone: Icons.refresh_rounded,
          onPressed: _carregando ? null : _carregar,
        ),
      ],
    );
  }

  Widget _itemResumo(String titulo, String valor, IconData icone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: ClubbarColors.branco,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ClubbarColors.borda),
      ),
      child: Row(
        children: [
          Icon(icone, size: 18, color: ClubbarColors.ambarEscuro),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 10,
                    color: ClubbarColors.textoSecundario,
                  ),
                ),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
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
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final colunas = constraints.maxWidth >= 390 ? 3 : 2;
          final largura = (constraints.maxWidth - (colunas - 1) * 8) / colunas;
          final itens = [
            ('Lotes', '${_lotes.length}', Icons.confirmation_number_rounded),
            ('Ingressos', '$_totalIngressos', Icons.groups_rounded),
            ('Vendidos', '$_totalVendidos', Icons.check_circle_rounded),
            ('Disponíveis', '$_totalDisponiveis', Icons.inventory_2_rounded),
            (
              'A partir de',
              _lotes.isEmpty ? '—' : _moeda.format(_menorPreco),
              Icons.sell_rounded,
            ),
          ];
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in itens)
                SizedBox(
                  width: largura,
                  child: _itemResumo(item.$1, item.$2, item.$3),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _cardRegras() {
    final restante = (_cotaLegal - _cotaLegalUsada).clamp(0, _cotaLegal);
    return ClubbarCard(
      backgroundColor: ClubbarColors.infoClaro,
      borderColor: ClubbarColors.info,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gavel_rounded, color: ClubbarColors.info),
              SizedBox(width: 8),
              Expanded(
                child: Text('Regras de venda e meia-entrada', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Capacidade do evento: $_totalIngressos • cota legal: $_cotaLegal • disponível na cota: $restante',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cada lote oferece Inteira, Meia-entrada e Pessoa idosa. A meia legal conta na cota de 40% do evento; pessoa idosa tem 50% de desconto e não consome essa cota. A comprovação é exigida na entrada.',
            style: TextStyle(fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crie os setores primeiro. Em cada setor, os lotes seguem a numeração: o próximo entra em venda quando o anterior esgota ou encerra, respeitando sempre seu horário de início.',
            style: TextStyle(fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _botaoNovoSetor() {
    return OutlinedButton.icon(
      onPressed: _carregando ? null : _novoSetor,
      icon: const Icon(Icons.add_business_rounded),
      label: const Text('Adicionar setor'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
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
    final disponiveis =
        (lote.qttotallote - lote.qtvendidalote - lote.qtReservadaLote).clamp(
          0,
          lote.qttotallote,
        );

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
                decoration: const BoxDecoration(
                  color: ClubbarColors.ambarClaro,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.confirmation_number_rounded, size: 30),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lote.nmlote,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${lote.precos.where((preco) => preco.situacao == 'ATIVO').length} modalidades de preço',
                      style: const TextStyle(
                        fontSize: 13,
                        color: ClubbarColors.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
              _chipStatus(lote),
            ],
          ),
          const SizedBox(height: 12),
          ..._precosVisiveis(lote).map(_linhaPreco),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.groups_outlined,
                size: 18,
                color: ClubbarColors.textoSecundario,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  lote.usarCapacidadeRestante
                      ? 'Capacidade restante: ${lote.qtCapacidadeRestante?.toString() ?? '—'} disponíveis • ${lote.qtvendidalote} vendidos neste lote'
                      : '${lote.qttotallote} ingressos • ${lote.qtvendidalote} vendidos • $disponiveis disponíveis',
                  style: const TextStyle(
                    fontSize: 13,
                    color: ClubbarColors.textoSecundario,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 18,
                color: ClubbarColors.textoSecundario,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Vendas: ${_formatarData(lote.dtiniciovenda)} até ${_formatarData(lote.dtfimvenda)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: ClubbarColors.textoSecundario,
                  ),
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
                  label: const Text(
                    'Editar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _excluindo ? null : () => _excluirLote(lote),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text(
                    'Excluir',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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

  List<EventoLotePreco> _precosVisiveis(EventoLote lote) {
    final precos =
        lote.precos.where((preco) => preco.situacao == 'ATIVO').toList()
          ..sort((a, b) => a.ordem.compareTo(b.ordem));
    if (precos.isNotEmpty) return precos;
    return [
      EventoLotePreco(
        id: 0,
        nome: 'Inteira',
        tipo: 'INTEIRA',
        valor: lote.vrprecolote,
        aplicaCotaLegal: false,
        exigeComprovante: false,
      ),
    ];
  }

  String _nomeModalidade(EventoLotePreco preco) {
    switch (preco.tipo) {
      case 'INTEIRA':
        return 'Inteira';
      case 'MEIA_LEGAL':
        return 'Meia-entrada';
      case 'MEIA_IDOSO':
        return 'Pessoa idosa';
      default:
        return preco.nome.trim().isEmpty ? 'Ingresso' : preco.nome;
    }
  }

  Widget _linhaPreco(EventoLotePreco preco) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ClubbarColors.fundo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ClubbarColors.borda),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sell_outlined,
            size: 18,
            color: ClubbarColors.sucesso,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nomeModalidade(preco),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (preco.exigeComprovante)
                  const Text(
                    'Comprovante obrigatório',
                    style: TextStyle(
                      fontSize: 11,
                      color: ClubbarColors.textoSecundario,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _moeda.format(preco.valor),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: ClubbarColors.sucesso,
            ),
          ),
        ],
      ),
    );
  }

  Widget _conteudoLista() {
    if (_carregando) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(
          child: CircularProgressIndicator(color: ClubbarColors.ambar),
        ),
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

    final grupos = <int, List<EventoLote>>{};
    for (final lote in _lotesFiltrados) {
      (grupos[lote.eventoSetorId ?? -lote.loteId] ??= []).add(lote);
    }
    return Column(
      children: [
        for (final grupo in grupos.values) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
            child: Row(
              children: [
                const Icon(Icons.stadium_outlined, size: 19),
                const SizedBox(width: 7),
                Text(
                  grupo.first.nomeSetor?.isNotEmpty == true
                      ? grupo.first.nomeSetor!
                      : 'Ingressos sem setor',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          ...grupo.map(_cardLote),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      bottomNavigationBar: ClubbarActionBar(
        actions: [
          ClubbarAddButton(onPressed: _novoLote, label: 'Adicionar lote'),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: 'Ingressos e lotes',
              tituloWidget: Text(
                'Ingressos e lotes',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitulo: _dataHoraEvento,
              subtituloWidget: Text(
                _dataHoraEvento,
                style: const TextStyle(
                  color: ClubbarColors.info,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              trailing: _acoesHeader(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  _cardResumo(),
                  const SizedBox(height: 8),
                  _cardRegras(),
                  const SizedBox(height: 8),
                  _botaoNovoSetor(),
                  const SizedBox(height: 8),
                  _campoBusca(),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _carregar,
                color: ClubbarColors.ambar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
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
