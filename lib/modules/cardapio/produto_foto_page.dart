import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/api_config.dart';
import '../../core/repositories/cardapio_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_action_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';

class ProdutoFotoPage extends StatefulWidget {
  final int organizacaoId;
  final String nomeOrganizacao;
  final Map<String, dynamic> item;
  const ProdutoFotoPage({
    super.key,
    required this.organizacaoId,
    required this.nomeOrganizacao,
    required this.item,
  });
  @override
  State<ProdutoFotoPage> createState() => _ProdutoFotoPageState();
}

class _ProdutoFotoPageState extends State<ProdutoFotoPage> {
  final _repo = CardapioRepository();
  late final TextEditingController _nome;
  String? _fotoUrl;
  XFile? _fotoSelecionada;
  Uint8List? _fotoBytes;
  bool _salvando = false;
  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: '${widget.item['nmproduto'] ?? ''}');
    _fotoUrl = widget.item['urlfotoproduto']?.toString();
  }

  @override
  void dispose() {
    _nome.dispose();
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

  Future<void> _salvar() async {
    if (_salvando) return;
    setState(() => _salvando = true);
    try {
      final foto = _fotoSelecionada;
      final url = foto == null
          ? _fotoUrl
          : await _repo.enviarFotoProdutoPadraoOrganizacao(
              widget.organizacaoId,
              foto,
            );
      await _repo.alterarFotoProdutoPadraoOrganizacao(
        widget.organizacaoId,
        int.parse('${widget.item['produto_id']}'),
        url,
      );
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
          titulo: 'Foto do produto',
          subtitulo: widget.nomeOrganizacao,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(_nome.text, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              InkWell(
                onTap: _salvando ? null : _selecionarFoto,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 260,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: ClubbarColors.textoSecundario),
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
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.image_not_supported_outlined),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 44),
                            SizedBox(height: 8),
                            Text('Toque para escolher a foto do produto'),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _salvando ? null : _selecionarFoto,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Foto do aparelho'),
                  ),
                  FilledButton.icon(
                    onPressed: _salvando ? null : _escolherFotoPadronizada,
                    icon: const Icon(Icons.image_search_rounded),
                    label: const Text('Fotos padronizadas'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'A foto será usada em todos os cardápios que incluírem este produto.',
                style: TextStyle(color: ClubbarColors.textoSecundario),
              ),
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: ClubbarActionBar(
      actions: [
        FilledButton.icon(
          onPressed: _salvando ? null : _salvar,
          icon: _salvando
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Salvar foto'),
        ),
      ],
    ),
  );
}
