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
  late final TextEditingController _nome, _estilo, _descricao;
  XFile? _banner;
  bool _salvando = false;
  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: widget.atracao?.nome);
    _estilo = TextEditingController(text: widget.atracao?.estiloMusical);
    _descricao = TextEditingController(text: widget.atracao?.descricao);
  }

  @override
  void dispose() {
    _nome.dispose();
    _estilo.dispose();
    _descricao.dispose();
    super.dispose();
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
    setState(() => _salvando = true);
    try {
      await _repo.salvar(
        atracao: widget.atracao,
        nome: _nome.text.trim(),
        estilo: _estilo.text.trim(),
        descricao: _descricao.text.trim(),
        banner: _banner,
      );
      if (!mounted) return;
      AppSnackBar.sucesso(context, 'Atração salva com sucesso.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
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
                          child: Container(
                            height: 210,
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
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            child: Image.memory(
                                              s.data!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                  )
                                : _url != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Image.network(
                                      _url!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _placeholder(),
                                    ),
                                  )
                                : _placeholder(),
                          ),
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
                          controller: _estilo,
                          decoration: _dec(
                            'Estilo musical',
                            Icons.music_note_rounded,
                            hint: 'Rock, samba, eletrônico...',
                          ),
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
