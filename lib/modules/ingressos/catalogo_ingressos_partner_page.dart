import 'package:flutter/material.dart';

import '../../core/repositories/catalogo_ingresso_partner_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/evento_lote.dart';

class CatalogoIngressosPartnerPage extends StatefulWidget {
  const CatalogoIngressosPartnerPage({super.key});

  @override
  State<CatalogoIngressosPartnerPage> createState() =>
      _CatalogoIngressosPartnerPageState();
}

class _CatalogoIngressosPartnerPageState
    extends State<CatalogoIngressosPartnerPage>
    with SingleTickerProviderStateMixin {
  final _repo = CatalogoIngressoPartnerRepository();
  late final TabController _tabs;
  List<ModalidadeIngressoCatalogo> _modalidades = [];
  List<BeneficioIngressoCatalogo> _beneficios = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _carregar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final resultados = await Future.wait([
        _repo.listarModalidades(incluirInativos: true),
        _repo.listarBeneficios(incluirInativos: true),
      ]);
      if (!mounted) return;
      setState(() {
        _modalidades = resultados[0] as List<ModalidadeIngressoCatalogo>;
        _beneficios = resultados[1] as List<BeneficioIngressoCatalogo>;
      });
    } catch (e) {
      if (mounted)
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _editarBeneficio([BeneficioIngressoCatalogo? item]) async {
    if (item != null && !item.propria) {
      AppSnackBar.aviso(
        context,
        'Este é um benefício padrão do Clubbar e não pode ser alterado pela empresa.',
      );
      return;
    }
    final codigo = TextEditingController(text: item?.codigo ?? '');
    final nome = TextEditingController(text: item?.nome ?? '');
    var comprovante = item?.exigeComprovante ?? true;
    var ativo = true;
    final salvar = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(item == null ? 'Novo benefício' : 'Editar benefício'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codigo,
                  decoration: const InputDecoration(labelText: 'Código'),
                ),
                TextField(
                  controller: nome,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                SwitchListTile(
                  value: comprovante,
                  onChanged: (v) => setDialog(() => comprovante = v),
                  title: const Text('Exige comprovante'),
                ),
                SwitchListTile(
                  value: ativo,
                  onChanged: (v) => setDialog(() => ativo = v),
                  title: const Text('Ativo'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (salvar == true) {
      try {
        await _repo.salvarBeneficio(
          atual: item,
          codigo: codigo.text,
          nome: nome.text,
          exigeComprovante: comprovante,
          situacao: ativo ? 'ATIVO' : 'INATIVO',
        );
        await _carregar();
      } catch (e) {
        if (mounted)
          AppSnackBar.erro(
            context,
            e.toString().replaceFirst('Exception: ', ''),
          );
      }
    }
    codigo.dispose();
    nome.dispose();
  }

  Future<void> _editarModalidade([ModalidadeIngressoCatalogo? item]) async {
    if (item != null && !item.propria) {
      AppSnackBar.aviso(
        context,
        'Esta é uma modalidade padrão do Clubbar e não pode ser alterada pela empresa.',
      );
      return;
    }
    final codigo = TextEditingController(text: item?.codigo ?? '');
    final nome = TextEditingController(text: item?.nome ?? '');
    var tipo = item?.tipo ?? 'COMERCIAL';
    var exigeBeneficio = item?.exigeBeneficio ?? false;
    var exigeComprovante = item?.exigeComprovante ?? false;
    var ativo = true;
    final selecionados = item?.beneficios.map((e) => e.id).toSet() ?? <int>{};
    final salvar = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(item == null ? 'Nova modalidade' : 'Editar modalidade'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codigo,
                    decoration: const InputDecoration(labelText: 'Código'),
                  ),
                  TextField(
                    controller: nome,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: tipo,
                    items: const [
                      DropdownMenuItem(
                        value: 'COMERCIAL',
                        child: Text('Comercial'),
                      ),
                      DropdownMenuItem(value: 'PADRAO', child: Text('Padrão')),
                    ],
                    onChanged: (v) => setDialog(() => tipo = v ?? 'COMERCIAL'),
                    decoration: const InputDecoration(labelText: 'Tipo'),
                  ),
                  SwitchListTile(
                    value: exigeBeneficio,
                    onChanged: (v) => setDialog(() => exigeBeneficio = v),
                    title: const Text('Exige benefício'),
                  ),
                  SwitchListTile(
                    value: exigeComprovante,
                    onChanged: (v) => setDialog(() => exigeComprovante = v),
                    title: const Text('Exige comprovante'),
                  ),
                  SwitchListTile(
                    value: ativo,
                    onChanged: (v) => setDialog(() => ativo = v),
                    title: const Text('Ativa'),
                  ),
                  if (exigeBeneficio) ...[
                    const Divider(),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Benefícios aceitos',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ..._beneficios.map(
                      (beneficio) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: selecionados.contains(beneficio.id),
                        title: Text(beneficio.nome),
                        onChanged: (v) => setDialog(() {
                          if (v == true) {
                            selecionados.add(beneficio.id);
                          } else {
                            selecionados.remove(beneficio.id);
                          }
                        }),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (salvar == true) {
      try {
        await _repo.salvarModalidade(
          atual: item,
          codigo: codigo.text,
          nome: nome.text,
          tipo: tipo,
          exigeBeneficio: exigeBeneficio,
          exigeComprovante: exigeComprovante,
          beneficiosIds: selecionados.toList(),
          situacao: ativo ? 'ATIVO' : 'INATIVO',
        );
        await _carregar();
      } catch (e) {
        if (mounted)
          AppSnackBar.erro(
            context,
            e.toString().replaceFirst('Exception: ', ''),
          );
      }
    }
    codigo.dispose();
    nome.dispose();
  }

  Future<void> _excluir(bool modalidade, int id) async {
    try {
      if (modalidade)
        await _repo.excluirModalidade(id);
      else
        await _repo.excluirBeneficio(id);
      await _carregar();
    } catch (e) {
      if (mounted)
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _listaModalidades() => RefreshIndicator(
    onRefresh: _carregar,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Modalidades da empresa',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ..._modalidades.map(
          (item) => ClubbarCard(
            child: ListTile(
              leading: Icon(
                item.propria ? Icons.sell_rounded : Icons.verified_outlined,
                color: item.propria
                    ? ClubbarColors.primaria
                    : ClubbarColors.textoSecundario,
              ),
              title: Text(item.nome),
              subtitle: Text(
                '${item.codigo} · ${item.propria ? 'Da empresa' : 'Padrão Clubbar'}${item.exigeBeneficio ? ' · exige benefício' : ''}',
              ),
              trailing: item.propria
                  ? Wrap(
                      children: [
                        IconButton(
                          onPressed: () => _editarModalidade(item),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => _excluir(true, item.id),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: ClubbarColors.erro,
                          ),
                        ),
                      ],
                    )
                  : const Chip(label: Text('Padrão')),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _listaBeneficios() => RefreshIndicator(
    onRefresh: _carregar,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Benefícios da empresa',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ..._beneficios.map(
          (item) => ClubbarCard(
            child: ListTile(
              leading: Icon(
                item.propria
                    ? Icons.card_membership_rounded
                    : Icons.verified_outlined,
                color: item.propria
                    ? ClubbarColors.primaria
                    : ClubbarColors.textoSecundario,
              ),
              title: Text(item.nome),
              subtitle: Text(
                '${item.codigo} · ${item.propria ? 'Da empresa' : 'Padrão Clubbar'}',
              ),
              trailing: item.propria
                  ? Wrap(
                      children: [
                        IconButton(
                          onPressed: () => _editarBeneficio(item),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => _excluir(false, item.id),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: ClubbarColors.erro,
                          ),
                        ),
                      ],
                    )
                  : const Chip(label: Text('Padrão')),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    backgroundColor: ClubbarColors.fundo,
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _carregando
          ? null
          : () => _tabs.index == 0 ? _editarModalidade() : _editarBeneficio(),
      icon: const Icon(Icons.add),
      label: Text(_tabs.index == 0 ? 'Nova modalidade' : 'Novo benefício'),
    ),
    body: Column(
      children: [
        const ClubbarPageHeader(
          titulo: 'Ingressos',
          subtitulo: 'Modalidades e benefícios usados nos seus eventos',
        ),
        TabBar(
          controller: _tabs,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'Modalidades'),
            Tab(text: 'Benefícios'),
          ],
        ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabs,
                  children: [_listaModalidades(), _listaBeneficios()],
                ),
        ),
      ],
    ),
  );
}
