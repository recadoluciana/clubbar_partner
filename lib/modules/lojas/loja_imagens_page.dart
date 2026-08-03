import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';

class LojaImagensPage extends StatefulWidget {
  final Loja loja;

  const LojaImagensPage({super.key, required this.loja});

  @override
  State<LojaImagensPage> createState() => _LojaImagensPageState();
}

class _LojaImagensPageState extends State<LojaImagensPage> {
  final _repository = LojaRepository();
  final _picker = ImagePicker();

  XFile? _logo;
  Uint8List? _logoBytes;
  XFile? _fachada;
  Uint8List? _fachadaBytes;
  bool _salvando = false;
  bool _carregandoOrganizacao = true;
  String _nomeOrganizacao = 'Organização não identificada';

  bool get _possuiAlteracao => _logo != null || _fachada != null;

  @override
  void initState() {
    super.initState();
    _carregarNomeOrganizacao();
  }

  Future<void> _carregarNomeOrganizacao() async {
    final nome = (await StorageService.getNomeOrganizacao() ?? '').trim();
    if (!mounted) return;
    setState(() {
      _nomeOrganizacao = nome.isEmpty ? 'Organização não identificada' : nome;
      _carregandoOrganizacao = false;
    });
  }

  String _url(String? caminho) => ApiConfig.buildUrl(caminho ?? '');

  Future<void> _selecionar({required bool logo}) async {
    try {
      final arquivo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (arquivo == null) return;
      final bytes = await arquivo.readAsBytes();
      if (!mounted) return;

      setState(() {
        if (logo) {
          _logo = arquivo;
          _logoBytes = bytes;
        } else {
          _fachada = arquivo;
          _fachadaBytes = bytes;
        }
      });
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, 'Erro ao selecionar imagem: $e');
    }
  }

  Future<void> _salvar() async {
    if (_salvando || !_possuiAlteracao) return;

    setState(() => _salvando = true);
    try {
      await _repository.atualizarImagens(
        loja: widget.loja,
        logo: _logo,
        fachada: _fachada,
      );
      if (!mounted) return;
      AppSnackBar.sucesso(context, 'Imagens da loja atualizadas com sucesso.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, 'Erro ao salvar imagens: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _imagem({
    required Uint8List? bytes,
    required String url,
    required IconData fallback,
  }) {
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.contain);
    }
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(fallback, size: 52),
      );
    }
    return Icon(fallback, size: 52, color: ClubbarColors.textoSecundario);
  }

  Widget _previewCliente() {
    final fachadaUrl = _url(widget.loja.urlfachadaloja);
    final logoUrl = _url(widget.loja.urllogoloja);

    return ClubbarCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: ClubbarColors.preto,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _imagem(
                bytes: _fachadaBytes,
                url: fachadaUrl,
                fallback: Icons.storefront_outlined,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -38),
            child: Column(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: ClubbarColors.branco,
                    shape: BoxShape.circle,
                    border: Border.all(color: ClubbarColors.ambar, width: 3),
                  ),
                  child: ClipOval(
                    child: ColoredBox(
                      color: ClubbarColors.branco,
                      child: _imagem(
                        bytes: _logoBytes,
                        url: logoUrl,
                        fallback: Icons.store_rounded,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.loja.nmloja,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if ((widget.loja.dsestiloloja ?? '').trim().isNotEmpty)
                  Text(
                    widget.loja.dsestiloloja!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ClubbarColors.textoSecundario,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _botaoImagem({
    required String titulo,
    required String subtitulo,
    required IconData icone,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: _salvando ? null : onPressed,
      icon: Icon(icone),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(subtitulo, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: ClubbarColors.textoPrincipal,
        side: const BorderSide(color: ClubbarColors.ambar),
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
              titulo: 'Imagens - ${widget.loja.nmloja}',
              subtitulo: _carregandoOrganizacao
                  ? 'Carregando organização...'
                  : _nomeOrganizacao,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Prévia no aplicativo do cliente',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'As imagens são exibidas inteiras nesta prévia, sem cortes.',
                    style: TextStyle(color: ClubbarColors.textoSecundario),
                  ),
                  const SizedBox(height: 12),
                  _previewCliente(),
                  const SizedBox(height: 16),
                  _botaoImagem(
                    titulo: 'Escolher logo da loja',
                    subtitulo: 'Prefira uma imagem quadrada com fundo limpo',
                    icone: Icons.image_outlined,
                    onPressed: () => _selecionar(logo: true),
                  ),
                  const SizedBox(height: 10),
                  _botaoImagem(
                    titulo: 'Escolher foto da fachada',
                    subtitulo: 'Prefira uma imagem horizontal e bem iluminada',
                    icone: Icons.add_photo_alternate_outlined,
                    onPressed: () => _selecionar(logo: false),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _salvando || !_possuiAlteracao ? null : _salvar,
                    icon: _salvando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _salvando
                          ? 'Salvando...'
                          : _possuiAlteracao
                          ? 'Salvar imagens'
                          : 'Nenhuma alteração',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: ClubbarColors.ambar,
                      foregroundColor: ClubbarColors.preto,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
