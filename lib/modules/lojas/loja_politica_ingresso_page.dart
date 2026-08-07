import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/api_config.dart';
import '../../core/repositories/loja_perfil_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';

class LojaPoliticaIngressoPage extends StatefulWidget {
  final Loja loja;
  const LojaPoliticaIngressoPage({super.key, required this.loja});
  @override
  State<LojaPoliticaIngressoPage> createState() =>
      _LojaPoliticaIngressoPageState();
}

class _LojaPoliticaIngressoPageState extends State<LojaPoliticaIngressoPage> {
  final _repo = LojaPerfilRepository(),
      _politica = TextEditingController(),
      _mapaDesc = TextEditingController(),
      _acesso = TextEditingController();
  String? _mapa;
  bool _loading = true,
      _saving = false,
      _permiteTransferencia = false,
      _exigeDocumento = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _politica.dispose();
    _mapaDesc.dispose();
    _acesso.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final x = await _repo.politica(widget.loja.lojaId);
      final cfg = Map<String, dynamic>.from(x['configuracoes'] as Map? ?? {});
      if (!mounted) return;
      setState(() {
        _politica.text = x['dspoliticaingresso']?.toString() ?? '';
        _mapa = x['urlmapaingressos']?.toString();
        _mapaDesc.text = x['dsmapaingressos']?.toString() ?? '';
        _acesso.text = x['dsorientacoesacesso']?.toString() ?? '';
        _permiteTransferencia = cfg['permite_transferencia'] == true;
        _exigeDocumento = cfg['exige_documento'] != false;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnackBar.erro(context, e.toString());
      }
    }
  }

  String _url(String x) => x.startsWith('http')
      ? x
      : '${ApiConfig.baseUrl}${x.startsWith('/') ? '' : '/'}$x';
  Future<void> _uploadMapa() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1800,
    );
    if (x == null) return;
    try {
      final u = await _repo.upload(widget.loja.lojaId, x);
      if (mounted) setState(() => _mapa = u);
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, e.toString());
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repo.salvarPolitica(widget.loja.lojaId, {
        'dspoliticaingresso': _politica.text.trim(),
        'urlmapaingressos': _mapa,
        'dsmapaingressos': _mapaDesc.text.trim(),
        'dsorientacoesacesso': _acesso.text.trim(),
        'configuracoes': {
          'permite_transferencia': _permiteTransferencia,
          'exige_documento': _exigeDocumento,
        },
      });
      if (mounted) {
        AppSnackBar.sucesso(context, 'Política salva.');
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
        title: const Text('Excluir política?'),
        content: const Text(
          'Todas as regras e o mapa de ingressos serão removidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _repo.excluirPolitica(widget.loja.lojaId);
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
            titulo: 'Política de Ingressos',
            subtitulo: widget.loja.nmloja,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _campo(
                        _politica,
                        'Política de venda, cancelamento e reembolso',
                        6,
                      ),
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Mapa dos ingressos e setores',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (_mapa?.isNotEmpty == true)
                                Image.network(
                                  _url(_mapa!),
                                  height: 210,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const SizedBox(),
                                ),
                              OutlinedButton.icon(
                                onPressed: _uploadMapa,
                                icon: const Icon(Icons.map),
                                label: Text(
                                  _mapa == null
                                      ? 'Adicionar mapa'
                                      : 'Substituir mapa',
                                ),
                              ),
                              const SizedBox(height: 8),
                              _campo(
                                _mapaDesc,
                                'Descrição dos setores, mesas ou áreas',
                                3,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _campo(_acesso, 'Orientações de entrada e acesso', 4),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        value: _permiteTransferencia,
                        onChanged: (v) =>
                            setState(() => _permiteTransferencia = v),
                        title: const Text('Permitir transferência de ingresso'),
                      ),
                      SwitchListTile(
                        value: _exigeDocumento,
                        onChanged: (v) => setState(() => _exigeDocumento = v),
                        title: const Text('Exigir documento na entrada'),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: Text(
                          _saving ? 'Salvando...' : 'Salvar política',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _delete,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: ClubbarColors.erro,
                        ),
                        label: const Text(
                          'Excluir política',
                          style: TextStyle(color: ClubbarColors.erro),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
  Widget _campo(TextEditingController c, String label, int lines) => TextField(
    controller: c,
    minLines: lines,
    maxLines: lines + 4,
    decoration: InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      filled: true,
      fillColor: ClubbarColors.branco,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
