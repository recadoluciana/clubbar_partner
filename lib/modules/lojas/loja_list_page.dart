import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';
import 'loja_form_page.dart';

class LojaListPage extends StatefulWidget {
  final int organizacaoId;

  const LojaListPage({super.key, required this.organizacaoId});

  @override
  State<LojaListPage> createState() => _LojaListPageState();
}

class _LojaListPageState extends State<LojaListPage> {
  final TextEditingController _buscaController = TextEditingController();
  final LojaRepository _repository = LojaRepository();

  bool _carregando = true;
  bool _excluindo = false;

  String? _erro;

  List<Loja> _lojas = [];
  List<Loja> _lojasFiltradas = [];

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
        final jsonTexto = texto.substring(inicio, fim + 1);
        final decoded = jsonDecode(jsonTexto);

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

  Future<void> _carregarLojas() async {
    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    try {
      final lista = await _repository.listar(widget.organizacaoId);

      if (!mounted) return;

      setState(() {
        _lojas = lista;
        _lojasFiltradas = _aplicarFiltro(lista, _buscaController.text);
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

  List<Loja> _aplicarFiltro(List<Loja> lojas, String texto) {
    final busca = texto.trim().toLowerCase();

    if (busca.isEmpty) {
      return List<Loja>.from(lojas);
    }

    return lojas.where((loja) {
      final nome = loja.nmloja.toLowerCase();
      final endereco = (loja.endloja ?? '').toLowerCase();
      final bairro = (loja.dsbairroloja ?? '').toLowerCase();
      final instagram = (loja.dsinstaloja ?? '').toLowerCase();
      final telefone = (loja.nrtelloja ?? '').toLowerCase();
      final horario = (loja.dshorarioloja ?? '').toLowerCase();
      final status = (loja.sitloja ?? '').toLowerCase();

      return loja.lojaId.toString().contains(busca) ||
          nome.contains(busca) ||
          endereco.contains(busca) ||
          bairro.contains(busca) ||
          instagram.contains(busca) ||
          telefone.contains(busca) ||
          horario.contains(busca) ||
          status.contains(busca);
    }).toList();
  }

  void _filtrar(String texto) {
    setState(() {
      _lojasFiltradas = _aplicarFiltro(_lojas, texto);
    });
  }

  void _limparBusca() {
    _buscaController.clear();
    _filtrar('');
    FocusScope.of(context).unfocus();
  }

  String _montarUrlLogo(Loja loja) {
    final caminho = (loja.urllogoloja ?? '').trim();

    if (caminho.isEmpty) {
      return '';
    }

    if (caminho.startsWith('http://') || caminho.startsWith('https://')) {
      return caminho;
    }

    return caminho.startsWith('/')
        ? '${ApiConfig.baseUrl}$caminho'
        : '${ApiConfig.baseUrl}/$caminho';
  }

  Future<void> _abrirNovaLoja() async {
    final resultado = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const LojaFormPage()));

    if (resultado == true) {
      await _carregarLojas();
    }
  }

  Future<void> _abrirEdicao(Loja loja) async {
    final resultado = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => LojaFormPage(loja: loja)));

    if (resultado == true) {
      await _carregarLojas();
    }
  }

  Future<bool> _confirmarExclusao(Loja loja) async {
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
                  'Excluir loja',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: Text(
            'Deseja realmente excluir a loja '
            '"${loja.nmloja}"?\n\n'
            'Essa ação não poderá ser desfeita.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
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
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
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

  Future<void> _excluirLoja(Loja loja) async {
    if (_excluindo) return;

    final confirmou = await _confirmarExclusao(loja);

    if (!confirmou) return;

    setState(() {
      _excluindo = true;
    });

    try {
      await _repository.excluir(loja.lojaId);

      if (!mounted) return;

      AppSnackBar.sucesso(context, 'Loja excluída com sucesso.');

      await _carregarLojas();
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, _extrairMensagemErro(e));
    } finally {
      if (mounted) {
        setState(() {
          _excluindo = false;
        });
      }
    }
  }

  Widget _logoLoja(Loja loja) {
    final url = _montarUrlLogo(loja);

    Widget placeholder() {
      return Container(
        color: ClubbarColors.ambarClaro,
        alignment: Alignment.center,
        child: const Icon(
          Icons.storefront_rounded,
          size: 34,
          color: ClubbarColors.preto,
        ),
      );
    }

    if (url.isEmpty) {
      return placeholder();
    }

    return Image.network(
      url,
      width: 70,
      height: 70,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        return placeholder();
      },
    );
  }

