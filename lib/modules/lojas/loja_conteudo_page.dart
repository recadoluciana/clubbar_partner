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
  bool _loading = true, _saving = false;
  List<Map<String, dynamic>> _fotos = [], _videos = [], _posts = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _descricao.dispose();
    _video.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final x = await _repo.conteudo(widget.loja.lojaId);
      if (!mounted) return;
      setState(() {
        _descricao.text = x['dsdetalhadaloja']?.toString() ?? '';
        _fotos = _list(x['fotos']);
        _videos = _list(x['videos']);
        _posts = _list(x['publicacoes']);
        _loading = false;
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
      }
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, e.toString());
    }
  }

  void _addVideo() {
    final url = _video.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _videos.add({'titulo': 'Vídeo do estabelecimento', 'url': url});
      _video.clear();
    });
  }

  Future<void> _post() async {
    final titulo = TextEditingController(),
        desc = TextEditingController(),
        imagem = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nova publicação'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titulo,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: desc,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
            TextField(
              controller: imagem,
              decoration: const InputDecoration(
                labelText: 'URL da imagem (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (ok == true && titulo.text.trim().isNotEmpty) {
      setState(
        () => _posts.add({
          'titulo': titulo.text.trim(),
          'descricao': desc.text.trim(),
          'imagem': imagem.text.trim(),
          'data_publicacao': DateTime.now().toIso8601String().substring(0, 10),
        }),
      );
    }
    titulo.dispose();
    desc.dispose();
    imagem.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repo.salvarConteudo(widget.loja.lojaId, {
        'dsdetalhadaloja': _descricao.text.trim(),
        'fotos': _fotos,
        'videos': _videos,
        'publicacoes': _posts,
        'configuracoes': {
          'mostrar_galeria': true,
          'mostrar_videos': true,
          'mostrar_publicacoes': true,
        },
      });
      if (mounted) {
        AppSnackBar.sucesso(context, 'Conteúdo salvo.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Limpar conteúdo?'),
        content: const Text(
          'A descrição, galeria, vídeos e publicações serão removidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _repo.excluirConteudo(widget.loja.lojaId);
      if (mounted) Navigator.pop(context, true);
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
              color: Colors.blue,
              fontSize: 23,
              fontWeight: FontWeight.w900,
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
                              onPressed: () =>
                                  setState(() => _fotos.removeAt(e.key)),
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
                              onPressed: () =>
                                  setState(() => _videos.removeAt(e.key)),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        ),
                      ]),
                      _card('Publicações', [
                        OutlinedButton.icon(
                          onPressed: _post,
                          icon: const Icon(Icons.post_add),
                          label: const Text('Nova publicação'),
                        ),
                        ..._posts.asMap().entries.map((e) {
                          final imagem = (e.value['imagem'] ?? '')
                              .toString()
                              .trim();
                          return Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(color: ClubbarColors.borda),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (imagem.isNotEmpty) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      _url(imagem),
                                      width: double.infinity,
                                      height: 180,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (
                                            context,
                                            error,
                                            stackTrace,
                                          ) => Container(
                                            height: 90,
                                            color: ClubbarColors.fundo,
                                            alignment: Alignment.center,
                                            child: const Text(
                                              'Não foi possível carregar a imagem deste link.',
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            e.value['titulo']?.toString() ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if ((e.value['descricao'] ?? '')
                                              .toString()
                                              .trim()
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              e.value['descricao'].toString(),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => setState(
                                        () => _posts.removeAt(e.key),
                                      ),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ]),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: const Icon(Icons.save),
                              label: Text(
                                _saving ? 'Salvando...' : 'Salvar conteúdo',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _delete,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Limpar conteúdo'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ClubbarColors.erro,
                                side: const BorderSide(
                                  color: ClubbarColors.erro,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
