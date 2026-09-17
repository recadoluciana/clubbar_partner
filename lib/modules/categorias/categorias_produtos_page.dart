import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../core/widgets/app_snackbar.dart';

class CategoriasProdutosPage extends StatefulWidget {
  final int organizacaoId;
  const CategoriasProdutosPage({super.key, required this.organizacaoId});
  @override
  State<CategoriasProdutosPage> createState() => _CategoriasProdutosPageState();
}

class _CategoriasProdutosPageState extends State<CategoriasProdutosPage> {
  List<Map<String, dynamic>> _itens = [];
  bool _ocupado = false;
  String? _erro;
  String _busca = '';
  String get _rota => '/organizacoes/${widget.organizacaoId}/categorias';
  static const _icones = <String, IconData>{
    'category': Icons.category_rounded,
    'water_drop': Icons.water_drop_rounded,
    'local_drink': Icons.local_drink_rounded,
    'local_cafe': Icons.local_cafe_rounded,
    'bolt': Icons.bolt_rounded,
    'sports_bar': Icons.sports_bar_rounded,
    'no_drinks': Icons.no_drinks_rounded,
    'local_bar': Icons.local_bar_rounded,
    'liquor': Icons.liquor_rounded,
    'wine_bar': Icons.wine_bar_rounded,
    'coffee': Icons.coffee_rounded,
    'soup_kitchen': Icons.soup_kitchen_rounded,
    'tapas': Icons.tapas_rounded,
    'restaurant': Icons.restaurant_rounded,
    'lunch_dining': Icons.lunch_dining_rounded,
    'outdoor_grill': Icons.outdoor_grill_rounded,
    'fastfood': Icons.fastfood_rounded,
    'local_pizza': Icons.local_pizza_rounded,
    'dinner_dining': Icons.dinner_dining_rounded,
    'eco': Icons.eco_rounded,
    'cake': Icons.cake_rounded,
    'icecream': Icons.icecream_rounded,
    'inventory_2': Icons.inventory_2_rounded,
    'sell': Icons.sell_rounded,
    'celebration': Icons.celebration_rounded,
    'event_seat': Icons.event_seat_rounded,
    'event': Icons.event_rounded,
    'checkroom': Icons.checkroom_rounded,
    'redeem': Icons.redeem_rounded,
    'more_horiz': Icons.more_horiz_rounded,
  };
  IconData _icone(dynamic nome) => _icones[nome] ?? Icons.category_rounded;
  static const _coresCategoria = <Color>[
    Color(0xFFE65100),
    Color(0xFF1565C0),
    Color(0xFF7B1FA2),
    Color(0xFF2E7D32),
    Color(0xFFC62828),
    Color(0xFF00838F),
    Color(0xFFAD1457),
  ];

  Color _corCategoria(Map<String, dynamic> categoria) {
    final id = (categoria['categoria_id'] as num?)?.toInt() ?? 0;
    return _coresCategoria[id.abs() % _coresCategoria.length];
  }

  dynamic _resposta(dynamic r) {
    final dados = jsonDecode(r.body);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(
        dados is Map ? dados['detail'] : 'Não foi possível concluir.',
      );
    }
    return dados;
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _mostrarErro(Object erro) {
    if (!mounted) return;
    final mensagem = erro.toString().replaceFirst(
      RegExp(r'^Exception:\s*'),
      '',
    );
    AppSnackBar.erro(
      context,
      mensagem,
      duration: const Duration(seconds: 20),
      mostrarFechar: true,
    );
  }

