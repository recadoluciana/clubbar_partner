import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/cardapio_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import 'produto_padrao_form_page.dart';

class CardapioPadraoEmpresaPage extends StatefulWidget {
  final int organizacaoId;
  final String nomeOrganizacao;

  const CardapioPadraoEmpresaPage({
    super.key,
    required this.organizacaoId,
    required this.nomeOrganizacao,
  });

  @override
  State<CardapioPadraoEmpresaPage> createState() =>
      _CardapioPadraoEmpresaPageState();
}

class _CardapioPadraoEmpresaPageState extends State<CardapioPadraoEmpresaPage> {
  final _repo = CardapioRepository();
  final _pesquisaController = TextEditingController();
  List<Map<String, dynamic>> _produtos = [];
  bool _carregando = true;
  int? _produtoComSituacaoAlterando;
  String _pesquisa = '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _pesquisaController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _produtosFiltrados {
    final termo = _pesquisa.trim().toLowerCase();
    if (termo.isEmpty) return _produtos;
    return _produtos
        .where(
          (produto) =>
              '${produto['nmproduto'] ?? ''}'.toLowerCase().contains(termo),
        )
        .toList();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final produtos = await _repo.listarProdutosPadraoOrganizacao(
        widget.organizacaoId,
      );
      if (mounted) {
        setState(() => _produtos = produtos);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrirProduto([Map<String, dynamic>? produto]) async {
    final alterou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProdutoPadraoFormPage(
          organizacaoId: widget.organizacaoId,
          nomeOrganizacao: widget.nomeOrganizacao,
          item: produto,
        ),
      ),
    );
    if (alterou == true && mounted) await _carregar();
  }

  Future<void> _excluirProduto(Map<String, dynamic> produto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir produto?'),
        content: Text(
          'O produto ${produto['nmproduto']} será excluído. Caso já esteja sendo usado em algum cardápio ou venda, inative-o em vez de excluí-lo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await _repo.excluirProdutoPadraoOrganizacao(
        int.parse('${produto['produto_id']}'),
      );
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, 'Produto excluído.');
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  bool _produtoEstaAtivo(Map<String, dynamic> produto) =>
      '${produto['sitproduto']}'.trim().toUpperCase() == 'ATIVO';

  Future<void> _alterarSituacaoProduto(Map<String, dynamic> produto) async {
    final produtoId = int.parse('${produto['produto_id']}');
    final ativo = _produtoEstaAtivo(produto);
    setState(() => _produtoComSituacaoAlterando = produtoId);
    try {
      await _repo
          .alterarProdutoPadraoOrganizacao(widget.organizacaoId, produtoId, {
            'nmproduto': '${produto['nmproduto'] ?? ''}'.trim(),
            'dsproduto': '${produto['dsproduto'] ?? ''}'.trim().isEmpty
                ? null
                : '${produto['dsproduto']}'.trim(),
            'vrprecopadrao': produto['vrprecopadrao'] ?? 0,
            'sitproduto': ativo ? 'INATIVO' : 'ATIVO',
            'skuproduto': produto['skuproduto'],
            'urlfotoproduto': produto['urlfotoproduto'],
          });
      await _carregar();
      if (mounted) {
        AppSnackBar.sucesso(
          context,
          ativo ? 'Produto inativado.' : 'Produto ativado.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _produtoComSituacaoAlterando = null);
    }
  }

  Widget _cardProduto(Map<String, dynamic> produto) {
    final foto = '${produto['urlfotoproduto'] ?? ''}'.trim();
    final ativo = _produtoEstaAtivo(produto);
    final alterandoSituacao =
        _produtoComSituacaoAlterando == int.parse('${produto['produto_id']}');
    final descricao = '${produto['dsproduto'] ?? ''}'.trim();
    final precoPadrao =
        double.tryParse('${produto['vrprecopadrao'] ?? 0}') ?? 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: foto.isEmpty
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_outlined),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            foto.startsWith('http')
                                ? foto
                                : ApiConfig.buildUrl(foto),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.image_not_supported_outlined),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${produto['nmproduto']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        descricao.isEmpty ? 'Sem descrição' : descricao,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ClubbarColors.textoSecundario,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Preço padrão: R\$ ${precoPadrao.toStringAsFixed(2).replaceAll('.', ',')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ClubbarColors.textoSecundario,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar produto',
                  onPressed: () => _abrirProduto(produto),
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                ),
                IconButton(
                  tooltip: 'Excluir produto',
                  onPressed: () => _excluirProduto(produto),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: alterandoSituacao
                    ? null
                    : () => _alterarSituacaoProduto(produto),
                icon: alterandoSituacao
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        ativo
                            ? Icons.pause_circle_outline_rounded
                            : Icons.play_circle_outline_rounded,
                        size: 18,
                      ),
                label: Text(ativo ? 'Inativar' : 'Ativar'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: ativo
                      ? ClubbarColors.erro
                      : ClubbarColors.sucesso,
                  side: BorderSide(
                    color: ativo ? ClubbarColors.erro : ClubbarColors.sucesso,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _abaProdutos() {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    final produtos = _produtosFiltrados;
    return RefreshIndicator(
      onRefresh: _carregar,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largura = constraints.maxWidth;
          final colunas = largura < 600
              ? 1
              : largura < 900
              ? 2
              : largura < 1250
              ? 3
              : 4;
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: produtos.isEmpty ? 1 : produtos.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: colunas,
              mainAxisExtent: 132,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) => produtos.isEmpty
                ? const Card(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhum produto encontrado.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                : _cardProduto(produtos[index]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: Column(
      children: [
        ClubbarPageHeader(
          titulo: 'Produtos',
          subtitulo: widget.nomeOrganizacao,
          tituloStyle: const TextStyle(
            color: ClubbarColors.info,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
          trailing: FilledButton.icon(
            onPressed: _abrirProduto,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar produto'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _pesquisaController,
            onChanged: (valor) => setState(() => _pesquisa = valor),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Pesquisar produto por nome',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _pesquisa.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar pesquisa',
                      onPressed: () {
                        _pesquisaController.clear();
                        setState(() => _pesquisa = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(child: _abaProdutos()),
      ],
    ),
  );
}
