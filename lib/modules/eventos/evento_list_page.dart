import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/evento_repository.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/evento.dart';
import '../../models/loja.dart';
import 'evento_form_page.dart';
import 'evento_lote_list_page.dart';

class EventoListPage extends StatefulWidget {
  final int organizacaoId;

  const EventoListPage({
    super.key,
    required this.organizacaoId,
  });

  @override
  State<EventoListPage> createState() => _EventoListPageState();
}

class _EventoListPageState extends State<EventoListPage> {
  final EventoRepository _repository = EventoRepository();
  final LojaRepository _lojaRepository = LojaRepository();
  final TextEditingController _buscaController = TextEditingController();

  final DateFormat _formatoData = DateFormat('dd/MM/yyyy HH:mm');

  bool _carregando = true;
  bool _carregandoLojas = true;
  bool _excluindo = false;
  String? _erro;

  List<Evento> _eventos = [];
  List<Evento> _eventosFiltrados = [];
  List<Loja> _lojas = [];
  int? _lojaIdSelecionada;

  @override
  void initState() {
    super.initState();
    _carregarLojas();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  String _extrairMensagemErro(Object erro) {
    final texto = erro.toString();

    try {
      final inicio = texto.indexOf('{');
      final fim = texto.lastIndexOf('}');

      if (inicio != -1 && fim != -1 && fim > inicio) {
        final decoded = jsonDecode(texto.substring(inicio, fim + 1));
        if (decoded is Map && decoded['detail'] != null) {
          return decoded['detail'].toString();
        }
      }
    } catch (_) {}

    final mensagem = texto
        .replaceFirst('Exception: ', '')
        .replaceFirst('Exception:', '')
        .trim();

    return mensagem.isEmpty ? 'Ocorreu um erro inesperado.' : mensagem;
  }

  String _nomeLojaSelecionada() {
    final lojaId = _lojaIdSelecionada;
    if (lojaId == null) return '';

    for (final loja in _lojas) {
      if (loja.lojaId == lojaId) return loja.nmloja;
    }
    return '';
  }

  String _formatarData(String? valor) {
    if (valor == null || valor.trim().isEmpty) return 'Não informada';
    try {
      return _formatoData.format(DateTime.parse(valor));
    } catch (_) {
      return valor;
    }
  }

  String _montarUrlBanner(Evento evento) {
    final caminho = (evento.urlbannerevento ?? '').trim();
    if (caminho.isEmpty) return '';
    if (caminho.startsWith('http://') || caminho.startsWith('https://')) {
      return caminho;
    }
    return caminho.startsWith('/')
        ? '${ApiConfig.baseUrl}$caminho'
        : '${ApiConfig.baseUrl}/$caminho';
  }

  Future<void> _carregarLojas() async {
    setState(() {
      _carregandoLojas = true;
      _carregando = true;
      _erro = null;
    });

    try {
      final lojas = await _lojaRepository.listar(widget.organizacaoId);
      if (!mounted) return;

      int? selecionada = _lojaIdSelecionada;
      if (lojas.isNotEmpty) {
        if (!lojas.any((loja) => loja.lojaId == selecionada)) {
          selecionada = lojas.first.lojaId;
        }
      } else {
        selecionada = null;
      }

      setState(() {
        _lojas = lojas;
        _lojaIdSelecionada = selecionada;
        _carregandoLojas = false;
      });

      if (_lojaIdSelecionada != null) {
        await _carregarEventos();
      } else {
        setState(() {
          _eventos = [];
          _eventosFiltrados = [];
          _carregando = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final mensagem = _extrairMensagemErro(e);
      setState(() {
        _carregandoLojas = false;
        _carregando = false;
        _erro = mensagem;
      });
      AppSnackBar.erro(context, mensagem);
    }
  }

  Future<void> _carregarEventos() async {
    final lojaId = _lojaIdSelecionada;
    if (lojaId == null) {
      setState(() {
        _eventos = [];
        _eventosFiltrados = [];
        _carregando = false;
      });
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final lista = await _repository.listar(lojaId);
      if (!mounted) return;
      setState(() {
        _eventos = lista;
        _eventosFiltrados = _aplicarFiltro(lista, _buscaController.text);
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      final mensagem = _extrairMensagemErro(e);
      setState(() {
        _carregando = false;
        _erro = mensagem;
      });
      AppSnackBar.erro(context, mensagem);
    }
  }

  List<Evento> _aplicarFiltro(List<Evento> eventos, String texto) {
    final busca = texto.trim().toLowerCase();
    if (busca.isEmpty) return List<Evento>.from(eventos);

    return eventos.where((evento) {
      return evento.eventoId.toString().contains(busca) ||
          evento.nmtituloevento.toLowerCase().contains(busca) ||
          (evento.statusevento ?? '').toLowerCase().contains(busca) ||
          (evento.nmlocalevento ?? '').toLowerCase().contains(busca) ||
          (evento.dsendlocevento ?? '').toLowerCase().contains(busca);
    }).toList();
  }

  void _filtrar(String texto) {
    setState(() {
      _eventosFiltrados = _aplicarFiltro(_eventos, texto);
    });
  }

  void _limparBusca() {
    _buscaController.clear();
    _filtrar('');
    FocusScope.of(context).unfocus();
  }

  Future<void> _abrirNovoEvento() async {
    final lojaId = _lojaIdSelecionada;
    if (lojaId == null) {
      AppSnackBar.aviso(context, 'Selecione uma loja.');
      return;
    }

    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventoFormPage(
          organizacaoId: widget.organizacaoId,
          lojaId: lojaId,
        ),
      ),
    );

    if (resultado == true) await _carregarEventos();
  }

  Future<void> _abrirEdicao(Evento evento) async {
    final lojaId = _lojaIdSelecionada;
    if (lojaId == null) return;

    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventoFormPage(
          organizacaoId: widget.organizacaoId,
          lojaId: lojaId,
          evento: evento,
        ),
      ),
    );

    if (resultado == true) await _carregarEventos();
  }

  Future<void> _abrirLotes(Evento evento) async {
    final lojaId = _lojaIdSelecionada;
    if (lojaId == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventoLoteListPage(
          eventoId: evento.eventoId,
          eventoTitulo: evento.nmtituloevento,
          organizacaoId: widget.organizacaoId,
          lojaId: lojaId,
        ),
      ),
    );

    await _carregarEventos();
  }

  Future<bool> _confirmarExclusao(Evento evento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: ClubbarColors.fundo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
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
                  'Excluir evento',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: Text(
            'Deseja realmente excluir o evento "${evento.nmtituloevento}"?\n\n'
            'Os lotes vinculados podem impedir a exclusão.',
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
              style: OutlinedButton.styleFrom(
                foregroundColor: ClubbarColors.textoPrincipal,
                side: const BorderSide(color: ClubbarColors.borda),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        );
      },
    );

    return confirmar == true;
  }

