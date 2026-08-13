import 'package:flutter/material.dart';
import '../../core/config/api_config.dart';
import '../../core/repositories/atracao_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/atracao.dart';
import 'atracao_form_page.dart';

class AtracaoListPage extends StatefulWidget {
  const AtracaoListPage({super.key});
  @override
  State<AtracaoListPage> createState() => _AtracaoListPageState();
}

class _AtracaoListPageState extends State<AtracaoListPage> {
  final _repo = AtracaoRepository();
  bool _loading = true;
  String? _erro;
  List<Atracao> _itens = [];
  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      final x = await _repo.listar();
      if (mounted) {
        setState(() {
          _itens = x;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _form([Atracao? a]) async {
    if (await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => AtracaoFormPage(atracao: a)),
        ) ==
        true) {
      _carregar();
    }
  }

  Future<void> _excluir(Atracao a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir atração?'),
        content: Text('Deseja excluir ${a.nome}?'),
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
    if (ok != true) return;
    try {
      await _repo.excluir(a.atracaoId);
      if (mounted) {
        AppSnackBar.sucesso(context, 'Atração excluída.');
        _carregar();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  String? _url(Atracao a) {
    final b = a.banner?.trim() ?? '';
    if (b.isEmpty) return null;
    return b.startsWith('http')
        ? b
        : '${ApiConfig.baseUrl}${b.startsWith('/') ? '' : '/'}$b';
  }

  @override
  Widget build(BuildContext context) {
    Widget conteudo;
    if (_loading) {
      conteudo = const Center(child: CircularProgressIndicator());
    } else if (_erro != null) {
      conteudo = ListView(
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.error_outline, size: 48, color: ClubbarColors.erro),
          Center(child: Text(_erro!)),
          TextButton(
            onPressed: _carregar,
            child: const Text('Tentar novamente'),
          ),
        ],
      );
    } else if (_itens.isEmpty) {
      conteudo = ListView(
        children: const [
          SizedBox(height: 100),
          Icon(
            Icons.mic_none_rounded,
            size: 64,
            color: ClubbarColors.textoSecundario,
          ),
          Center(child: Text('Nenhuma atração cadastrada.')),
        ],
      );
    } else {
      conteudo = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: _itens.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (c, i) {
          final a = _itens[i];
          final u = _url(a);
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(10),
              leading: CircleAvatar(
                radius: 30,
                backgroundColor: ClubbarColors.ambarClaro,
                backgroundImage: u == null ? null : NetworkImage(u),
                child: u == null ? const Icon(Icons.mic_rounded) : null,
              ),
              title: Text(
                a.nome,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                [
                  if (a.estiloMusical?.trim().isNotEmpty == true)
                    a.estiloMusical!,
                  if (a.descricao?.trim().isNotEmpty == true) a.descricao!,
                ].join('\n'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (v) => v == 'e' ? _form(a) : _excluir(a),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'e', child: Text('Editar')),
                  PopupMenuItem(value: 'x', child: Text('Excluir')),
                ],
              ),
            ),
          );
        },
      );
    }
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(),
        icon: const Icon(Icons.add),
        label: const Text('Nova atração'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const ClubbarPageHeader(
              titulo: 'Atrações',
              subtitulo: 'Cadastre bandas, DJs, artistas e apresentações',
            ),
            Expanded(
              child: RefreshIndicator(onRefresh: _carregar, child: conteudo),
            ),
          ],
        ),
      ),
    );
  }
}
