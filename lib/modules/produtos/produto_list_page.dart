import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/repositories/produto_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';
import 'produto_form_page.dart';

class ProdutoListPage extends StatefulWidget {
  final int organizacaoId;

  const ProdutoListPage({
    super.key,
    required this.organizacaoId,
  });

  @override
  State<ProdutoListPage> createState() => _ProdutoListPageState();
}

class _ProdutoListPageState extends State<ProdutoListPage> {
  final ProdutoRepository _repository = ProdutoRepository();
  final LojaRepository _lojaRepository = LojaRepository();
  final TextEditingController _buscaController = TextEditingController();

  bool _carregando = true;
  bool _carregandoLojas = true;
  bool _excluindo = false;

  String? _erro;

  List<dynamic> _produtos = [];
  List<dynamic> _produtosFiltrados = [];

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

  double _numero(dynamic valor) {
    return double.tryParse(
          (valor ?? '0').toString().replaceAll(',', '.'),
        ) ??
        0;
  }

  String _moeda(dynamic valor) {
    return NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    ).format(_numero(valor));
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

  String _montarUrlImagem(dynamic produto) {
    final caminho = (produto['urlfotoproduto'] ?? '')
        .toString()
        .trim();

    if (caminho.isEmpty) return '';

    if (caminho.startsWith('http://') ||
        caminho.startsWith('https://')) {
      return caminho;
    }

    return caminho.startsWith('/')
        ? '${ApiConfig.baseUrl}$caminho'
        : '${ApiConfig.baseUrl}/$caminho';
  }

  double _precoFinal(dynamic produto) {
    final preco = _numero(produto['vrprecoprod']);
    final tipo = (produto['tipodesconto'] ?? 'NENHUM')
        .toString()
        .toUpperCase();
    final desconto = _numero(produto['vrdesconto']);

    if (tipo == 'PERCENTUAL') {
      final valor = preco - (preco * desconto / 100);
      return valor < 0 ? 0 : valor;
    }

    if (tipo == 'VALOR') {
      final valor = preco - desconto;
      return valor < 0 ? 0 : valor;
    }

    return preco;
  }

