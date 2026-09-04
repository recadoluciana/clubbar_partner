import 'package:flutter/material.dart';

import '../../core/repositories/cardapio_padrao_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';

class CardapioPadraoPage extends StatefulWidget {
  final int organizacaoId;
  final String nomeOrganizacao;
  final List<Loja> lojas;

  const CardapioPadraoPage({
    super.key,
    required this.organizacaoId,
    required this.nomeOrganizacao,
    required this.lojas,
  });

  @override
  State<CardapioPadraoPage> createState() => _CardapioPadraoPageState();
}

class _CardapioPadraoPageState extends State<CardapioPadraoPage> {
  final _repository = CardapioPadraoRepository();
  bool _carregando = true;
  bool _salvando = false;
  String? _erro;
  Map<String, dynamic> _dados = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  String _mensagem(Object erro) => erro
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Exception:', '')
      .trim();

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final dados = await _repository.consultar(widget.organizacaoId);
      if (!mounted) return;
      setState(() => _dados = dados);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = _mensagem(e));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _escolherLojaOrigem() async {
    if (widget.lojas.isEmpty || _salvando) return;
    final loja = await showModalBottomSheet<Loja>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Escolha o cardápio de origem',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'O padrão atual será substituído. Os cardápios já importados pelas lojas não serão alterados.',
              ),
            ),
            ...widget.lojas.map(
              (item) => ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.storefront_rounded),
                ),
                title: Text(item.nmloja),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, item),
              ),
            ),
          ],
        ),
      ),
    );
    if (loja == null || !mounted) return;

    setState(() => _salvando = true);
    try {
      final resposta = await _repository.copiarDaLoja(
        widget.organizacaoId,
        loja.lojaId,
      );
      if (!mounted) return;
      AppSnackBar.sucesso(
        context,
        resposta['mensagem']?.toString() ?? 'Cardápio padrão atualizado.',
      );
      await _carregar();
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, _mensagem(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final produtos = (_dados['produtos'] as List? ?? const []);
    final quantidadeCategorias = _dados['quantidade_categorias'] ?? 0;
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true, centralizarLogo: true),
      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: widget.nomeOrganizacao,
            subtitulo: 'Cardápio digital padrão da organização',
            tituloStyle: const TextStyle(
              color: ClubbarColors.info,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
            trailing: IconButton.filled(
              tooltip: 'Definir a partir de um estabelecimento',
              onPressed: _salvando ? null : _escolherLojaOrigem,
              icon: _salvando
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.content_copy_rounded),
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _erro != null
                ? Center(
                    child: FilledButton.icon(
                      onPressed: _carregar,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(_erro!),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _carregar,
                    child: ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        ClubbarCard(
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: ClubbarColors.ambarClaro,
                              child: Icon(Icons.restaurant_menu_rounded),
                            ),
                            title: Text(
                              '${produtos.length} ${produtos.length == 1 ? 'produto' : 'produtos'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text('$quantidadeCategorias categorias'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (produtos.isEmpty)
                          ClubbarCard(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.menu_book_outlined,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'O cardápio padrão ainda não foi definido.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed: _escolherLojaOrigem,
                                    icon: const Icon(Icons.copy_all_rounded),
                                    label: const Text(
                                      'Escolher estabelecimento',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...produtos.map((item) {
                            final produto = Map<String, dynamic>.from(
                              item as Map,
                            );
                            return ClubbarCard(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.local_bar_outlined),
                                ),
                                title: Text(
                                  produto['nmproduto']?.toString() ?? 'Produto',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  produto['nmcategoria']?.toString() ??
                                      'Sem categoria',
                                ),
                                trailing: Text(
                                  'R\$ ${double.tryParse('${produto['vrprecoprod']}')?.toStringAsFixed(2).replaceAll('.', ',') ?? '0,00'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
