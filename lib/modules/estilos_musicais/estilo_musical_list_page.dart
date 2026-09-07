import 'package:flutter/material.dart';

import '../../core/repositories/atracao_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/atracao.dart';

class EstiloMusicalListPage extends StatefulWidget {
  const EstiloMusicalListPage({super.key});

  @override
  State<EstiloMusicalListPage> createState() => _EstiloMusicalListPageState();
}

class _EstiloMusicalListPageState extends State<EstiloMusicalListPage> {
  final _repo = AtracaoRepository();
  final _busca = TextEditingController();
  List<EstiloMusical> _itens = [];
  bool _carregando = true;
  String? _erro;

  List<EstiloMusical> get _filtrados {
    final termo = _busca.text.trim().toLowerCase();
    if (termo.isEmpty) return _itens;
    return _itens.where((e) => e.nome.toLowerCase().contains(termo)).toList();
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final itens = await _repo.listarEstilosParaGerenciar();
      if (mounted) {
        setState(() {
          _itens = itens;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString().replaceFirst('Exception: ', '');
          _carregando = false;
        });
      }
    }
  }

  Future<void> _editar([EstiloMusical? estilo]) async {
    final nome = TextEditingController(text: estilo?.nome ?? '');
    var ativo = estilo?.situacao != 'INATIVO';
    final salvar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            estilo == null ? 'Novo estilo musical' : 'Editar estilo musical',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nome,
                autofocus: true,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome do estilo'),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Estilo ativo'),
                value: ativo,
                onChanged: (valor) => setDialogState(() => ativo = valor),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (salvar != true) {
      nome.dispose();
      return;
    }
    final valor = nome.text.trim();
    nome.dispose();
    if (valor.isEmpty) {
      if (mounted) {
        AppSnackBar.aviso(context, 'Informe o nome do estilo musical.');
      }
      return;
    }
    try {
      await _repo.salvarEstilo(
        estilo: estilo,
        nome: valor,
        situacao: ativo ? 'ATIVO' : 'INATIVO',
      );
      if (!mounted) return;
      AppSnackBar.sucesso(
        context,
        estilo == null
            ? 'Estilo musical incluído.'
            : 'Estilo musical atualizado.',
      );
      await _carregar();
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _importarDoCatalogo() async {
    try {
      final catalogo = await _repo.listarCatalogoEstilos();
      if (!mounted) return;
      final jaAdotados = _itens
          .where((e) => e.origem == 'CATALOGO')
          .map((e) => e.nome.toLowerCase())
          .toSet();
      final disponiveis = catalogo
          .where((e) => !jaAdotados.contains(e.nome.toLowerCase()))
          .toList();
      final selecionados = <int>{};
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Adicionar do catálogo Clubbar'),
            content: SizedBox(
              width: 480,
              child: disponiveis.isEmpty
                  ? const Text(
                      'Todos os estilos do catálogo já foram adicionados.',
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: disponiveis.length,
                      itemBuilder: (_, i) {
                        final estilo = disponiveis[i];
                        return CheckboxListTile(
                          value: selecionados.contains(estilo.id),
                          title: Text(estilo.nome),
                          onChanged: (valor) => setDialogState(() {
                            valor == true
                                ? selecionados.add(estilo.id)
                                : selecionados.remove(estilo.id);
                          }),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: disponiveis.isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Adicionar'),
              ),
            ],
          ),
        ),
      );
      if (confirmar != true || selecionados.isEmpty) return;
      await _repo.importarEstilos(selecionados.toList());
      if (!mounted) return;
      AppSnackBar.sucesso(context, 'Estilos adicionados à organização.');
      await _carregar();
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _excluir(EstiloMusical estilo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir estilo musical?'),
        content: Text('Deseja excluir “${estilo.nome}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _repo.excluirEstilo(estilo.id);
      if (!mounted) return;
      AppSnackBar.sucesso(context, 'Estilo musical excluído.');
      await _carregar();
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itens = _filtrados;
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'adicionar_catalogo_estilos',
            onPressed: _importarDoCatalogo,
            icon: const Icon(Icons.playlist_add_rounded),
            label: const Text('Adicionar do catálogo'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'adicionar_estilo',
            onPressed: () => _editar(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar estilo'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: 'Estilos da organização',
              subtitulo:
                  '${_itens.length} estilos disponíveis para as atrações',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: TextField(
                controller: _busca,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Buscar estilo musical',
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _carregar,
                child: _carregando
                    ? const Center(child: CircularProgressIndicator())
                    : _erro != null
                    ? ListView(
                        children: [
                          const SizedBox(height: 90),
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 52,
                            color: ClubbarColors.erro,
                          ),
                          Center(
                            child: Text(_erro!, textAlign: TextAlign.center),
                          ),
                          TextButton(
                            onPressed: _carregar,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      )
                    : itens.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 90),
                          Icon(Icons.music_note_rounded, size: 58),
                          Center(child: Text('Nenhum estilo encontrado.')),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
                        itemCount: itens.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final estilo = itens[index];
                          final ativo = estilo.situacao == 'ATIVO';
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: ativo
                                    ? ClubbarColors.ambarClaro
                                    : ClubbarColors.borda,
                                child: const Icon(Icons.music_note_rounded),
                              ),
                              title: Text(
                                estilo.nome,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '${estilo.origem == 'CATALOGO' ? 'Catálogo Clubbar' : 'Personalizado'} • ${ativo ? 'Ativo' : 'Inativo'}',
                                style: TextStyle(
                                  color: ativo
                                      ? Colors.green
                                      : ClubbarColors.textoSecundario,
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (opcao) => opcao == 'editar'
                                    ? _editar(estilo)
                                    : _excluir(estilo),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'editar',
                                    child: ListTile(
                                      leading: Icon(Icons.edit_rounded),
                                      title: Text('Editar'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'excluir',
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                      title: Text('Excluir'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
