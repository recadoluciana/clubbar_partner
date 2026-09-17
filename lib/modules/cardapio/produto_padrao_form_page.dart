import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/cardapio_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../categorias/categorias_produtos_page.dart';

class ProdutoPadraoFormPage extends StatefulWidget {
  final int organizacaoId;
  final int modeloId;
  final Map<String, dynamic>? item;

  const ProdutoPadraoFormPage({
    super.key,
    required this.organizacaoId,
    required this.modeloId,
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
  late final TextEditingController _preco;
  late final TextEditingController _sku;
  late final TextEditingController _foto;
  late final TextEditingController _desconto;
  late final TextEditingController _cashback;
  List<Map<String, dynamic>> _categorias = [];
  int? _categoriaId;
  String _situacao = 'ATIVO';
  String _tipoDesconto = 'NENHUM';
  DateTime? _inicioDesconto;
  DateTime? _fimDesconto;
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item ?? const <String, dynamic>{};
    _nome = TextEditingController(text: '${item['nmproduto'] ?? ''}');
    _descricao = TextEditingController(text: '${item['dsproduto'] ?? ''}');
    _preco = TextEditingController(
      text: '${item['vrprecoprod'] ?? ''}'.replaceAll('.', ','),
    );
    _sku = TextEditingController(text: '${item['skuproduto'] ?? ''}');
    _foto = TextEditingController(text: '${item['urlfotoproduto'] ?? ''}');
    _desconto = TextEditingController(
      text: '${item['vrdesconto'] ?? ''}'.replaceAll('.', ','),
    );
    _cashback = TextEditingController(
      text: '${item['pccashback'] ?? ''}'.replaceAll('.', ','),
    );
    _categoriaId = (item['categoria_id'] as num?)?.toInt();
    _situacao = '${item['sitproduto'] ?? 'ATIVO'}';
    _tipoDesconto = '${item['tipodesconto'] ?? 'NENHUM'}';
    _inicioDesconto = DateTime.tryParse('${item['dtinidesconto'] ?? ''}');
    _fimDesconto = DateTime.tryParse('${item['dtfimdesconto'] ?? ''}');
    _carregarCategorias();
  }

  @override
  void dispose() {
    for (final controller in [
      _nome,
      _descricao,
      _preco,
      _sku,
      _foto,
      _desconto,
      _cashback,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarCategorias() async {
    setState(() => _carregando = true);
    try {
      final categorias = await _repo.listarCategoriasOrganizacao(
        widget.organizacaoId,
      );
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        if (!_categorias.any((c) => c['categoria_id'] == _categoriaId)) {
          _categoriaId = null;
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

  Future<void> _gerenciarCategorias() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CategoriasProdutosPage(organizacaoId: widget.organizacaoId),
      ),
    );
    if (mounted) await _carregarCategorias();
  }

  Future<void> _selecionarData(bool inicio) async {
    final atual = inicio ? _inicioDesconto : _fimDesconto;
    final data = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (data == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(atual ?? DateTime.now()),
    );
    if (hora == null || !mounted) return;
    final valor = DateTime(
      data.year,
      data.month,
      data.day,
      hora.hour,
      hora.minute,
    );
    setState(() {
      if (inicio) {
        _inicioDesconto = valor;
      } else {
        _fimDesconto = valor;
      }
    });
  }

  double? _numero(String texto) =>
      double.tryParse(texto.trim().replaceAll(',', '.'));

  String _dataRegistro(Object? valor) {
    final data = DateTime.tryParse('${valor ?? ''}');
    return data == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(data);
  }

  String? _validarNumero(
    String? texto, {
    bool positivo = false,
    double? maximo,
  }) {
    final valor = _numero(texto ?? '');
    if (valor == null || (positivo ? valor <= 0 : valor < 0)) {
      return positivo
          ? 'Informe um valor maior que zero.'
          : 'Informe um valor válido.';
    }
    if (maximo != null && valor > maximo) return 'O máximo é $maximo.';
    return null;
  }

  Future<void> _salvar() async {
    if (_salvando || !_formKey.currentState!.validate()) return;
    final preco = _numero(_preco.text)!;
    final desconto = _tipoDesconto == 'NENHUM' ? 0.0 : _numero(_desconto.text);
    if (_tipoDesconto != 'NENHUM' && desconto == null) {
      AppSnackBar.aviso(context, 'Informe o valor do desconto.');
      return;
    }
    if (_tipoDesconto == 'VALOR' && desconto! > preco) {
      AppSnackBar.aviso(context, 'O desconto não pode superar o preço.');
      return;
    }
    if (_inicioDesconto != null &&
        _fimDesconto != null &&
        _fimDesconto!.isBefore(_inicioDesconto!)) {
      AppSnackBar.aviso(
        context,
        'O fim do desconto deve ser posterior ao início.',
      );
      return;
    }
    final dados = <String, dynamic>{
      'categoria_id': _categoriaId,
      'nmproduto': _nome.text.trim(),
      'dsproduto': _descricao.text.trim().isEmpty
          ? null
          : _descricao.text.trim(),
      'vrprecoprod': preco,
      'sitproduto': _situacao,
      'skuproduto': _sku.text.trim().isEmpty ? null : _sku.text.trim(),
      'urlfotoproduto': _foto.text.trim().isEmpty ? null : _foto.text.trim(),
      'tipodesconto': _tipoDesconto,
      'vrdesconto': desconto ?? 0,
      'pccashback': _cashback.text.trim().isEmpty
          ? null
          : _numero(_cashback.text),
      'dtinidesconto': _tipoDesconto == 'NENHUM'
          ? null
          : _inicioDesconto?.toIso8601String(),
      'dtfimdesconto': _tipoDesconto == 'NENHUM'
          ? null
          : _fimDesconto?.toIso8601String(),
    };
    setState(() => _salvando = true);
    try {
      if (widget.item == null) {
        await _repo.adicionarItemPadrao(
          widget.organizacaoId,
          widget.modeloId,
          dados,
        );
      } else {
        await _repo.alterarProdutoPadrao(
          widget.organizacaoId,
          widget.modeloId,
          int.parse('${widget.item!['cardapiomodeloitem_id']}'),
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

  Widget _campoData(String titulo, DateTime? valor, bool inicio) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(titulo),
    subtitle: Text(
      valor == null
          ? 'Não definida'
          : DateFormat('dd/MM/yyyy HH:mm').format(valor),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (valor != null)
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Limpar',
            onPressed: () => setState(() {
              if (inicio) {
                _inicioDesconto = null;
              } else {
                _fimDesconto = null;
              }
            }),
          ),
        IconButton(
          icon: const Icon(Icons.calendar_month_outlined),
          tooltip: 'Escolher data e hora',
          onPressed: () => _selecionarData(inicio),
        ),
      ],
    ),
    onTap: () => _selecionarData(inicio),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: Column(
      children: [
        ClubbarPageHeader(
          titulo: widget.item == null ? 'Novo produto' : 'Editar produto',
          subtitulo: 'Cardápio padrão da empresa',
        ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      DropdownButtonFormField<int>(
                        key: ValueKey(_categoriaId),
                        initialValue: _categoriaId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Categoria da organização',
                          border: OutlineInputBorder(),
                        ),
                        items: _categorias
                            .map(
                              (c) => DropdownMenuItem<int>(
                                value: (c['categoria_id'] as num).toInt(),
                                child: Text('${c['nmcategoria']}'),
                              ),
                            )
                            .toList(),
                        onChanged: (id) => setState(() => _categoriaId = id),
                        validator: (id) =>
                            id == null ? 'Selecione uma categoria.' : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _gerenciarCategorias,
                          icon: const Icon(Icons.category_outlined),
                          label: const Text('Gerenciar categorias'),
                        ),
                      ),
                      if (_categorias.isEmpty)
                        const Text(
                          'Nenhuma categoria ativa. Cadastre uma categoria da empresa antes do produto.',
                        ),
                      const SizedBox(height: 8),
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
                        controller: _preco,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Preço do produto (R\$)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => _validarNumero(v),
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _sku,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'SKU (opcional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _foto,
                        maxLength: 255,
                        decoration: const InputDecoration(
                          labelText: 'URL da foto (opcional)',
                          helperText:
                              'Link da imagem ou caminho /uploads/produtos/...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _tipoDesconto,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de desconto',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'NENHUM',
                            child: Text('Nenhum'),
                          ),
                          DropdownMenuItem(
                            value: 'PERCENTUAL',
                            child: Text('Percentual'),
                          ),
                          DropdownMenuItem(
                            value: 'VALOR',
                            child: Text('Valor fixo'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _tipoDesconto = v ?? 'NENHUM'),
                      ),
                      if (_tipoDesconto != 'NENHUM') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _desconto,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: _tipoDesconto == 'PERCENTUAL'
                                ? 'Desconto (%)'
                                : 'Desconto (R\$)',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => _validarNumero(
                            v,
                            maximo: _tipoDesconto == 'PERCENTUAL' ? 100 : null,
                          ),
                        ),
                        _campoData('Início do desconto', _inicioDesconto, true),
                        _campoData('Fim do desconto', _fimDesconto, false),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _cashback,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Cashback (%) — opcional',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? null
                            : _validarNumero(v, maximo: 100),
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
