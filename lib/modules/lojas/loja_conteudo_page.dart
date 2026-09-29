import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/api_config.dart';
import '../../core/repositories/loja_perfil_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';

class LojaConteudoPage extends StatefulWidget {
  final Loja loja;
  const LojaConteudoPage({super.key, required this.loja});
  @override
  State<LojaConteudoPage> createState() => _LojaConteudoPageState();
}

class _LojaConteudoPageState extends State<LojaConteudoPage> {
  final _repo = LojaPerfilRepository(),
      _descricao = TextEditingController(),
      _video = TextEditingController();
  bool _loading = true, _saving = false, _dadosCarregados = false;
  bool _salvamentoPendente = false;
  Timer? _descricaoTimer;
  List<Map<String, dynamic>> _fotos = [], _videos = [];
  @override
  void initState() {
    super.initState();
    _descricao.addListener(_descricaoAlterada);
    _load();
  }

  @override
  void dispose() {
    _descricaoTimer?.cancel();
    _descricao.removeListener(_descricaoAlterada);
    _descricao.dispose();
    _video.dispose();
    super.dispose();
  }

  void _descricaoAlterada() {
    if (!_dadosCarregados) return;
    _descricaoTimer?.cancel();
    _descricaoTimer = Timer(const Duration(milliseconds: 800), _salvar);
  }

  Future<void> _load() async {
    try {
      final x = await _repo.conteudo(widget.loja.lojaId);
      if (!mounted) return;
      setState(() {
        _descricao.text = x['dsdetalhadaloja']?.toString() ?? '';
        _fotos = _list(x['fotos']);
        _videos = _list(x['videos']);
        _loading = false;
        _dadosCarregados = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnackBar.erro(context, e.toString());
      }
    }
  }

  List<Map<String, dynamic>> _list(dynamic x) => (x as List? ?? const [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  String _url(String x) => x.startsWith('http')
      ? x
      : '${ApiConfig.baseUrl}${x.startsWith('/') ? '' : '/'}$x';
  Future<void> _foto() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (x == null) return;
    try {
      final url = await _repo.upload(widget.loja.lojaId, x);
      if (mounted) {
        setState(
          () => _fotos.add({
            'titulo': 'Foto do estabelecimento',
            'url': url,
            'ordem': _fotos.length + 1,
          }),
        );
        await _salvar();
      }
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, e.toString());
    }
  }

  Future<void> _addVideo() async {
    final url = _video.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _videos.add({'titulo': 'Vídeo do estabelecimento', 'url': url});
      _video.clear();
    });
    await _salvar();
  }

  Future<void> _salvar() async {
    _salvamentoPendente = true;
    if (_saving) return;
    while (_salvamentoPendente && mounted) {
      _salvamentoPendente = false;
      setState(() => _saving = true);
      try {
        await _repo.salvarConteudo(widget.loja.lojaId, {
          'dsdetalhadaloja': _descricao.text.trim(),
          'fotos': _fotos,
          'videos': _videos,
          'configuracoes': {'mostrar_galeria': true, 'mostrar_videos': true},
        });
      } catch (e) {
        _salvamentoPendente = false;
        if (mounted) AppSnackBar.erro(context, e.toString());
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  Future<void> _removerFoto(int indice) async {
    setState(() => _fotos.removeAt(indice));
    await _salvar();
  }

  Future<void> _removerVideo(int indice) async {
    setState(() => _videos.removeAt(indice));
    await _salvar();
  }

  Future<void> _limparConteudo() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar todo o conteúdo?'),
        content: const Text(
          'Esta ação removerá a descrição, todas as fotos e vídeos do estabelecimento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Limpar tudo'),
            style: FilledButton.styleFrom(backgroundColor: ClubbarColors.erro),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    try {
      await _repo.excluirConteudo(widget.loja.lojaId);
      if (!mounted) return;
      _dadosCarregados = false;
      setState(() {
        _descricao.clear();
        _fotos = [];
        _videos = [];
        _dadosCarregados = true;
      });
      AppSnackBar.sucesso(context, 'Conteúdo do estabelecimento removido.');
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: SafeArea(
      child: Column(
        children: [
          ClubbarPageHeader(
            titulo: widget.loja.nmloja,
            subtitulo: 'Conteúdo do estabelecimento',
            tituloStyle: const TextStyle(
              color: ClubbarColors.primariaEscuro,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
            trailing: _saving
                ? const SizedBox(
                    width: 34,
                    height: 34,
                    child: Padding(
                      padding: EdgeInsets.all(7),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Limpar todo o conteúdo',
                    onPressed: _limparConteudo,
                    icon: const Icon(
                      Icons.delete_sweep_outlined,
                      color: ClubbarColors.erro,
                    ),
                  ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _card('Sobre o estabelecimento', [
                        TextField(
                          controller: _descricao,
                          minLines: 5,
                          maxLines: 12,
                          decoration: const InputDecoration(
                            hintText:
                                'Conte a história, estrutura e diferenciais do estabelecimento.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ]),
                      _card('Galeria de fotos', [
                        OutlinedButton.icon(
                          onPressed: _foto,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Adicionar foto'),
                        ),
                        const SizedBox(height: 8),
                        if (_fotos.isEmpty)
                          const Text('Nenhuma foto adicionada.'),
                        ..._fotos.asMap().entries.map(
                          (e) => ListTile(
                            leading: Image.network(
                              _url(e.value['url'].toString()),
                              width: 55,
                              height: 45,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image),
                            ),
                            title: Text(
                              e.value['titulo']?.toString() ?? 'Foto',
                            ),
                            trailing: IconButton(
                              onPressed: () => _removerFoto(e.key),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        ),
                      ]),
                      _card('Vídeos', [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _video,
                                decoration: const InputDecoration(
                                  labelText:
                                      'URL do YouTube, Instagram ou Vimeo',
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _addVideo,
                              icon: const Icon(Icons.add_circle),
                            ),
                          ],
                        ),
                        ..._videos.asMap().entries.map(
                          (e) => ListTile(
                            leading: const Icon(Icons.play_circle),
                            title: Text(e.value['url'].toString()),
                            trailing: IconButton(
                              onPressed: () => _removerVideo(e.key),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
  Widget _card(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}