  Future<void> _excluirEvento(Evento evento) async {
    if (_excluindo) return;
    if (!await _confirmarExclusao(evento)) return;

    setState(() => _excluindo = true);

    try {
      await _repository.excluir(evento.eventoId);
      if (!mounted) return;
      AppSnackBar.sucesso(context, 'Evento excluído com sucesso.');
      await _carregarEventos();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.erro(context, _extrairMensagemErro(e));
    } finally {
      if (mounted) setState(() => _excluindo = false);
    }
  }

  Widget _campoLoja() {
    if (_carregandoLojas) {
      return const SizedBox(
        height: 56,
        child: Center(
          child: CircularProgressIndicator(color: ClubbarColors.ambar),
        ),
      );
    }

    return DropdownButtonFormField<int>(
      initialValue: _lojaIdSelecionada,
      isExpanded: true,
      decoration: _decoracaoFiltro(
        label: 'Loja',
        icone: Icons.storefront_rounded,
      ),
      items: _lojas.map((loja) {
        return DropdownMenuItem<int>(
          value: loja.lojaId,
          child: Text(loja.nmloja, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (value) async {
        setState(() => _lojaIdSelecionada = value);
        await _carregarEventos();
      },
    );
  }

  InputDecoration _decoracaoFiltro({
    required String label,
    required IconData icone,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icone, color: ClubbarColors.textoSecundario),
      filled: true,
      fillColor: ClubbarColors.branco,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ClubbarColors.borda),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ClubbarColors.borda),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: ClubbarColors.ambar,
          width: 2,
        ),
      ),
    );
  }

  Widget _campoBusca() {
    return TextField(
      controller: _buscaController,
      onChanged: _filtrar,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar evento',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: ClubbarColors.textoSecundario,
        ),
        suffixIcon: _buscaController.text.isNotEmpty
            ? IconButton(
                onPressed: _limparBusca,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        filled: true,
        fillColor: ClubbarColors.branco,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ClubbarColors.borda),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ClubbarColors.borda),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: ClubbarColors.ambar,
            width: 2,
          ),
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
              onPressed: _lojaIdSelecionada == null ? null : _abrirNovoEvento,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Novo evento',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ClubbarColors.ambar,
                foregroundColor: ClubbarColors.preto,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 50,
          height: 50,
          child: OutlinedButton(
            onPressed: _carregando ? null : _carregarEventos,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: ClubbarColors.textoPrincipal,
              side: const BorderSide(color: ClubbarColors.borda),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
    );
  }

  Widget _bannerEvento(Evento evento) {
    final url = _montarUrlBanner(evento);

    Widget placeholder() {
      return Container(
        color: ClubbarColors.ambarClaro,
        alignment: Alignment.center,
        child: const Icon(
          Icons.event_rounded,
          size: 54,
          color: ClubbarColors.preto,
        ),
      );
    }

    if (url.isEmpty) return placeholder();

    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 180,
      errorBuilder: (_, _, _) => placeholder(),
    );
  }

  Widget _chipStatus(Evento evento) {
    final status = (evento.statusevento ?? 'ATIVO').trim().toUpperCase();
    final ativo = status == 'ATIVO' || status == 'ATIVA';

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

  Widget _linhaInformacao({
    required IconData icone,
    required String texto,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: ClubbarColors.textoSecundario),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: ClubbarColors.textoSecundario,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardEvento(Evento evento) {
    final local = (evento.nmlocalevento ?? '').trim();
    final endereco = (evento.dsendlocevento ?? '').trim();

    return ClubbarCard(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      padding: EdgeInsets.zero,
      onTap: () => _abrirLotes(evento),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
            child: SizedBox(
              width: double.infinity,
              height: 180,
              child: _bannerEvento(evento),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        evento.nmtituloevento,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: ClubbarColors.textoPrincipal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _chipStatus(evento),
                  ],
                ),
                _linhaInformacao(
                  icone: Icons.calendar_month_outlined,
                  texto: _formatarData(evento.dtinicioevento),
                ),
                if (local.isNotEmpty)
                  _linhaInformacao(
                    icone: Icons.location_on_outlined,
                    texto: local,
                  ),
                if (endereco.isNotEmpty)
                  _linhaInformacao(
                    icone: Icons.map_outlined,
                    texto: endereco,
                  ),
                const SizedBox(height: 15),
                const Divider(height: 1, color: ClubbarColors.divisor),
                const SizedBox(height: 11),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _abrirLotes(evento),
                    icon: const Icon(Icons.confirmation_number_rounded),
                    label: const Text(
                      'Gerenciar lotes e preços',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ClubbarColors.ambar,
                      foregroundColor: ClubbarColors.preto,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _excluindo ? null : () => _abrirEdicao(evento),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text(
                          'Editar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ClubbarColors.textoPrincipal,
                          side: const BorderSide(color: ClubbarColors.borda),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _excluindo ? null : () => _excluirEvento(evento),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text(
                          'Excluir',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ClubbarColors.erroClaro,
                          foregroundColor: ClubbarColors.erro,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoVazio() {
    final temBusca = _buscaController.text.trim().isNotEmpty;
    final temLoja = _lojaIdSelecionada != null;

    return ClubbarCard(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 34),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: ClubbarColors.ambarClaro,
                shape: BoxShape.circle,
              ),
              child: Icon(
                !temLoja
                    ? Icons.storefront_rounded
                    : temBusca
                        ? Icons.search_off_rounded
                        : Icons.event_rounded,
                size: 39,
                color: ClubbarColors.preto,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              !temLoja
                  ? 'Nenhuma loja disponível'
                  : temBusca
                      ? 'Nenhum evento encontrado'
                      : 'Nenhum evento cadastrado',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              !temLoja
                  ? 'Cadastre uma loja antes de criar eventos.'
                  : temBusca
                      ? 'Tente pesquisar por outro título, local ou situação.'
                      : 'Cadastre o primeiro evento desta loja.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: ClubbarColors.textoSecundario,
              ),
            ),
            if (temLoja && !temBusca) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _abrirNovoEvento,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Cadastrar evento',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ClubbarColors.ambar,
                  foregroundColor: ClubbarColors.preto,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _estadoErro() {
    return ClubbarCard(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 62,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            const Text(
              'Não foi possível carregar os eventos',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              _erro ?? 'Tente novamente em instantes.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                height: 1.4,
                color: ClubbarColors.textoSecundario,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _carregarEventos,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'Tentar novamente',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ClubbarColors.ambar,
                foregroundColor: ClubbarColors.preto,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conteudoLista() {
    if (_carregando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: CircularProgressIndicator(color: ClubbarColors.ambar),
        ),
      );
    }
    if (_erro != null) return _estadoErro();
    if (_eventosFiltrados.isEmpty) return _estadoVazio();
    return Column(children: _eventosFiltrados.map(_cardEvento).toList());
  }

  @override
  Widget build(BuildContext context) {
    final nomeLoja = _nomeLojaSelecionada();

    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: 'Eventos',
              subtitulo: _carregando
                  ? 'Carregando eventos...'
                  : nomeLoja.isEmpty
                      ? 'Selecione uma loja'
                      : '$nomeLoja • ${_eventos.length} '
                          '${_eventos.length == 1 ? 'evento' : 'eventos'}',
              icone: Icons.event_rounded,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                children: [
                  _campoLoja(),
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
                onRefresh: _carregarEventos,
                color: ClubbarColors.ambar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
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
