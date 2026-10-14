import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/cardapio_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';

class ProdutoPadraoFormPage extends StatefulWidget {
  final int organizacaoId;
  final int? modeloId;
  final int? categoriaPadraoIdInicial;
  final Map<String, dynamic>? item;

  const ProdutoPadraoFormPage({
    super.key,
    required this.organizacaoId,
    this.modeloId,
    this.categoriaPadraoIdInicial,
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
  String? _fotoUrl;
  XFile? _fotoSelecionada;
  Uint8List? _fotoBytes;
  List<Map<String, dynamic>> _categorias = [];
  int? _categoriaId;
  String _situacao = 'ATIVO';
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item ?? const <String, dynamic>{};
    _nome = TextEditingController(text: '${item['nmproduto'] ?? ''}');
    _descricao = TextEditingController(text: '${item['dsproduto'] ?? ''}');
    _fotoUrl = item['urlfotoproduto']?.toString();
    _categoriaId =
        (item['cardapiomodelocategoria_id'] as num?)?.toInt() ??
        widget.categoriaPadraoIdInicial;
    _situacao = '${item['sitproduto'] ?? 'ATIVO'}';
    _carregarCategorias();
  }

  @override
  void dispose() {
    for (final controller in [_nome, _descricao]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarCategorias() async {
    if (widget.modeloId == null) {
      setState(() => _carregando = false);
      return;
    }
    setState(() => _carregando = true);
    try {
      final categorias = await _repo.listarCategoriasPadrao(
        widget.organizacaoId,
        widget.modeloId!,
      );
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        if (!_categorias.any(
          (c) => c['cardapiomodelocategoria_id'] == _categoriaId,
        )) {
          _categoriaId = _categorias.length == 1
              ? (_categorias.first['cardapiomodelocategoria_id'] as num).toInt()
              : null;
        }
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _selecionarFoto() async {
    try {
      final foto = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (foto == null) return;
      final bytes = await foto.readAsBytes();
      if (!mounted) return;
      setState(() {
        _fotoSelecionada = foto;
        _fotoBytes = bytes;
      });
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, 'Não foi possível abrir a foto.');
    }
  }

  String _dataRegistro(Object? valor) {
    final data = DateTime.tryParse('${valor ?? ''}');
    return data == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(data);
  }

  Future<void> _salvar() async {
    if (_salvando || !_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      if (_fotoSelecionada != null) {
        _fotoUrl = widget.modeloId == null
            ? await _repo.enviarFotoProdutoPadraoOrganizacao(
                widget.organizacaoId,
                _fotoSelecionada!,
              )
            : await _repo.enviarFotoProdutoPadrao(
                widget.organizacaoId,
                widget.modeloId!,
                _fotoSelecionada!,
              );
      }
      final dados = <String, dynamic>{
        if (widget.modeloId != null) 'cardapiomodelocategoria_id': _categoriaId,
        if (widget.item != null) 'produto_id': widget.item!['produto_id'],
        'nmproduto': _nome.text.trim(),
        'dsproduto': _descricao.text.trim().isEmpty
            ? null
            : _descricao.text.trim(),
        'vrprecoprod': 0,
        'sitproduto': _situacao,
        if (widget.item != null) 'skuproduto': widget.item!['skuproduto'],
        'urlfotoproduto': _fotoUrl,
        'tipodesconto': 'NENHUM',
        'vrdesconto': 0,
        'pccashback': null,
        'dtinidesconto': null,
        'dtfimdesconto': null,
      };
      if (widget.modeloId == null) {
        if (widget.item == null) {
          await _repo.criarProdutoPadraoOrganizacao(
            widget.organizacaoId,
            dados,
          );
        } else {
          await _repo.alterarProdutoPadraoOrganizacao(
            widget.organizacaoId,
            int.parse('${widget.item!['produto_id']}'),
            dados,
          );
        }
      } else if (widget.item == null) {
        await _repo.adicionarItemPadrao(
          widget.organizacaoId,
          widget.modeloId!,
          dados,
        );
      } else {
        await _repo.alterarProdutoPadrao(
          widget.organizacaoId,
          widget.modeloId!,
          int.parse('${widget.item!['cardapiomodeloproduto_id']}'),
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
          subtitulo: widget.modeloId == null
              ? 'Produtos da empresa'
              : 'Cardápio padrão da empresa',
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
                      if (widget.modeloId != null) ...[
                        DropdownButtonFormField<int>(
                          key: ValueKey(_categoriaId),
                          initialValue: _categoriaId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Categoria do cardápio',
                            border: OutlineInputBorder(),
                          ),
                          items: _categorias
                              .map(
                                (c) => DropdownMenuItem<int>(
                                  value:
                                      (c['cardapiomodelocategoria_id'] as num)
                                          .toInt(),
                                  child: Text('${c['nmcategoria']}'),
                                ),
                              )
                              .toList(),
                          onChanged: (id) => setState(() => _categoriaId = id),
                          validator: (id) =>
                              id == null ? 'Selecione uma categoria.' : null,
                        ),
                        if (_categorias.isEmpty)
                          const Text(
                            'Inclua uma categoria neste cardápio antes de cadastrar produtos.',
                          ),
                        const SizedBox(height: 8),
                      ],
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
                      InkWell(
                        onTap: _selecionarFoto,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: ClubbarColors.textoSecundario,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _fotoBytes != null
                              ? Image.memory(_fotoBytes!, fit: BoxFit.contain)
                              : (_fotoUrl ?? '').isNotEmpty
                              ? Image.network(
                                  _fotoUrl!.startsWith('http')
                                      ? _fotoUrl!
                                      : ApiConfig.buildUrl(_fotoUrl!),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.image_not_supported_outlined,
                                  ),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_outlined, size: 44),
                                    SizedBox(height: 8),
                                    Text(
                                      'Toque para escolher a foto do produto',
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Preço, promoção e cashback são definidos quando este produto for incluído em um cardápio.',
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
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
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
      ),
    ),
  );
}
