import 'package:flutter/material.dart';

import '../../../core/repositories/categoria_padrao_consulta_repository.dart';
import '../../../core/widgets/clubbar_app_bar.dart';
import '../../../core/widgets/clubbar_page_header.dart';

class CategoriaPadraoConsultaPage extends StatefulWidget {
  const CategoriaPadraoConsultaPage({super.key});

  @override
  State<CategoriaPadraoConsultaPage> createState() =>
      _CategoriaPadraoConsultaPageState();
}

class _CategoriaPadraoConsultaPageState
    extends State<CategoriaPadraoConsultaPage> {
  final _repo = CategoriaPadraoConsultaRepository();
  final _busca = TextEditingController();
  List<CategoriaPadraoAdmin> _itens = [];
  bool _carregando = true;

  static const _iconesDisponiveis = <String, IconData>{
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

  IconData _icone(String nome) =>
      _iconesDisponiveis[nome] ?? Icons.category_rounded;

  List<CategoriaPadraoAdmin> get _filtrados {
    final termo = _busca.text.trim().toLowerCase();
    return termo.isEmpty
        ? _itens
        : _itens.where((e) => e.nome.toLowerCase().contains(termo)).toList();
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final itens = await _repo.listar();
      if (mounted) setState(() => _itens = itens);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itens = _filtrados;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: 'Categorias padrão dos produtos',
            subtitulo: 'Catálogo geral do Clubbar',
            trailing: IconButton(
              tooltip: 'Atualizar',
              onPressed: _carregar,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: TextField(
              controller: _busca,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Buscar categoria',
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 6, 18, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'As categorias deste catálogo não podem ser alteradas ou excluídas. Consulta somente para leitura.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _carregar,
                    child: itens.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 90),
                              Icon(Icons.category_outlined, size: 54),
                              Center(
                                child: Text('Nenhuma categoria encontrada.'),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                            itemCount: itens.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final item = itens[i];
                              final ativa = item.situacao == 'ATIVA';
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: ativa
                                        ? Colors.amber.shade100
                                        : Colors.grey.shade200,
                                    child: Icon(_icone(item.icone)),
                                  ),
                                  title: Text(
                                    item.nome,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${item.icone} • Ordem ${item.ordem}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Text(ativa ? 'Ativa' : 'Inativa'),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