  bool _temDesconto(dynamic produto) {
    final tipo = (produto['tipodesconto'] ?? 'NENHUM')
        .toString()
        .toUpperCase();
    final desconto = _numero(produto['vrdesconto']);

    return tipo != 'NENHUM' && desconto > 0;
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
        await _carregarProdutos();
      } else {
        setState(() {
          _produtos = [];
          _produtosFiltrados = [];
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

  Future<void> _carregarProdutos() async {
    final lojaId = _lojaIdSelecionada;

    if (lojaId == null) {
      setState(() {
        _produtos = [];
        _produtosFiltrados = [];
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
        _produtos = lista;
        _produtosFiltrados = _aplicarFiltro(
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

      AppSnackBar.erro(context, mensagem);
    }
  }

  List<dynamic> _aplicarFiltro(
    List<dynamic> produtos,
    String texto,
  ) {
    final busca = texto.trim().toLowerCase();

    if (busca.isEmpty) {
      return List<dynamic>.from(produtos);
    }

    return produtos.where((produto) {
      final nome = (produto['nmproduto'] ?? '')
          .toString()
          .toLowerCase();
      final categoria = (produto['nmcategoria'] ?? '')
          .toString()
          .toLowerCase();
      final status = (produto['sitproduto'] ?? '')
          .toString()
          .toLowerCase();
      final tipoDesconto = (produto['tipodesconto'] ?? '')
          .toString()
          .toLowerCase();
      final id = (produto['produto_id'] ?? '').toString();

      return nome.contains(busca) ||
          categoria.contains(busca) ||
          status.contains(busca) ||
          tipoDesconto.contains(busca) ||
          id.contains(busca);
    }).toList();
  }

  void _filtrar(String texto) {
    setState(() {
      _produtosFiltrados = _aplicarFiltro(
        _produtos,
        texto,
      );
    });
  }

  void _limparBusca() {
    _buscaController.clear();
    _filtrar('');
    FocusScope.of(context).unfocus();
  }

  Future<void> _abrirCadastro() async {
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
        builder: (_) => ProdutoFormPage(
          lojaId: lojaId,
          organizacaoId: widget.organizacaoId,
        ),
      ),
    );

    if (resultado == true) {
      await _carregarProdutos();
    }
  }

  Future<void> _abrirEdicao(dynamic produto) async {
    final lojaId = _lojaIdSelecionada;

    if (lojaId == null) return;

    try {
      final produtoMap = Map<String, dynamic>.from(
        produto as Map,
      );

      final resultado = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ProdutoFormPage(
            lojaId: lojaId,
            organizacaoId: widget.organizacaoId,
            produto: produtoMap,
          ),
        ),
      );

      if (resultado == true) {
        await _carregarProdutos();
      }
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(
        context,
        'Não foi possível abrir o produto para edição.',
      );
    }
  }

  Future<bool> _confirmarExclusao(dynamic produto) async {
    final nome = (produto['nmproduto'] ?? 'Produto').toString();

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
                  'Excluir produto',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Deseja realmente excluir "$nome"?\n\n'
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

  Future<void> _excluirProduto(dynamic produto) async {
    if (_excluindo) return;

    final confirmou = await _confirmarExclusao(produto);

    if (!confirmou) return;

    final produtoId = int.tryParse(
      (produto['produto_id'] ?? '').toString(),
    );

    if (produtoId == null) {
      AppSnackBar.erro(
        context,
        'Produto não identificado.',
      );
      return;
    }

    setState(() {
      _excluindo = true;
    });

    try {
      await _repository.excluir(produtoId);

      if (!mounted) return;

      AppSnackBar.sucesso(
        context,
        'Produto excluído com sucesso.',
      );

      await _carregarProdutos();
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

        await _carregarProdutos();
      },
    );
  }

  Widget _campoBusca() {
    return TextField(
      controller: _buscaController,
      onChanged: _filtrar,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar produto',
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
                  : _abrirCadastro,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Novo produto',
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
                : _carregarProdutos,
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

  Widget _imagemProduto(dynamic produto) {
    final url = _montarUrlImagem(produto);

    Widget placeholder() {
      return Container(
        color: ClubbarColors.ambarClaro,
        alignment: Alignment.center,
        child: const Icon(
          Icons.local_bar_rounded,
          size: 38,
          color: ClubbarColors.preto,
        ),
      );
    }

    if (url.isEmpty) {
      return placeholder();
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      width: 84,
      height: 84,
      errorBuilder: (_, _, _) {
        return placeholder();
      },
    );
  }

  Widget _chipStatus(dynamic produto) {
    final status = (produto['sitproduto'] ?? 'ATIVO')
        .toString()
        .trim()
        .toUpperCase();

    final ativo = status == 'ATIVO' || status == 'ATIVA';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: ativo
            ? ClubbarColors.sucessoClaro
            : ClubbarColors.erroClaro,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        ativo ? 'Ativo' : 'Inativo',
        style: TextStyle(
          color: ativo
              ? ClubbarColors.sucesso
              : ClubbarColors.erro,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _chipCategoria(dynamic produto) {
    final categoria = (produto['nmcategoria'] ?? 'Sem categoria')
        .toString()
        .trim();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: ClubbarColors.infoClaro,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        categoria.isEmpty ? 'Sem categoria' : categoria,
        style: const TextStyle(
          color: ClubbarColors.info,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _cardProduto(dynamic produto) {
    final nome = (produto['nmproduto'] ?? 'Produto').toString();
    final precoOriginal = _numero(produto['vrprecoprod']);
    final precoFinal = _precoFinal(produto);
    final temDesconto = _temDesconto(produto);

    return ClubbarCard(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      padding: const EdgeInsets.all(15),
      onTap: () => _abrirEdicao(produto),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: _imagemProduto(produto),
                ),
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
                            nome,
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
                        _chipStatus(produto),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chipCategoria(produto),
                        if (temDesconto)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: ClubbarColors.avisoClaro,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Promoção',
                              style: TextStyle(
                                color: ClubbarColors.aviso,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (temDesconto) ...[
                      Text(
                        _moeda(precoOriginal),
                        style: const TextStyle(
                          fontSize: 13,
                          color: ClubbarColors.textoSecundario,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      _moeda(precoFinal),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: temDesconto
                            ? ClubbarColors.sucesso
                            : ClubbarColors.textoPrincipal,
                      ),
                    ),
                  ],
                ),
              ),
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
                      : () => _abrirEdicao(produto),
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
                      : () => _excluirProduto(produto),
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
                        : Icons.inventory_2_rounded,
                size: 39,
                color: ClubbarColors.preto,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              !temLoja
                  ? 'Nenhuma loja disponível'
                  : temBusca
                      ? 'Nenhum produto encontrado'
                      : 'Nenhum produto cadastrado',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              !temLoja
                  ? 'Cadastre uma loja antes de criar produtos.'
                  : temBusca
                      ? 'Tente pesquisar por outro nome, categoria ou situação.'
                      : 'Cadastre o primeiro produto desta loja.',
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
                onPressed: _abrirCadastro,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Cadastrar produto',
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
              'Não foi possível carregar os produtos',
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
              onPressed: _carregarProdutos,
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

    if (_produtosFiltrados.isEmpty) {
      return _estadoVazio();
    }

    return Column(
      children: _produtosFiltrados
          .map(_cardProduto)
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
              titulo: 'Produtos',
              subtitulo: _carregando
                  ? 'Carregando produtos...'
                  : nomeLoja.isEmpty
                      ? 'Selecione uma loja'
                      : '$nomeLoja • ${_produtos.length} '
                          '${_produtos.length == 1 ? 'produto' : 'produtos'}',
              icone: Icons.inventory_2_rounded,
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
                onRefresh: _carregarProdutos,
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
