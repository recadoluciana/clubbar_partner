import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/categoria_repository.dart';
import '../../core/repositories/produto_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/categoria.dart';

class ProdutoFormPage extends StatefulWidget {
  final int lojaId;
  final int organizacaoId;
  final Map<String, dynamic>? produto;

  const ProdutoFormPage({
    super.key,
    required this.lojaId,
    required this.organizacaoId,
    this.produto,
  });

  @override
  State<ProdutoFormPage> createState() => _ProdutoFormPageState();
}

class _ProdutoFormPageState extends State<ProdutoFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _produtoRepository = ProdutoRepository();
  final _categoriaRepository = CategoriaRepository();
  final _picker = ImagePicker();

  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _precoController = TextEditingController();
  final _vrDescontoController = TextEditingController();
  final _dtIniDescontoController = TextEditingController();
  final _dtFimDescontoController = TextEditingController();

  bool _salvando = false;
  bool _carregandoCategorias = true;

  List<Categoria> _categorias = [];
  int? _categoriaIdSelecionada;

  String _statusSelecionado = 'ATIVO';
  String _tipoDescontoSelecionado = 'NENHUM';

  XFile? _imagemSelecionada;
  Uint8List? _imagemBytes;

  bool get editando => widget.produto != null;
  bool get _descontoAtivo => _tipoDescontoSelecionado != 'NENHUM';

  @override
  void initState() {
    super.initState();

    _precoController.addListener(_atualizarResumo);
    _vrDescontoController.addListener(_atualizarResumo);

    final produto = widget.produto;

    if (produto != null) {
      _nomeController.text = (produto['nmproduto'] ?? '').toString();
      _descricaoController.text = (produto['dsproduto'] ?? '').toString();
      _precoController.text = (produto['vrprecoprod'] ?? '').toString();
      _categoriaIdSelecionada = int.tryParse(
        (produto['categoria_id'] ?? '').toString(),
      );
      _statusSelecionado = (produto['sitproduto'] ?? 'ATIVO').toString();
      _tipoDescontoSelecionado = (produto['tipodesconto'] ?? 'NENHUM')
          .toString();
      _vrDescontoController.text = (produto['vrdesconto'] ?? '0').toString();
      _dtIniDescontoController.text = _formatarDataTela(
        produto['dtinidesconto'],
      );
      _dtFimDescontoController.text = _formatarDataTela(
        produto['dtfimdesconto'],
      );
    } else {
      _vrDescontoController.text = '0';
    }

    _carregarCategorias();
  }

  @override
  void dispose() {
    _precoController.removeListener(_atualizarResumo);
    _vrDescontoController.removeListener(_atualizarResumo);

    _nomeController.dispose();
    _descricaoController.dispose();
    _precoController.dispose();
    _vrDescontoController.dispose();
    _dtIniDescontoController.dispose();
    _dtFimDescontoController.dispose();
    super.dispose();
  }

  void _atualizarResumo() {
    if (mounted) {
      setState(() {});
    }
  }

  String _mensagemErro(Object erro) {
    final texto = erro.toString().replaceFirst('Exception: ', '').trim();

    return texto.isEmpty ? 'Ocorreu um erro inesperado.' : texto;
  }

  double _numero(String valor) {
    return double.tryParse(
          valor
              .replaceAll('R\$', '')
              .replaceAll('%', '')
              .replaceAll(' ', '')
              .replaceAll('.', '')
              .replaceAll(',', '.')
              .trim(),
        ) ??
        0;
  }

  String _moeda(double valor) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(valor);
  }

  double get _precoOriginal {
    return _numero(_precoController.text);
  }

  double get _valorDesconto {
    return _descontoAtivo ? _numero(_vrDescontoController.text) : 0;
  }

  double get _precoFinal {
    final preco = _precoOriginal;
    final desconto = _valorDesconto;

    if (_tipoDescontoSelecionado == 'PERCENTUAL') {
      final valor = preco - (preco * desconto / 100);
      return valor < 0 ? 0 : valor;
    }

    if (_tipoDescontoSelecionado == 'VALOR') {
      final valor = preco - desconto;
      return valor < 0 ? 0 : valor;
    }

    return preco;
  }

  String _formatarDataTela(dynamic valor) {
    final texto = (valor ?? '').toString().trim();

    if (texto.isEmpty || texto == 'null') {
      return '';
    }

    try {
      final data = DateTime.parse(texto);
      return DateFormat('dd/MM/yyyy HH:mm').format(data);
    } catch (_) {
      return texto;
    }
  }

  String? _formatarDataApi(String texto) {
    final valor = texto.trim();

    if (valor.isEmpty) return null;

    try {
      final data = DateFormat('dd/MM/yyyy HH:mm').parseStrict(valor);

      return DateFormat('yyyy-MM-dd HH:mm:ss').format(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _selecionarDataHora(TextEditingController controller) async {
    final agora = DateTime.now();

    final data = await showDatePicker(
      context: context,
      initialDate: agora,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (data == null || !mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(agora),
    );

    if (hora == null) return;

    final dataHora = DateTime(
      data.year,
      data.month,
      data.day,
      hora.hour,
      hora.minute,
    );

    controller.text = DateFormat('dd/MM/yyyy HH:mm').format(dataHora);
  }

  Future<void> _carregarCategorias() async {
    setState(() {
      _carregandoCategorias = true;
    });

    try {
      final lista = await _categoriaRepository.listar(widget.lojaId);

      if (!mounted) return;

      int? categoriaSelecionada = _categoriaIdSelecionada;

      if (lista.isNotEmpty) {
        final existe = lista.any(
          (categoria) => categoria.categoriaId == categoriaSelecionada,
        );

        if (!existe) {
          categoriaSelecionada = lista.first.categoriaId;
        }
      } else {
        categoriaSelecionada = null;
      }

      setState(() {
        _categorias = lista;
        _categoriaIdSelecionada = categoriaSelecionada;
        _carregandoCategorias = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _carregandoCategorias = false;
      });

      AppSnackBar.erro(context, 'Não foi possível carregar as categorias.');
    }
  }

  Future<void> _selecionarImagem() async {
    try {
      final arquivo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );

      if (arquivo == null) return;

      Uint8List? bytes;

      if (kIsWeb) {
        bytes = await arquivo.readAsBytes();
      }

      if (!mounted) return;

      setState(() {
        _imagemSelecionada = arquivo;
        _imagemBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, 'Não foi possível selecionar a imagem.');
    }
  }

  String _montarUrlImagemAtual() {
    final imagemAtual = (widget.produto?['urlfotoproduto'] ?? '')
        .toString()
        .trim();

    if (imagemAtual.isEmpty) return '';

    if (imagemAtual.startsWith('http://') ||
        imagemAtual.startsWith('https://')) {
      return imagemAtual;
    }

    return imagemAtual.startsWith('/')
        ? '${ApiConfig.baseUrl}$imagemAtual'
        : '${ApiConfig.baseUrl}/$imagemAtual';
  }

  InputDecoration _decoracaoCampo({
    required String label,
    required IconData icone,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icone, color: ClubbarColors.textoSecundario),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: ClubbarColors.branco,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ClubbarColors.erro),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ClubbarColors.erro, width: 2),
      ),
    );
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_categoriaIdSelecionada == null) {
      AppSnackBar.aviso(context, 'Selecione uma categoria.');
      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      final preco = _precoOriginal;

      if (preco <= 0) {
        throw Exception('Informe um preço maior que zero.');
      }

      final vrDesconto = _valorDesconto;

      if (_tipoDescontoSelecionado == 'PERCENTUAL' && vrDesconto > 100) {
        throw Exception('O desconto percentual não pode ser maior que 100%.');
      }

      if (_tipoDescontoSelecionado == 'VALOR' && vrDesconto > preco) {
        throw Exception('O desconto não pode ser maior que o preço.');
      }

      final dtIniDesconto = _formatarDataApi(_dtIniDescontoController.text);
      final dtFimDesconto = _formatarDataApi(_dtFimDescontoController.text);

      if (_dtIniDescontoController.text.trim().isNotEmpty &&
          dtIniDesconto == null) {
        throw Exception('Data inicial inválida. Use dd/MM/yyyy HH:mm.');
      }

      if (_dtFimDescontoController.text.trim().isNotEmpty &&
          dtFimDesconto == null) {
        throw Exception('Data final inválida. Use dd/MM/yyyy HH:mm.');
      }

      if (_descontoAtivo && dtIniDesconto != null && dtFimDesconto != null) {
        final inicio = DateFormat('yyyy-MM-dd HH:mm:ss').parse(dtIniDesconto);

        final fim = DateFormat('yyyy-MM-dd HH:mm:ss').parse(dtFimDesconto);

        if (!fim.isAfter(inicio)) {
          throw Exception('A data final deve ser posterior à data inicial.');
        }
      }

      if (editando) {
        await _produtoRepository.atualizar(
          produtoId: widget.produto!['produto_id'],
          categoriaId: _categoriaIdSelecionada,
          nome: _nomeController.text.trim(),
          descricao: _descricaoController.text.trim(),
          preco: preco,
          status: _statusSelecionado,
          imagem: _imagemSelecionada,
          tipodesconto: _tipoDescontoSelecionado,
          vrdesconto: _descontoAtivo ? vrDesconto : 0,
          dtinidesconto: _descontoAtivo ? dtIniDesconto : '',
          dtfimdesconto: _descontoAtivo ? dtFimDesconto : '',
        );
      } else {
        await _produtoRepository.criar(
          organizacaoId: widget.organizacaoId,
          lojaId: widget.lojaId,
          categoriaId: _categoriaIdSelecionada!,
          nome: _nomeController.text.trim(),
          descricao: _descricaoController.text.trim(),
          preco: preco,
          sitproduto: _statusSelecionado,
          imagem: _imagemSelecionada,
          tipodesconto: _tipoDescontoSelecionado,
          vrdesconto: _descontoAtivo ? vrDesconto : 0,
          dtinidesconto: _descontoAtivo ? dtIniDesconto : '',
          dtfimdesconto: _descontoAtivo ? dtFimDesconto : '',
        );
      }

      if (!mounted) return;

      AppSnackBar.sucesso(
        context,
        editando
            ? 'Produto atualizado com sucesso.'
            : 'Produto criado com sucesso.',
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, _mensagemErro(e));
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  Widget _imagemSelecionadaWidget() {
    final imagemAtualUrl = _montarUrlImagemAtual();

    Widget placeholder() {
      return Container(
        color: ClubbarColors.ambarClaro,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          size: 52,
          color: ClubbarColors.preto,
        ),
      );
    }

    if (_imagemSelecionada != null) {
      if (kIsWeb && _imagemBytes != null) {
        return Image.memory(
          _imagemBytes!,
          fit: BoxFit.cover,
          width: double.infinity,
        );
      }

      return Image.network(
        _imagemSelecionada!.path,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, _, _) => placeholder(),
      );
    }

    if (editando && imagemAtualUrl.isNotEmpty) {
      return Image.network(
        imagemAtualUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, _, _) => placeholder(),
      );
    }

    return placeholder();
  }

  Widget _cardImagem() {
    return ClubbarCard(
      elevation: 1,
      child: Column(
        children: [
          const Text(
            'Imagem do produto',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: double.infinity,
              height: 210,
              child: _imagemSelecionadaWidget(),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _salvando ? null : _selecionarImagem,
              icon: const Icon(Icons.photo_library_rounded),
              label: Text(
                _imagemSelecionada != null || editando
                    ? 'Alterar imagem'
                    : 'Selecionar imagem',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: ClubbarColors.textoPrincipal,
                side: const BorderSide(color: ClubbarColors.borda),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardDados() {
    return ClubbarCard(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dados do produto',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nomeController,
            textCapitalization: TextCapitalization.words,
            decoration: _decoracaoCampo(
              label: 'Nome do produto',
              icone: Icons.local_bar_outlined,
              hint: 'Ex.: Caipirinha de morango',
            ),
            validator: (value) {
              final texto = value?.trim() ?? '';

              if (texto.isEmpty) {
                return 'Informe o nome do produto';
              }

              if (texto.length < 2) {
                return 'Nome muito curto';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _descricaoController,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoracaoCampo(
              label: 'Descrição',
              icone: Icons.description_outlined,
              hint: 'Descreva o produto',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _precoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoracaoCampo(
              label: 'Preço',
              icone: Icons.attach_money_rounded,
              hint: '0,00',
            ),
            validator: (value) {
              final preco = _numero(value ?? '');

              if (preco <= 0) {
                return 'Informe um preço válido';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          _carregandoCategorias
              ? const Center(
                  child: CircularProgressIndicator(color: ClubbarColors.ambar),
                )
              : DropdownButtonFormField<int>(
                  initialValue: _categoriaIdSelecionada,
                  isExpanded: true,
                  decoration: _decoracaoCampo(
                    label: 'Categoria',
                    icone: Icons.category_outlined,
                  ),
                  items: _categorias.map((categoria) {
                    return DropdownMenuItem<int>(
                      value: categoria.categoriaId,
                      child: Text(
                        categoria.nmcategoria,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _salvando
                      ? null
                      : (value) {
                          setState(() {
                            _categoriaIdSelecionada = value;
                          });
                        },
                  validator: (value) {
                    if (value == null) {
                      return 'Selecione uma categoria';
                    }

                    return null;
                  },
                ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _statusSelecionado,
            decoration: _decoracaoCampo(
              label: 'Status',
              icone: Icons.toggle_on_outlined,
            ),
            items: const [
              DropdownMenuItem(value: 'ATIVO', child: Text('Ativo')),
              DropdownMenuItem(value: 'INATIVO', child: Text('Inativo')),
            ],
            onChanged: _salvando
                ? null
                : (value) {
                    if (value == null) return;

                    setState(() {
                      _statusSelecionado = value;
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _cardDesconto() {
    return ClubbarCard(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Promoção',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Configure um desconto opcional para este produto.',
            style: TextStyle(
              fontSize: 13,
              color: ClubbarColors.textoSecundario,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _tipoDescontoSelecionado,
            decoration: _decoracaoCampo(
              label: 'Tipo de desconto',
              icone: Icons.sell_outlined,
            ),
            items: const [
              DropdownMenuItem(value: 'NENHUM', child: Text('Sem desconto')),
              DropdownMenuItem(value: 'PERCENTUAL', child: Text('Percentual')),
              DropdownMenuItem(value: 'VALOR', child: Text('Valor em reais')),
            ],
            onChanged: _salvando
                ? null
                : (value) {
                    if (value == null) return;

                    setState(() {
                      _tipoDescontoSelecionado = value;

                      if (value == 'NENHUM') {
                        _vrDescontoController.text = '0';
                        _dtIniDescontoController.clear();
                        _dtFimDescontoController.clear();
                      }
                    });
                  },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _vrDescontoController,
            enabled: _descontoAtivo,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoracaoCampo(
              label: _tipoDescontoSelecionado == 'PERCENTUAL'
                  ? 'Desconto (%)'
                  : 'Desconto (R\$)',
              icone: _tipoDescontoSelecionado == 'PERCENTUAL'
                  ? Icons.percent_rounded
                  : Icons.attach_money_rounded,
              hint: '0,00',
            ),
            validator: (value) {
              if (!_descontoAtivo) return null;

              final numero = _numero(value ?? '');

              if (numero <= 0) {
                return 'Informe um desconto válido';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _dtIniDescontoController,
            enabled: _descontoAtivo,
            readOnly: true,
            decoration: _decoracaoCampo(
              label: 'Início da promoção',
              icone: Icons.calendar_today_outlined,
              suffixIcon: const Icon(Icons.schedule_rounded),
            ),
            onTap: _descontoAtivo
                ? () => _selecionarDataHora(_dtIniDescontoController)
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _dtFimDescontoController,
            enabled: _descontoAtivo,
            readOnly: true,
            decoration: _decoracaoCampo(
              label: 'Fim da promoção',
              icone: Icons.event_available_outlined,
              suffixIcon: const Icon(Icons.schedule_rounded),
            ),
            onTap: _descontoAtivo
                ? () => _selecionarDataHora(_dtFimDescontoController)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _cardResumo() {
    final descontoTexto = _tipoDescontoSelecionado == 'PERCENTUAL'
        ? '${_valorDesconto.toStringAsFixed(2)}%'
        : _moeda(_valorDesconto);

    return ClubbarCard(
      elevation: 1,
      backgroundColor: ClubbarColors.avisoClaro,
      borderColor: ClubbarColors.ambar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                color: ClubbarColors.ambarEscuro,
              ),
              SizedBox(width: 9),
              Text(
                'Resumo do preço',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _linhaResumo(titulo: 'Preço original', valor: _moeda(_precoOriginal)),
          const SizedBox(height: 10),
          _linhaResumo(
            titulo: 'Desconto',
            valor: _descontoAtivo ? descontoTexto : 'Sem desconto',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1, color: ClubbarColors.ambar),
          ),
          _linhaResumo(
            titulo: 'Preço final',
            valor: _moeda(_precoFinal),
            destaque: true,
          ),
        ],
      ),
    );
  }

  Widget _linhaResumo({
    required String titulo,
    required String valor,
    bool destaque = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: TextStyle(
              fontSize: destaque ? 15 : 14,
              fontWeight: destaque ? FontWeight.w900 : FontWeight.w600,
              color: ClubbarColors.textoSecundario,
            ),
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: destaque ? 21 : 15,
            fontWeight: FontWeight.w900,
            color: destaque
                ? ClubbarColors.sucesso
                : ClubbarColors.textoPrincipal,
          ),
        ),
      ],
    );
  }

  Widget _botaoSalvar() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _salvando ? null : _salvar,
        icon: _salvando
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ClubbarColors.preto,
                ),
              )
            : const Icon(Icons.save_rounded),
        label: Text(
          _salvando
              ? 'Salvando...'
              : editando
              ? 'Salvar alterações'
              : 'Cadastrar produto',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: ClubbarColors.ambar,
          foregroundColor: ClubbarColors.preto,
          disabledBackgroundColor: ClubbarColors.ambarClaro,
          disabledForegroundColor: ClubbarColors.textoSecundario,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
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
              titulo: editando ? 'Editar Produto' : 'Novo Produto',
              subtitulo: editando
                  ? 'Atualize os dados do produto'
                  : 'Cadastre um item no cardápio',
              icone: Icons.inventory_2_rounded,
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                  children: [
                    _cardImagem(),
                    const SizedBox(height: 16),
                    _cardDados(),
                    const SizedBox(height: 16),
                    _cardDesconto(),
                    const SizedBox(height: 16),
                    _cardResumo(),
                    const SizedBox(height: 20),
                    _botaoSalvar(),
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
