import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/cardapio_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_action_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';

class ProdutoPadraoFormPage extends StatefulWidget {
  final int organizacaoId;
  final String nomeOrganizacao;
  final Map<String, dynamic>? item;

  const ProdutoPadraoFormPage({
    super.key,
    required this.organizacaoId,
    required this.nomeOrganizacao,
    this.item,
  });

  @override
  State<ProdutoPadraoFormPage> createState() => _ProdutoPadraoFormPageState();
}

class _ProdutoPadraoFormPageState extends State<ProdutoPadraoFormPage> {
  final _repo = CardapioRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _descricao;
  late final TextEditingController _precoPadrao;
  String _situacao = 'ATIVO';
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item ?? const <String, dynamic>{};
    _nome = TextEditingController(text: '${item['nmproduto'] ?? ''}');
    _descricao = TextEditingController(text: '${item['dsproduto'] ?? ''}');
    _precoPadrao = TextEditingController(
      text: widget.item == null
          ? ''
          : _formatarPreco(_numeroPreco(item['vrprecopadrao']) ?? 0),
    );
    _situacao = '${item['sitproduto'] ?? 'ATIVO'}';
    _carregando = false;
  }

  @override
  void dispose() {
    for (final controller in [_nome, _descricao, _precoPadrao]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _dataRegistro(Object? valor) {
    final data = DateTime.tryParse('${valor ?? ''}');
    return data == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(data);
  }

  double? _numeroPreco(Object? valor) {
    final texto = '${valor ?? ''}'
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .trim();
    if (texto.isEmpty) return null;
    return double.tryParse(
      texto.contains(',')
          ? texto.replaceAll('.', '').replaceAll(',', '.')
          : texto,
    );
  }

  String _formatarPreco(double valor) =>
      NumberFormat('0.00', 'pt_BR').format(valor);

  Future<void> _salvar() async {
    if (_salvando || !_formKey.currentState!.validate()) return;
    final precoPadrao = _numeroPreco(_precoPadrao.text);
    if (precoPadrao == null || precoPadrao <= 0) {
      AppSnackBar.aviso(context, 'Informe um preço padrão maior que zero.');
      return;
    }
    setState(() => _salvando = true);
    try {
      final dados = <String, dynamic>{
        'nmproduto': _nome.text.trim(),
        'dsproduto': _descricao.text.trim().isEmpty
            ? null
            : _descricao.text.trim(),
        'vrprecopadrao': precoPadrao,
        'sitproduto': _situacao,
      };
      if (widget.item == null) {
        await _repo.criarProdutoPadraoOrganizacao(widget.organizacaoId, dados);
      } else {
        await _repo.alterarDadosProdutoPadraoOrganizacao(
          widget.organizacaoId,
          int.parse('${widget.item!['produto_id']}'),
          dados,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: Column(
      children: [
        ClubbarPageHeader(
          titulo: widget.item == null ? 'Novo produto' : 'Editar produto',
          subtitulo: widget.nomeOrganizacao,
        ),
        if (widget.item != null)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Este produto pode ser usado em outros cardápios. Alterações nos dados do produto também aparecerão neles.',
            ),
          ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        controller: _nome,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Nome do produto',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v ?? '').trim().length < 2
                            ? 'Informe o nome do produto.'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descricao,
                        maxLength: 255,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _precoPadrao,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Preço padrão',
                          prefixText: 'R\$ ',
                          helperText:
                              'Obrigatório e maior que zero. Sugestão inicial ao incluir no cardápio.',
                          border: OutlineInputBorder(),
                        ),
                        validator: (valor) {
                          final preco = _numeroPreco(valor);
                          return preco == null || preco <= 0
                              ? 'Informe um preço maior que zero.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _situacao,
                        decoration: const InputDecoration(
                          labelText: 'Situação',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'ATIVO',
                            child: Text('Ativo'),
                          ),
                          DropdownMenuItem(
                            value: 'INATIVO',
                            child: Text('Inativo'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _situacao = v ?? 'ATIVO'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'O preço padrão é apenas uma sugestão. O preço, a promoção e o cashback definidos no cardápio são os que valem para venda.',
                        style: TextStyle(color: ClubbarColors.textoSecundario),
                      ),
                      if (widget.item != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Produto #${widget.item!['produto_id']} • Organização #${widget.organizacaoId}',
                          style: const TextStyle(
                            color: ClubbarColors.textoSecundario,
                          ),
                        ),
                        Text(
                          'Criado em: ${_dataRegistro(widget.item!['dtcriacao'])}',
                          style: const TextStyle(
                            color: ClubbarColors.textoSecundario,
                          ),
                        ),
                        Text(
                          'Atualizado em: ${_dataRegistro(widget.item!['dtultatu'])}',
                          style: const TextStyle(
                            color: ClubbarColors.textoSecundario,
                          ),
                        ),
                      ],
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
        ),
      ],
    ),
    bottomNavigationBar: ClubbarActionBar(
      actions: [
        FilledButton.icon(
          onPressed: _salvando || _carregando ? null : _salvar,
          icon: _salvando
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(
            widget.item == null ? 'Adicionar produto' : 'Salvar alterações',
          ),
        ),
      ],
    ),
  );
}