  Future<void> _carregar() async {
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final dados = _resposta(await ApiService.get(_rota)) as List;
      if (mounted) {
        setState(
          () =>
              _itens = dados.map((e) => Map<String, dynamic>.from(e)).toList(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _salvar(String rota, Map<String, dynamic> dados) async {
    setState(() => _ocupado = true);
    try {
      _resposta(await ApiService.post(rota, dados));
      await _carregar();
    } catch (e) {
      _mostrarErro(e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _importar() async {
    setState(() => _ocupado = true);
    try {
      final padroes =
          _resposta(await ApiService.get('/categorias-padrao')) as List;
      final selecionados = _itens
          .where(
            (e) =>
                e['categoriapadrao_id'] != null && e['sitcategoria'] == 'ATIVA',
          )
          .map((e) => e['categoriapadrao_id'] as int)
          .toSet();
      if (!mounted) return;
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, atualizar) => AlertDialog(
            title: const Text('Importar categorias padrão'),
            content: SizedBox(
              width: 440,
              height: 380,
              child: ListView(
                children: padroes
                    .map<Widget>(
                      (e) => CheckboxListTile(
                        secondary: Icon(_icone(e['dsicone'])),
                        title: Text(e['nmcategoria']),
                        value: selecionados.contains(e['categoriapadrao_id']),
                        onChanged: (v) => atualizar(() {
                          if (v == true) {
                            selecionados.add(e['categoriapadrao_id']);
                          } else {
                            selecionados.remove(e['categoriapadrao_id']);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Salvar seleção'),
              ),
            ],
          ),
        ),
      );
      if (confirmar == true && mounted) {
        await _salvar('$_rota/selecionar', {
          'categorias_padrao_ids': selecionados.toList(),
        });
      }
    } catch (e) {
      _mostrarErro(e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _apagar(Map<String, dynamic> categoria) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar categoria?'),
        content: Text(
          'Deseja apagar "${categoria['nmcategoria']}" da sua empresa? '
          'Esta ação não pode ser desfeita. O catálogo padrão do Clubbar não será alterado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      _resposta(await ApiService.delete('$_rota/${categoria['categoria_id']}'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categoria apagada com sucesso.')),
      );
      await _carregar();
    } catch (e) {
      _mostrarErro(e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _alterarSituacao(Map<String, dynamic> categoria) async {
    final ativar = categoria['sitcategoria'] != 'ATIVA';
    setState(() => _ocupado = true);
    try {
      _resposta(
        await ApiService.patch(
          '$_rota/${categoria['categoria_id']}/situacao',
          body: {'sitcategoria': ativar ? 'ATIVA' : 'INATIVA'},
        ),
      );
      await _carregar();
      if (mounted) {
        AppSnackBar.sucesso(
          context,
          ativar ? 'Categoria ativada.' : 'Categoria inativada.',
        );
      }
    } catch (e) {
      _mostrarErro(e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _criar() async {
    final form = GlobalKey<FormState>();
    String nome = '', icone = 'category';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova categoria dos produtos'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Nome *'),
                maxLength: 120,
                onChanged: (v) => nome = v.trim(),
                validator: (v) => (v ?? '').trim().length < 2
                    ? 'Informe ao menos 2 caracteres.'
                    : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: icone,
                decoration: const InputDecoration(labelText: 'Ícone'),
                items: _icones.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Row(
                          children: [
                            Icon(e.value),
                            const SizedBox(width: 12),
                            Text(e.key),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => icone = v ?? 'category',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Criar categoria'),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      await _salvar(_rota, {'nmcategoria': nome, 'dsicone': icone});
    }
  }

  @override
  Widget build(BuildContext context) {
    final itens = _itens
        .where((e) => '${e['nmcategoria']}'.toLowerCase().contains(_busca))
        .toList();
    return Scaffold(
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: 'Categorias dos produtos',
            subtitulo: 'Categorias da sua empresa',
            trailing: IconButton(
              onPressed: _ocupado ? null : _carregar,
              icon: const Icon(Icons.refresh),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar categoria',
                  ),
                  onChanged: (v) =>
                      setState(() => _busca = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _ocupado ? null : _importar,
                      icon: const Icon(Icons.download),
                      label: const Text('Importar das padrão'),
                    ),
                    FilledButton.icon(
                      onPressed: _ocupado ? null : _criar,
                      icon: const Icon(Icons.add),
                      label: const Text('Criar categoria'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Somente as categorias ativas da sua empresa são usadas no Cardápio Digital.',
                ),
              ],
            ),
          ),
          Expanded(
            child: _ocupado
                ? const Center(child: CircularProgressIndicator())
                : _erro != null
                ? Center(child: Text(_erro!))
                : RefreshIndicator(
                    onRefresh: _carregar,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: itens.isEmpty
                          ? [
                              const ListTile(
                                title: Text(
                                  'Nenhuma categoria. Importe das padrão ou crie uma.',
                                ),
                              ),
                            ]
                          : itens
                                .map(
                                  (e) => Card(
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: _corCategoria(
                                          e,
                                        ).withValues(alpha: 0.14),
                                        child: Icon(
                                          _icone(e['dsicone']),
                                          color: _corCategoria(e),
                                        ),
                                      ),
                                      title: Text(e['nmcategoria']),
                                      subtitle: Text(
                                        '${e['categoriapadrao_id'] == null ? 'Categoria própria' : 'Importada das padrão'} • ${e['sitcategoria'] == 'ATIVA' ? 'Ativa' : 'Inativa'}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          OutlinedButton(
                                            onPressed: _ocupado
                                                ? null
                                                : () => _alterarSituacao(e),
                                            child: Text(
                                              e['sitcategoria'] == 'ATIVA'
                                                  ? 'Inativar'
                                                  : 'Ativar',
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Apagar categoria',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                            onPressed: _ocupado
                                                ? null
                                                : () => _apagar(e),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