  Widget _chipStatus(Loja loja) {
    final status = (loja.sitloja ?? 'ATIVA').trim().toUpperCase();

    final ativa = status == 'ATIVA' || status == 'ATIVO';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ativa ? ClubbarColors.sucessoClaro : ClubbarColors.erroClaro,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        ativa ? 'Ativa' : 'Inativa',
        style: TextStyle(
          color: ativa ? ClubbarColors.sucesso : ClubbarColors.erro,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _linhaInformacao({required IconData icone, required String texto}) {
    if (texto.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 17, color: ClubbarColors.textoSecundario),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 13,
                color: ClubbarColors.textoSecundario,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardLoja(Loja loja) {
    final endereco = (loja.endloja ?? '').trim();
    final bairro = (loja.dsbairroloja ?? '').trim();
    final telefone = (loja.nrtelloja ?? '').trim();
    final horario = (loja.dshorarioloja ?? '').trim();
    final instagram = (loja.dsinstaloja ?? '').trim();

    final enderecoCompleto = [
      endereco,
      bairro,
    ].where((valor) => valor.isNotEmpty).join(' • ');

    return ClubbarCard(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      padding: const EdgeInsets.all(15),
      onTap: () => _abrirEdicao(loja),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(width: 70, height: 70, child: _logoLoja(loja)),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            loja.nmloja,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: ClubbarColors.textoPrincipal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _chipStatus(loja),
                      ],
                    ),

                    if (enderecoCompleto.isNotEmpty)
                      _linhaInformacao(
                        icone: Icons.location_on_outlined,
                        texto: enderecoCompleto,
                      ),

                    if (telefone.isNotEmpty)
                      _linhaInformacao(
                        icone: Icons.phone_outlined,
                        texto: telefone,
                      ),

                    if (horario.isNotEmpty)
                      _linhaInformacao(
                        icone: Icons.schedule_outlined,
                        texto: horario,
                      ),

                    if (instagram.isNotEmpty)
                      _linhaInformacao(
                        icone: Icons.alternate_email_rounded,
                        texto: instagram,
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Divider(height: 1, color: ClubbarColors.divisor),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _excluindo ? null : () => _abrirEdicao(loja),
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
                  onPressed: _excluindo ? null : () => _excluirLoja(loja),
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
    );
  }

  Widget _campoBusca() {
    return TextField(
      controller: _buscaController,
      onChanged: _filtrar,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar loja',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: ClubbarColors.textoSecundario,
        ),
        suffixIcon: _buscaController.text.isNotEmpty
            ? IconButton(
                tooltip: 'Limpar busca',
                onPressed: _limparBusca,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        filled: true,
        fillColor: ClubbarColors.branco,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
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
              onPressed: _abrirNovaLoja,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text(
                'Nova loja',
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
            onPressed: _carregando ? null : _carregarLojas,
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

  Widget _estadoVazio() {
    final temBusca = _buscaController.text.trim().isNotEmpty;

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
                temBusca ? Icons.search_off_rounded : Icons.storefront_rounded,
                size: 39,
                color: ClubbarColors.preto,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              temBusca ? 'Nenhuma loja encontrada' : 'Nenhuma loja cadastrada',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),

            const SizedBox(height: 7),

            Text(
              temBusca
                  ? 'Tente pesquisar usando outro nome, bairro ou endereço.'
                  : 'Cadastre a primeira loja da sua organização.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: ClubbarColors.textoSecundario,
                height: 1.4,
              ),
            ),

            if (!temBusca) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _abrirNovaLoja,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Cadastrar loja',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ClubbarColors.ambar,
                  foregroundColor: ClubbarColors.preto,
                  elevation: 0,
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
              'Não foi possível carregar as lojas',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),

            const SizedBox(height: 8),

            Text(
              _erro ?? 'Tente novamente em instantes.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ClubbarColors.textoSecundario,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 18),

            ElevatedButton.icon(
              onPressed: _carregarLojas,
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
          padding: EdgeInsets.only(top: 70),
          child: CircularProgressIndicator(color: ClubbarColors.ambar),
        ),
      );
    }

    if (_erro != null) {
      return _estadoErro();
    }

    if (_lojasFiltradas.isEmpty) {
      return _estadoVazio();
    }

    return Column(children: _lojasFiltradas.map(_cardLoja).toList());
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
              titulo: 'Lojas',
              subtitulo: _carregando
                  ? 'Carregando estabelecimentos...'
                  : '${_lojas.length} '
                        '${_lojas.length == 1 ? 'loja cadastrada' : 'lojas cadastradas'}',
              icone: Icons.storefront_rounded,
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                children: [
                  _campoBusca(),

                  const SizedBox(height: 12),

                  _acoesTopo(),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _carregarLojas,
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
