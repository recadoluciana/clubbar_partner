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
  String? _fotoUrl;
  XFile? _fotoSelecionada;
  Uint8List? _fotoBytes;
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
    _fotoUrl = item['urlfotoproduto']?.toString();
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

  Future<void> _escolherFotoPadronizada() async {
    final busca = TextEditingController(text: _nome.text.trim());
    var pesquisando = false;
    var importandoId = 0;
    var fotos = <Map<String, dynamic>>[];
    String? erro;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, atualizar) {
          Future<void> pesquisar() async {
            final termo = busca.text.trim();
            if (termo.length < 2) {
              atualizar(
                () => erro = 'Informe pelo menos dois caracteres para buscar.',
              );
              return;
            }
            atualizar(() {
              pesquisando = true;
              erro = null;
            });
            try {
              final resultado = await _repo.buscarFotosPadronizadasPixabay(
                widget.organizacaoId,
                termo,
              );
              if (dialogContext.mounted) {
                atualizar(() => fotos = resultado);
              }
            } catch (e) {
              if (dialogContext.mounted) {
                atualizar(
                  () => erro = e.toString().replaceFirst('Exception: ', ''),
                );
              }
            } finally {
              if (dialogContext.mounted) {
                atualizar(() => pesquisando = false);
              }
            }
          }

          Future<void> selecionar(Map<String, dynamic> foto) async {
            final fotoId = int.tryParse('${foto['foto_id']}');
            if (fotoId == null) return;
            atualizar(() {
              importandoId = fotoId;
              erro = null;
            });
            try {
              final url = await _repo.importarFotoPadronizadaPixabay(
                widget.organizacaoId,
                fotoId,
              );
              if (!mounted) return;
              setState(() {
                _fotoUrl = url;
                _fotoSelecionada = null;
                _fotoBytes = null;
              });
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (e) {
              if (dialogContext.mounted) {
                atualizar(
                  () => erro = e.toString().replaceFirst('Exception: ', ''),
                );
              }
            } finally {
              if (dialogContext.mounted) {
                atualizar(() => importandoId = 0);
              }
            }
          }

          return AlertDialog(
            title: const Text('Escolher foto padronizada'),
            content: SizedBox(
              width: 680,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: busca,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => pesquisar(),
                          decoration: const InputDecoration(
                            labelText: 'Buscar foto',
                            hintText: 'Ex.: cerveja, água com gás, caipirinha',
                            prefixIcon: Icon(Icons.search_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: pesquisando ? null : pesquisar,
                        child: const Text('Buscar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Fotos fornecidas por Pixabay. Escolha uma imagem para copiá-la ao Clubbar.',
                    style: TextStyle(
                      color: ClubbarColors.textoSecundario,
                      fontSize: 12,
                    ),
                  ),
                  if (erro != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      erro!,
                      style: const TextStyle(color: ClubbarColors.erro),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 330,
                    child: pesquisando
                        ? const Center(child: CircularProgressIndicator())
                        : fotos.isEmpty
                        ? const Center(
                            child: Text(
                              'Pesquise pelo nome do produto para ver as fotos disponíveis.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: .82,
                                ),
                            itemCount: fotos.length,
                            itemBuilder: (context, indice) {
                              final foto = fotos[indice];
                              final fotoId = int.tryParse('${foto['foto_id']}');
                              final importando = fotoId == importandoId;
                              return InkWell(
                                onTap: importando
                                    ? null
                                    : () => selecionar(foto),
                                borderRadius: BorderRadius.circular(10),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: ClubbarColors.borda,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(9),
                                              ),
                                          child: Image.network(
                                            '${foto['preview_url']}',
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                const Center(
                                                  child: Icon(
                                                    Icons.broken_image_outlined,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: importando
                                            ? const SizedBox.square(
                                                dimension: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : Text(
                                                'Por ${foto['autor']}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: ClubbarColors
                                                      .textoSecundario,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      ),
    );
    busca.dispose();
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
      if (_fotoSelecionada != null) {
        _fotoUrl = await _repo.enviarFotoProdutoPadraoOrganizacao(
          widget.organizacaoId,
          _fotoSelecionada!,
        );
      }
      final dados = <String, dynamic>{
        'nmproduto': _nome.text.trim(),
        'dsproduto': _descricao.text.trim().isEmpty
            ? null
            : _descricao.text.trim(),
        'vrprecopadrao': precoPadrao,
        'sitproduto': _situacao,
        if (widget.item != null) 'skuproduto': widget.item!['skuproduto'],
        'urlfotoproduto': _fotoUrl,
      };
      if (widget.item == null) {
        await _repo.criarProdutoPadraoOrganizacao(widget.organizacaoId, dados);
      } else {
        await _repo.alterarProdutoPadraoOrganizacao(
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
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _selecionarFoto,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Foto do aparelho'),
                          ),
                          FilledButton.icon(
                            onPressed: _escolherFotoPadronizada,
                            icon: const Icon(Icons.image_search_rounded),
                            label: const Text('Fotos padronizadas'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
