import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/repositories/cardapio_repository.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
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
        if (r.statusCode == 200) {
          _campanhas = (jsonDecode(r.body) as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _nova([Map<String, dynamic>? campanha]) async {
    if (_lojaId == null || _produtos.isEmpty) return;
    String tipo = '${campanha?['tipo'] ?? 'CORTESIA'}';
    int produtoId =
        int.tryParse('${campanha?['produto_id']}') ??
        int.parse('${_produtos.first['produto_id']}');
    final nome = TextEditingController(
      text: '${campanha?['nmcampanha'] ?? ''}',
    );
    final limite = TextEditingController(
      text: campanha?['qtlimite']?.toString() ?? '',
    );
    final quantidadePacote = TextEditingController(
      text: campanha?['qtitenspacote']?.toString() ?? '',
    );
    final valorPacote = TextEditingController(
      text: campanha?['vrpacote']?.toString() ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (c, atualizar) => AlertDialog(
          title: const Text('Novo benefício'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField(
                  initialValue: tipo,
                  items: const [
                    DropdownMenuItem(
                      value: 'CORTESIA',
                      child: Text('Cortesia'),
                    ),
                    DropdownMenuItem(
                      value: 'ROLETA',
                      child: Text('Roleta de descontos'),
                    ),
                    DropdownMenuItem(
                      value: 'PACOTE',
                      child: Text('Promoção por quantidade'),
                    ),
                  ],
                  onChanged: (v) => atualizar(() => tipo = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: produtoId,
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
                const SizedBox(height: 12),
                TextField(
                  controller: nome,
                  decoration: const InputDecoration(
                    labelText: 'Nome da campanha',
                  ),
                ),
                if (tipo == 'PACOTE') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantidadePacote,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade de produtos no pacote',
                      hintText: 'Ex.: 3',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valorPacote,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Preço do pacote',
                      hintText: 'Ex.: 40,00',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: limite,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade total (opcional)',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tipo == 'PACOTE'
                      ? 'O cliente verá o produto normal no cardápio e, abaixo dele, a oferta do pacote. A compra gera uma ficha individual para cada unidade.'
                      : 'A roleta sorteia 10% ou 20%. O cliente pode girar até duas vezes por produto em 24 horas; o segundo giro substitui o primeiro prêmio. Cortesia pendente ou desconto usado nos últimos 10 dias bloqueiam novos giros.',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final agora = DateTime.now();
    final dados = {
      'organizacao_id': widget.organizacaoId,
      'loja_id': _lojaId,
      'produto_id': produtoId,
      'tipo': tipo,
      'nmcampanha': nome.text.trim().isEmpty
          ? (tipo == 'ROLETA'
                ? 'Roleta promocional'
                : tipo == 'PACOTE'
                ? 'Promoção por quantidade'
                : 'Cortesia de produto')
          : nome.text.trim(),
      'dthrinicio': campanha?['dthrinicio'] ?? agora.toIso8601String(),
      'dthrfim':
          campanha?['dthrfim'] ??
          agora.add(const Duration(days: 30)).toIso8601String(),
      'qtlimite': int.tryParse(limite.text),
      'limite_cliente_dia': 1,
      'qtitenspacote': tipo == 'PACOTE'
          ? int.tryParse(quantidadePacote.text.trim())
          : null,
      'vrpacote': tipo == 'PACOTE'
          ? double.tryParse(valorPacote.text.trim().replaceAll(',', '.'))
          : null,
      'situacao': 'ATIVA',
    };
    final r = campanha == null
        ? await ApiService.post('/beneficios-produtos', dados)
        : await ApiService.put(
            '/beneficios-produtos/${campanha['campanha_id']}',
            dados,
          );
    if (r.statusCode >= 200 && r.statusCode < 300) {
      await _carregar();
      if (mounted) {
        AppSnackBar.sucesso(
          context,
          campanha == null ? 'Benefício criado.' : 'Campanha atualizada.',
        );
      }
    } else {
      if (mounted) {
        AppSnackBar.erro(
          context,
          jsonDecode(r.body)['detail']?.toString() ??
              'Não foi possível salvar.',
        );
      }
    }
  }

  Future<void> _excluir(Map<String, dynamic> campanha) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir campanha'),
        content: Text('Excluir "${campanha['nmcampanha']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final r = await ApiService.delete(
      '/beneficios-produtos/${campanha['campanha_id']}',
    );
    if (r.statusCode == 204) {
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, 'Campanha excluída.');
    } else if (mounted) {
      AppSnackBar.erro(context, 'Não foi possível excluir a campanha.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ClubbarAppBar(mostrarVoltar: true),
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
              padding: EdgeInsets.zero,
              children: [
                const ClubbarPageHeader(
                  titulo: 'Cortesias e promoções',
                  subtitulo:
                      'Planeje campanhas sem alterar ou republicar o cardápio.',
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<int>(
                    initialValue: _lojaId,
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
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Campanhas independentes do cardápio',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'O produto continua com seu preço normal no cardápio. Configure a cortesia ou a roleta aqui, sem republicar.',
                  ),
                ),
                const SizedBox(height: 12),
                ..._campanhas.map(
                  (x) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Card(
                      child: ListTile(
                        leading: Icon(
                          x['tipo'] == 'ROLETA'
                              ? Icons.casino_outlined
                              : x['tipo'] == 'PACOTE'
                              ? Icons.local_offer_outlined
                              : Icons.redeem_outlined,
                        ),
                        title: Text('${x['nmcampanha']}'),
                        subtitle: Text(
                          'Produto: ${x['nmproduto'] ?? 'Produto'}\n${x['tipo'] == 'ROLETA'
                              ? 'Roleta: 10% ou 20% OFF'
                              : x['tipo'] == 'PACOTE'
                              ? 'Promoção: ${x['qtitenspacote']} por R\$ ${x['vrpacote']}'
                              : 'Cortesia'} • ${x['resgates'] ?? 0} resgates',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${x['restantes'] ?? '∞'}\nrestantes',
                              textAlign: TextAlign.right,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Editar',
                              onPressed: () => _nova(x),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              tooltip: 'Excluir',
                              onPressed: () => _excluir(x),
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
