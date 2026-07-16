import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/repositories/categoria_repository.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/categoria.dart';
import '../../models/loja.dart';
import 'categoria_form_page.dart';

class CategoriaListPage extends StatefulWidget {
  final int organizacaoId;

  const CategoriaListPage({
    super.key,
    required this.organizacaoId,
  });

  @override
  State<CategoriaListPage> createState() => _CategoriaListPageState();
}

class _CategoriaListPageState extends State<CategoriaListPage> {
  final CategoriaRepository _repository = CategoriaRepository();
  final LojaRepository _lojaRepository = LojaRepository();
  final TextEditingController _buscaController = TextEditingController();

  bool _carregando = true;
  bool _carregandoLojas = true;
  bool _excluindo = false;

  String? _erro;

  List<Categoria> _categorias = [];
  List<Categoria> _categoriasFiltradas = [];

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

    return mensagem.isEmpty
        ? 'Ocorreu um erro inesperado.'
        : mensagem;
  }

  Future<void> _carregarLojas() async {
    setState(() {
      _carregandoLojas = true;
      _carregando = true;
      _erro = null;
    });

    try {
      final lojas = await _lojaRepository.listar(
        widget.organizacaoId,
      );

      if (!mounted) return;

      int? lojaSelecionada = _lojaIdSelecionada;

      if (lojas.isNotEmpty) {
        final existe = lojas.any(
          (loja) => loja.lojaId == lojaSelecionada,
        );

        if (!existe) {
          lojaSelecionada = lojas.first.lojaId;
        }
      } else {
        lojaSelecionada = null;
      }

      setState(() {
        _lojas = lojas;
        _lojaIdSelecionada = lojaSelecionada;
        _carregandoLojas = false;
      });

      if (_lojaIdSelecionada != null) {
        await _carregarCategorias();
      } else {
        setState(() {
          _categorias = [];
          _categoriasFiltradas = [];
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

      AppSnackBar.erro(
        context,
        mensagem,
      );
    }
  }

  Future<void> _carregarCategorias() async {
    final lojaId = _lojaIdSelecionada;

    if (lojaId == null) {
      setState(() {
        _categorias = [];
        _categoriasFiltradas = [];
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
        _categorias = lista;
        _categoriasFiltradas = _aplicarFiltro(
          lista,
          _buscaController.text,
        );
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      final mensagem = _extrairMensagemErro(e);

      setState(() {
        _carregando = false;
        _erro = mensagem;
      });

      AppSnackBar.erro(
        context,
        mensagem,
      );
    }
  }

  List<Categoria> _aplicarFiltro(
    List<Categoria> categorias,
    String texto,
  ) {
    final busca = texto.trim().toLowerCase();

    if (busca.isEmpty) {
      return List<Categoria>.from(categorias);
    }

    return categorias.where((categoria) {
      final id = categoria.categoriaId.toString();
      final nome = categoria.nmcategoria.toLowerCase();
      final status = (categoria.sitcategoria ?? '').toLowerCase();
      final ordem = (categoria.idordcategoria ?? 0).toString();

      return id.contains(busca) ||
          nome.contains(busca) ||
          status.contains(busca) ||
          ordem.contains(busca);
    }).toList();
  }

  void _filtrar(String texto) {
    setState(() {
      _categoriasFiltradas = _aplicarFiltro(
        _categorias,
        texto,
      );
    });
  }

  void _limparBusca() {
    _buscaController.clear();
    _filtrar('');
    FocusScope.of(context).unfocus();
  }

  String _nomeLojaSelecionada() {
    final lojaId = _lojaIdSelecionada;

    if (lojaId == null) return '';

    for (final loja in _lojas) {
      if (loja.lojaId == lojaId) {
        return loja.nmloja;
      }
    }

    return '';
  }

  Future<void> _abrirNovaCategoria() async {
    final lojaId = _lojaIdSelecionada;

    if (lojaId == null) {
      AppSnackBar.aviso(
        context,
        'Selecione uma loja.',
      );
      return;
    }

    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CategoriaFormPage(
          lojaId: lojaId,
        ),
      ),
    );

    if (resultado == true) {
      await _carregarCategorias();
    }
  }

  Future<void> _abrirEdicao(Categoria categoria) async {
    final lojaId = _lojaIdSelecionada;

    if (lojaId == null) return;

    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CategoriaFormPage(
          lojaId: lojaId,
          categoria: categoria,
        ),
      ),
    );

    if (resultado == true) {
      await _carregarCategorias();
    }
  }

  Future<bool> _confirmarExclusao(Categoria categoria) async {
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
                  'Excluir categoria',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Deseja realmente excluir a categoria '
            '"${categoria.nmcategoria}"?\n\n'
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: ClubbarColors.textoPrincipal,
                side: const BorderSide(
                  color: ClubbarColors.borda,
                ),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
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

  Future<void> _excluirCategoria(Categoria categoria) async {
    final lojaId = _lojaIdSelecionada;

    if (lojaId == null || _excluindo) return;

    final confirmou = await _confirmarExclusao(categoria);

    if (!confirmou) return;

    setState(() {
      _excluindo = true;
    });

    try {
      await _repository.excluir(
        lojaId,
        categoria.categoriaId,
      );

      if (!mounted) return;

      AppSnackBar.sucesso(
        context,
        'Categoria excluída com sucesso.',
      );

      await _carregarCategorias();
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(
        context,
        _extrairMensagemErro(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _excluindo = false;
        });
      }
    }
  }

  Widget _campoLoja() {
    if (_carregandoLojas) {
      return const SizedBox(
        height: 56,
        child: Center(
          child: CircularProgressIndicator(
            color: ClubbarColors.ambar,
          ),
        ),
      );
    }

    return DropdownButtonFormField<int>(
      initialValue: _lojaIdSelecionada,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Loja',
        prefixIcon: const Icon(
          Icons.storefront_rounded,
          color: ClubbarColors.textoSecundario,
        ),
        filled: true,
        fillColor: ClubbarColors.branco,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: ClubbarColors.borda,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: ClubbarColors.borda,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: ClubbarColors.ambar,
            width: 2,
          ),
        ),
      ),
      items: _lojas.map((loja) {
        return DropdownMenuItem<int>(
          value: loja.lojaId,
          child: Text(
            loja.nmloja,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) async {
        setState(() {
          _lojaIdSelecionada = value;
        });

        await _carregarCategorias();
      },
    );
  }

  Widget _campoBusca() {
    return TextField(
      controller: _buscaController,
      onChanged: _filtrar,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar categoria',
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
          borderSide: const BorderSide(
            color: ClubbarColors.borda,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: ClubbarColors.borda,
          ),
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
              onPressed: _lojaIdSelecionada == null
                  ? null
                  : _abrirNovaCategoria,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Nova categoria',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
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
            onPressed: _carregando
                ? null
                : _carregarCategorias,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: ClubbarColors.textoPrincipal,
              side: const BorderSide(
                color: ClubbarColors.borda,
              ),
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

  Widget _chipStatus(Categoria categoria) {
    final status = (categoria.sitcategoria ?? 'ATIVA')
        .trim()
        .toUpperCase();

    final ativa = status == 'ATIVA' || status == 'ATIVO';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: ativa
            ? ClubbarColors.sucessoClaro
            : ClubbarColors.erroClaro,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        ativa ? 'Ativa' : 'Inativa',
        style: TextStyle(
          color: ativa
              ? ClubbarColors.sucesso
              : ClubbarColors.erro,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _cardCategoria(Categoria categoria) {
    final ordem = categoria.idordcategoria ?? 0;

    return ClubbarCard(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      padding: const EdgeInsets.all(15),
      onTap: () => _abrirEdicao(categoria),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: ClubbarColors.ambarClaro,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.category_rounded,
                  size: 29,
                  color: ClubbarColors.preto,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoria.nmcategoria,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: ClubbarColors.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.format_list_numbered_rounded,
                          size: 17,
                          color: ClubbarColors.textoSecundario,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Ordem no cardápio: $ordem',
                          style: const TextStyle(
                            fontSize: 13,
                            color: ClubbarColors.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _chipStatus(categoria),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(
            height: 1,
            color: ClubbarColors.divisor,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _excluindo
                      ? null
                      : () => _abrirEdicao(categoria),
                  icon: const Icon(
                    Icons.edit_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Editar',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ClubbarColors.textoPrincipal,
                    side: const BorderSide(
                      color: ClubbarColors.borda,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _excluindo
                      ? null
                      : () => _excluirCategoria(categoria),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Excluir',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
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
                        : Icons.category_rounded,
                size: 39,
                color: ClubbarColors.preto,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              !temLoja
                  ? 'Nenhuma loja disponível'
                  : temBusca
                      ? 'Nenhuma categoria encontrada'
                      : 'Nenhuma categoria cadastrada',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              !temLoja
                  ? 'Cadastre uma loja antes de criar categorias.'
                  : temBusca
                      ? 'Tente pesquisar por outro nome, ordem ou situação.'
                      : 'Cadastre a primeira categoria desta loja.',
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
                onPressed: _abrirNovaCategoria,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Cadastrar categoria',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
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
              'Não foi possível carregar as categorias',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
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
              onPressed: _carregarCategorias,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'Tentar novamente',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
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
          child: CircularProgressIndicator(
            color: ClubbarColors.ambar,
          ),
        ),
      );
    }

    if (_erro != null) {
      return _estadoErro();
    }

    if (_categoriasFiltradas.isEmpty) {
      return _estadoVazio();
    }

    return Column(
      children: _categoriasFiltradas
          .map(_cardCategoria)
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nomeLoja = _nomeLojaSelecionada();

    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(
        mostrarVoltar: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: 'Categorias',
              subtitulo: _carregando
                  ? 'Carregando categorias...'
                  : nomeLoja.isEmpty
                      ? 'Selecione uma loja'
                      : '$nomeLoja • ${_categorias.length} '
                          '${_categorias.length == 1 ? 'categoria' : 'categorias'}',
              icone: Icons.category_rounded,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                18,
                20,
                0,
              ),
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
                onRefresh: _carregarCategorias,
                color: ClubbarColors.ambar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    28,
                  ),
                  children: [
                    _conteudoLista(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
