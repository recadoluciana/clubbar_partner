import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/api_config.dart';
import '../../core/repositories/atracao_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/atracao.dart';

class AtracaoFormPage extends StatefulWidget {
  final Atracao? atracao;
  const AtracaoFormPage({super.key, this.atracao});
  @override
  State<AtracaoFormPage> createState() => _AtracaoFormPageState();
}

class _AtracaoFormPageState extends State<AtracaoFormPage> {
  final _repo = AtracaoRepository();
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nome, _descricao;
  late final TextEditingController _instagram,
      _telefone,
      _videoInstagram,
      _videoYoutube;
  XFile? _banner;
  XFile? _foto2, _foto3;
  bool _removerFoto2 = false, _removerFoto3 = false;
  bool _salvando = false, _carregandoEstilos = true;
  List<EstiloMusical> _estilos = [];
  final Set<int> _estilosSelecionados = {};
  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: widget.atracao?.nome);
    _descricao = TextEditingController(text: widget.atracao?.descricao);
    _instagram = TextEditingController(text: widget.atracao?.instagram);
    _telefone = TextEditingController(text: widget.atracao?.telefoneContato);
    _videoInstagram = TextEditingController(
      text: widget.atracao?.videoInstagram,
    );
    _videoYoutube = TextEditingController(text: widget.atracao?.videoYoutube);
    _estilosSelecionados.addAll(widget.atracao?.estilos.map((e) => e.id) ?? []);
    _carregarEstilos();
  }

  @override
  void dispose() {
    _nome.dispose();
    _descricao.dispose();
    _instagram.dispose();
    _telefone.dispose();
    _videoInstagram.dispose();
    _videoYoutube.dispose();
    super.dispose();
  }

  Future<void> _carregarEstilos() async {
    try {
      final estilos = await _repo.listarEstilos();
      if (mounted) setState(() => _estilos = estilos);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregandoEstilos = false);
    }
  }

  Future<void> _imagem() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (x != null && mounted) setState(() => _banner = x);
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate() || _salvando) return;
    if (_estilosSelecionados.isEmpty) {
      AppSnackBar.aviso(context, 'Selecione pelo menos um estilo musical.');
      return;
    }
    setState(() => _salvando = true);
    try {
      await _repo.salvar(
        atracao: widget.atracao,
        nome: _nome.text.trim(),
        estilosIds: _estilosSelecionados.toList(),
        descricao: _descricao.text.trim(),
        banner: _banner,
        foto2: _foto2,
        foto3: _foto3,
        dadosExtras: {
          'instagram': _instagram.text.trim(),
          'telefone_contato': _telefone.text.trim(),
          'video_instagram': _videoInstagram.text.trim(),
          'video_youtube': _videoYoutube.text.trim(),
          'remover_foto2': _removerFoto2,
          'remover_foto3': _removerFoto3,
        },
      );
      if (!mounted) return;
      AppSnackBar.sucesso(context, 'Atração salva com sucesso.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  String? get _url {
    final b = widget.atracao?.banner?.trim() ?? '';
    if (b.isEmpty) return null;
    return b.startsWith('http')
        ? b
        : '${ApiConfig.baseUrl}${b.startsWith('/') ? '' : '/'}$b';
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
              titulo: widget.atracao == null
                  ? 'Nova Atração'
                  : 'Editar Atração',
              subtitulo: 'Artista, banda, DJ ou apresentação',
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Form(
                    key: _form,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        InkWell(
                          onTap: _imagem,
                          borderRadius: BorderRadius.circular(18),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Container(
                              decoration: BoxDecoration(
                                color: ClubbarColors.branco,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: ClubbarColors.borda),
                              ),
                              child: _banner != null
                                  ? FutureBuilder(
                                      future: _banner!.readAsBytes(),
                                      builder: (c, s) => s.hasData
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              child: Image.memory(
                                                s.data!,
                                                width: double.infinity,
                                                height: double.infinity,
                                                fit: BoxFit.contain,
                                              ),
                                            )
                                          : const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                    )
                                  : _url != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: Image.network(
                                        _url!,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) =>
                                            _placeholder(),
                                      ),
                                    )
                                  : _placeholder(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Fotos adicionais (até 3 fotos no total)'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _fotoAdicional(2)),
                            const SizedBox(width: 12),
                            Expanded(child: _fotoAdicional(3)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nome,
                          decoration: _dec(
                            'Nome da atração',
                            Icons.mic_rounded,
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Informe o nome da atração.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _instagram,
                          decoration: _dec(
                            'Instagram da atração',
                            Icons.alternate_email,
                            hint: '@perfil',
                          ),
                          maxLength: 255,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _telefone,
                          decoration: _dec(
                            'Telefone para contratar show',
                            Icons.phone,
                          ),
                          keyboardType: TextInputType.phone,
                          maxLength: 30,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _videoInstagram,
                          decoration: _dec(
                            'Link de vídeo do Instagram',
                            Icons.play_circle_outline,
                          ),
                          keyboardType: TextInputType.url,
                          maxLength: 500,
                          validator: (v) => _validarVideo(v, true),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _videoYoutube,
                          decoration: _dec(
                            'Link de vídeo do YouTube',
                            Icons.play_circle_outline,
                          ),
                          keyboardType: TextInputType.url,
                          maxLength: 500,
                          validator: (v) => _validarVideo(v, false),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descricao,
                          minLines: 4,
                          maxLines: 8,
                          decoration: _dec(
                            'Descrição da atração',
                            Icons.description_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: ClubbarColors.branco,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ClubbarColors.borda),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.music_note_rounded),
                                  SizedBox(width: 9),
                                  Text(
                                    'Estilos musicais',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Selecione um ou vários estilos.',
                                style: TextStyle(
                                  color: ClubbarColors.textoSecundario,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_carregandoEstilos)
                                const Center(child: CircularProgressIndicator())
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _estilos.map((estilo) {
                                    final selecionado = _estilosSelecionados
                                        .contains(estilo.id);
                                    return FilterChip(
                                      label: Text(estilo.nome),
                                      selected: selecionado,
                                      selectedColor: ClubbarColors.ambarClaro,
                                      checkmarkColor: Colors.black,
                                      onSelected: (valor) => setState(() {
                                        if (valor) {
                                          _estilosSelecionados.add(estilo.id);
                                        } else {
                                          _estilosSelecionados.remove(
                                            estilo.id,
                                          );
                                        }
                                      }),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _salvando ? null : _salvar,
                          icon: _salvando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(
                            _salvando ? 'Salvando...' : 'Salvar atração',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validarVideo(String? valor, bool instagram) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return null;
    final uri = Uri.tryParse(texto);
    final dominio = uri?.host.toLowerCase() ?? '';
    final dominios = instagram
        ? ['instagram.com']
        : ['youtube.com', 'youtu.be'];
    if (uri?.scheme != 'https' ||
        !dominios.any((d) => dominio == d || dominio.endsWith('.$d'))) {
      return 'Informe um link HTTPS válido do ${instagram ? "Instagram" : "YouTube"}.';
    }
    return null;
  }

  Widget _fotoAdicional(int numero) {
    final arquivo = numero == 2 ? _foto2 : _foto3;
    final removida = numero == 2 ? _removerFoto2 : _removerFoto3;
    final caminho = removida
        ? null
        : (numero == 2 ? widget.atracao?.foto2 : widget.atracao?.foto3);
    final url = caminho == null || caminho.isEmpty
        ? null
        : (caminho.startsWith('http')
              ? caminho
              : '${ApiConfig.baseUrl}${caminho.startsWith('/') ? '' : '/'}$caminho');
    return Column(
      children: [
        InkWell(
          onTap: () async {
            final foto = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 88,
              maxWidth: 1600,
            );
            if (foto != null && mounted) {
              setState(() {
                if (numero == 2) {
                  _foto2 = foto;
                  _removerFoto2 = false;
                } else {
                  _foto3 = foto;
                  _removerFoto3 = false;
                }
              });
            }
          },
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: ClubbarColors.branco,
              border: Border.all(color: ClubbarColors.borda),
              borderRadius: BorderRadius.circular(12),
            ),
            child: arquivo != null
                ? FutureBuilder(
                    future: arquivo.readAsBytes(),
                    builder: (_, snapshot) => snapshot.hasData
                        ? Image.memory(snapshot.data!, fit: BoxFit.contain)
                        : const Center(child: CircularProgressIndicator()),
                  )
                : url != null
                ? Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined),
                      Text('Adicionar foto $numero'),
                    ],
                  ),
          ),
        ),
        if (arquivo != null || url != null)
          TextButton(
            onPressed: () => setState(() {
              if (numero == 2) {
                _foto2 = null;
                _removerFoto2 = true;
              } else {
                _foto3 = null;
                _removerFoto3 = true;
              }
            }),
            child: const Text('Remover'),
          ),
      ],
    );
  }

  Widget _placeholder() => const Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.add_photo_alternate_rounded,
        size: 50,
        color: ClubbarColors.ambarEscuro,
      ),
      SizedBox(height: 8),
      Text('Selecionar banner', style: TextStyle(fontWeight: FontWeight.w800)),
    ],
  );
  InputDecoration _dec(String label, IconData icon, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: ClubbarColors.branco,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      );
}
