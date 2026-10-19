import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/repositories/cardapio_repository.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../models/loja.dart';

class BeneficiosProdutosPage extends StatefulWidget {
  final int organizacaoId;
  const BeneficiosProdutosPage({super.key, required this.organizacaoId});
  @override
  State<BeneficiosProdutosPage> createState() => _BeneficiosProdutosPageState();
}

class _BeneficiosProdutosPageState extends State<BeneficiosProdutosPage> {
  final _lojasRepo = LojaRepository();
  final _produtosRepo = CardapioRepository();
  List<Loja> _lojas = const [];
  List<Map<String, dynamic>> _produtos = const [];
  List<Map<String, dynamic>> _campanhas = const [];
  int? _lojaId;
  bool _carregando = true;
  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      _lojas = await _lojasRepo.listar(widget.organizacaoId);
      _lojaId ??= _lojas.isEmpty ? null : _lojas.first.lojaId;
      _produtos = await _produtosRepo.listarProdutosPadraoOrganizacao(
        widget.organizacaoId,
      );
      if (_lojaId != null) {
        final r = await ApiService.get(
          '/beneficios-produtos/lojas/$_lojaId?organizacao_id=${widget.organizacaoId}',
        );
        if (r.statusCode == 200)
          _campanhas = (jsonDecode(r.body) as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      }
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _nova() async {
    if (_lojaId == null || _produtos.isEmpty) return;
    String tipo = 'CORTESIA';
    int produtoId = int.parse('${_produtos.first['produto_id']}');
    final nome = TextEditingController();
    final limite = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Novo benefício'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField(
                value: tipo,
                items: const [
                  DropdownMenuItem(value: 'CORTESIA', child: Text('Cortesia')),
                  DropdownMenuItem(
                    value: 'ROLETA',
                    child: Text('Roleta de descontos'),
                  ),
                ],
                onChanged: (v) => tipo = v!,
              ),
              DropdownButtonFormField<int>(
                value: produtoId,
                items: _produtos
                    .map(
                      (p) => DropdownMenuItem(
                        value: int.parse('${p['produto_id']}'),
                        child: Text('${p['nmproduto']}'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => produtoId = v!,
              ),
              TextField(
                controller: nome,
                decoration: const InputDecoration(
                  labelText: 'Nome da campanha',
                ),
              ),
              TextField(
                controller: limite,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantidade total (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'A roleta sorteia 0%, 10%, 20%, 30% ou 50%. Cada cliente gira uma vez por dia.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final agora = DateTime.now();
    final r = await ApiService.post('/beneficios-produtos', {
      'organizacao_id': widget.organizacaoId,
      'loja_id': _lojaId,
      'produto_id': produtoId,
      'tipo': tipo,
      'nmcampanha': nome.text.trim().isEmpty
          ? (tipo == 'ROLETA' ? 'Roleta promocional' : 'Cortesia de produto')
          : nome.text.trim(),
      'dthrinicio': agora.toIso8601String(),
      'dthrfim': agora.add(const Duration(days: 30)).toIso8601String(),
      'qtlimite': int.tryParse(limite.text),
      'limite_cliente_dia': 1,
      'situacao': 'ATIVA',
    });
    if (r.statusCode >= 200 && r.statusCode < 300) {
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, 'Benefício criado.');
    } else {
      if (mounted)
        AppSnackBar.erro(
          context,
          jsonDecode(r.body)['detail']?.toString() ??
              'Não foi possível salvar.',
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cortesias e promoções')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _nova,
      label: const Text('Nova campanha'),
      icon: const Icon(Icons.add),
    ),
    body: _carregando
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _carregar,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<int>(
                  value: _lojaId,
                  decoration: const InputDecoration(
                    labelText: 'Estabelecimento',
                  ),
                  items: _lojas
                      .map(
                        (l) => DropdownMenuItem(
                          value: l.lojaId,
                          child: Text(l.nmloja),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() => _lojaId = v);
                    _carregar();
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Campanhas independentes do cardápio',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'O produto continua com seu preço normal no cardápio. Configure a cortesia ou a roleta aqui, sem republicar.',
                ),
                const SizedBox(height: 12),
                ..._campanhas.map(
                  (x) => Card(
                    child: ListTile(
                      leading: Icon(
                        x['tipo'] == 'ROLETA'
                            ? Icons.casino_outlined
                            : Icons.redeem_outlined,
                      ),
                      title: Text('${x['nmcampanha']}'),
                      subtitle: Text(
                        '${x['tipo'] == 'ROLETA' ? 'Roleta: 0%, 10%, 20%, 30% e 50%' : 'Cortesia'} • ${x['resgates'] ?? 0} resgates',
                      ),
                      trailing: Text(
                        '${x['restantes'] ?? '∞'}\nrestantes',
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
}
