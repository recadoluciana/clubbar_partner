import 'package:flutter/material.dart';

import '../../core/repositories/cardapio_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_action_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import 'cardapio_gestao_empresa_page.dart';

class CardapiosEmpresaPage extends StatefulWidget {
  final int organizacaoId;
  final String nomeOrganizacao;

  const CardapiosEmpresaPage({
    super.key,
    required this.organizacaoId,
    required this.nomeOrganizacao,
  });

  @override
  State<CardapiosEmpresaPage> createState() => _CardapiosEmpresaPageState();
}

class _CardapiosEmpresaPageState extends State<CardapiosEmpresaPage> {
  final _repo = CardapioRepository();
  List<Map<String, dynamic>> _cardapios = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final cardapios = await _repo.listarCardapiosEmpresa(
        widget.organizacaoId,
      );
      if (mounted) {
        setState(() => _cardapios = cardapios);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _novo() async {
    final nome = TextEditingController();
    var tipo = 'PRINCIPAL';
    final resultado = await showDialog<(String, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, atualizar) => AlertDialog(
          title: const Text('Novo cardápio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nome,
                autofocus: true,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Nome do cardápio',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'PRINCIPAL',
                    child: Text('Principal'),
                  ),
                  DropdownMenuItem(value: 'ESPECIAL', child: Text('Especial')),
                ],
                onChanged: (valor) => atualizar(() => tipo = valor ?? tipo),
              ),
              const SizedBox(height: 12),
              const Text(
                'Depois de criado, associe o cardápio às lojas desejadas e edite o conteúdo. As alterações publicadas valerão em todas as lojas associadas.',
                style: TextStyle(color: ClubbarColors.textoSecundario),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (nome.text.trim().length >= 2) {
                  Navigator.pop(context, (nome.text.trim(), tipo));
                }
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
    nome.dispose();
    if (resultado == null || !mounted) {
      return;
    }
    try {
      await _repo.criarPadrao(widget.organizacaoId, resultado.$1, resultado.$2);
      await _carregar();
      if (mounted) {
        AppSnackBar.sucesso(
          context,
          'Cardápio criado. Associe-o a uma loja para configurar os itens.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  String _lojasTexto(Map<String, dynamic> cardapio) {
    final lojas = (cardapio['lojas'] as List? ?? const []);
    if (lojas.isEmpty) return 'Ainda não associado a uma loja';
    return 'Lojas: ${lojas.map((loja) => loja['nmfantasialoja']).join(', ')}';
  }

  bool _ehEspecial(Map<String, dynamic> cardapio) =>
      '${cardapio['tipocardapio']}'.trim().toUpperCase() == 'ESPECIAL';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: Column(
      children: [
        ClubbarPageHeader(
          titulo: widget.nomeOrganizacao,
          subtitulo: 'Cardápios da empresa',
        ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'O cardápio é compartilhável: preço, promoção e cashback são definidos por produto dentro dele. Toque em um cardápio para editar o conteúdo, publicar e definir as lojas em que ele ficará disponível.',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_cardapios.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Nenhum cardápio criado. Crie o primeiro cardápio da empresa.',
                            ),
                          ),
                        ),
                      for (final cardapio in _cardapios)
                        Builder(
                          builder: (context) {
                            final especial = _ehEspecial(cardapio);
                            final cor = especial
                                ? Colors.deepPurple
                                : ClubbarColors.primaria;
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  especial
                                      ? Icons.auto_awesome_rounded
                                      : Icons.menu_book_rounded,
                                  color: cor,
                                ),
                                title: Text('${cardapio['nmcardapio']}'),
                                subtitle: Text(
                                  '${cardapio['tipocardapio']} • ${cardapio['quantidade_produtos'] ?? 0} produtos\n${_lojasTexto(cardapio)}',
                                ),
                                isThreeLine: true,
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () async {
                                  final alterado = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CardapioGestaoEmpresaPage(
                                        organizacaoId: widget.organizacaoId,
                                        nomeOrganizacao: widget.nomeOrganizacao,
                                        cardapioId: int.parse(
                                          '${cardapio['cardapio_id']}',
                                        ),
                                      ),
                                    ),
                                  );
                                  if (alterado == true && mounted) _carregar();
                                },
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
        ),
      ],
    ),
    bottomNavigationBar: ClubbarActionBar(
      actions: [ClubbarAddButton(onPressed: _novo, label: 'Novo cardápio')],
    ),
  );
}
