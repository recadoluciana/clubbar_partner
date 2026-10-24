import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/repositories/cardapio_repository.dart';
import '../../core/repositories/loja_repository.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../core/utils/text_normalizer.dart';
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
  bool _mostrarSomenteAtivas = false;

  DateTime? _dataCampanha(dynamic valor) {
    final texto = '${valor ?? ''}'.trim();
    if (texto.isEmpty) return null;
    return DateTime.tryParse(texto)?.toLocal();
  }

  bool _campanhaEstaAtivaAgora(Map<String, dynamic> campanha) {
    final situacao = '${campanha['situacao'] ?? ''}'.trim().toUpperCase();
    final statusPeriodo = '${campanha['status_periodo'] ?? ''}'
        .trim()
        .toUpperCase();
    final agora = DateTime.now();
    final inicio = _dataCampanha(campanha['dthrinicio']);
    final fim = _dataCampanha(campanha['dthrfim']);
    final restantes = num.tryParse('${campanha['restantes'] ?? ''}');

    return (situacao.isEmpty || situacao == 'ATIVA') &&
        (statusPeriodo.isEmpty || statusPeriodo == 'ATIVA') &&
        (inicio == null || !agora.isBefore(inicio)) &&
        (fim == null || !agora.isAfter(fim)) &&
        (restantes == null || restantes > 0);
  }

  List<Map<String, dynamic>> get _campanhasExibidas => _mostrarSomenteAtivas
      ? _campanhas.where(_campanhaEstaAtivaAgora).toList()
      : _campanhas;

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
    final campanhaLegadaDeRoleta = campanha?['tipo'] == 'ROLETA';
    String tipo = campanhaLegadaDeRoleta
        ? 'PERCENTUAL'
        : '${campanha?['tipo'] ?? 'CORTESIA'}';
    int produtoId =
        int.tryParse('${campanha?['produto_id']}') ??
        int.parse('${_produtos.first['produto_id']}');
    final nome = TextEditingController(
      text: campanhaLegadaDeRoleta
          ? 'Promoção percentual'
          : '${campanha?['nmcampanha'] ?? ''}',
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
    final percentualDesconto = TextEditingController(
      text: campanha?['percentual_desconto']?.toString() ?? '',
    );
    DateTime inicio =
        DateTime.tryParse('${campanha?['dthrinicio'] ?? ''}')?.toLocal() ??
        DateTime.now();
    DateTime? fim = campanha?['dthrfim'] == null
        ? null
        : DateTime.tryParse('${campanha?['dthrfim']}')?.toLocal();
    bool possuiFim = fim != null;

    String formatarDataHora(DateTime data) {
      String doisDigitos(int valor) => valor.toString().padLeft(2, '0');
      return '${doisDigitos(data.day)}/${doisDigitos(data.month)}/${data.year} '
          '${doisDigitos(data.hour)}:${doisDigitos(data.minute)}';
    }

    String nomeProdutoSelecionado() {
      final produto = _produtos.where(
        (item) => int.tryParse('${item['produto_id']}') == produtoId,
      );
      return produto.isEmpty
          ? 'Selecione o produto'
          : '${produto.first['nmproduto']}';
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (c, atualizar) => AlertDialog(
          title: Text(campanha == null ? 'Novo benefício' : 'Editar benefício'),
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
                      value: 'PERCENTUAL',
                      child: Text('Promoção por percentual'),
                    ),
                    DropdownMenuItem(
                      value: 'PACOTE',
                      child: Text('Promoção por quantidade'),
                    ),
                  ],
                  onChanged: (v) => atualizar(() => tipo = v!),
                ),
                const SizedBox(height: 12),
                Semantics(
                  button: true,
                  label: 'Selecione o produto',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () async {
                      final selecionado = await Navigator.of(context)
                          .push<Map<String, dynamic>>(
                            MaterialPageRoute(
                              builder: (_) => _SelecionarProdutoPage(
                                produtos: _produtos,
                                produtoIdSelecionado: produtoId,
                              ),
                            ),
                          );
                      if (selecionado == null) return;
                      atualizar(() {
                        produtoId = int.parse('${selecionado['produto_id']}');
                      });
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Selecione o produto',
                        suffixIcon: Icon(Icons.search_rounded),
                      ),
                      child: Text(
                        nomeProdutoSelecionado(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nome,
                  decoration: const InputDecoration(
                    labelText: 'Nome da campanha',
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () async {
                    final data = await showDatePicker(
                      context: c,
                      initialDate: inicio,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (data == null || !c.mounted) return;
                    final hora = await showTimePicker(
                      context: c,
                      initialTime: TimeOfDay.fromDateTime(inicio),
                    );
                    if (hora == null) return;
                    atualizar(() {
                      inicio = DateTime(
                        data.year,
                        data.month,
                        data.day,
                        hora.hour,
                        hora.minute,
                      );
                    });
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Início da campanha',
                      suffixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(formatarDataHora(inicio)),
                  ),
                ),
                const SizedBox(height: 4),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Definir data e hora de término'),
                  subtitle: const Text(
                    'Desative para manter a campanha sem prazo final.',
                  ),
                  value: possuiFim,
                  onChanged: (valor) => atualizar(() {
                    possuiFim = valor;
                    fim ??= inicio.add(const Duration(days: 1));
                  }),
                ),
                if (possuiFim) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () async {
                      final referencia =
                          fim ?? inicio.add(const Duration(days: 1));
                      final data = await showDatePicker(
                        context: c,
                        initialDate: referencia,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (data == null || !c.mounted) return;
                      final hora = await showTimePicker(
                        context: c,
                        initialTime: TimeOfDay.fromDateTime(referencia),
                      );
                      if (hora == null) return;
                      atualizar(() {
                        fim = DateTime(
                          data.year,
                          data.month,
                          data.day,
                          hora.hour,
                          hora.minute,
                        );
                      });
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fim da campanha',
                        suffixIcon: Icon(Icons.event_available_outlined),
                      ),
                      child: Text(formatarDataHora(fim!)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
                if (tipo == 'PERCENTUAL') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: percentualDesconto,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Desconto percentual',
                      hintText: 'Ex.: 20',
                      suffixText: '%',
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
                      : tipo == 'PERCENTUAL'
                      ? 'O desconto será aplicado automaticamente ao produto no cardápio e no carrinho, sem sorteio ou etapas extras.'
                      : 'O cliente poderá resgatar esta cortesia diretamente para a carteira.',
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
    if (possuiFim && (fim == null || !fim!.isAfter(inicio))) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          'O fim da campanha deve ser posterior ao início.',
        );
      }
      return;
    }
    final percentual = double.tryParse(
      percentualDesconto.text.trim().replaceAll(',', '.'),
    );
    if (tipo == 'PERCENTUAL' &&
        (percentual == null || percentual <= 0 || percentual >= 100)) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          'Informe um desconto maior que 0% e menor que 100%.',
        );
      }
      return;
    }
    final dados = {
      'organizacao_id': widget.organizacaoId,
      'loja_id': _lojaId,
      'produto_id': produtoId,
      'tipo': tipo,
      'nmcampanha': nome.text.trim().isEmpty
          ? (tipo == 'PERCENTUAL'
                ? 'Promoção percentual'
                : tipo == 'PACOTE'
                ? 'Promoção por quantidade'
                : 'Cortesia de produto')
          : nome.text.trim(),
      'dthrinicio': inicio.toIso8601String(),
      'dthrfim': possuiFim ? fim!.toIso8601String() : null,
      'qtlimite': int.tryParse(limite.text),
      'limite_cliente_dia': 1,
      'qtitenspacote': tipo == 'PACOTE'
          ? int.tryParse(quantidadePacote.text.trim())
          : null,
      'vrpacote': tipo == 'PACOTE'
          ? double.tryParse(valorPacote.text.trim().replaceAll(',', '.'))
          : null,
      'percentual_desconto': tipo == 'PERCENTUAL' ? percentual : null,
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

  String _descricaoPeriodo(Map<String, dynamic> campanha) {
    DateTime? converter(dynamic valor) =>
        valor == null ? null : DateTime.tryParse('$valor')?.toLocal();
    String formatar(DateTime data) {
      String doisDigitos(int valor) => valor.toString().padLeft(2, '0');
      return '${doisDigitos(data.day)}/${doisDigitos(data.month)}/${data.year} '
          '${doisDigitos(data.hour)}:${doisDigitos(data.minute)}';
    }

    final inicio = converter(campanha['dthrinicio']);
    final fim = converter(campanha['dthrfim']);
    switch ('${campanha['status_periodo'] ?? ''}') {
      case 'AGENDADA':
        return inicio == null
            ? 'Campanha agendada'
            : 'Agendada para ${formatar(inicio)}';
      case 'ENCERRADA':
        return fim == null
            ? 'Campanha encerrada'
            : 'Encerrada em ${formatar(fim)}';
      case 'INATIVA':
        return 'Campanha inativa';
      default:
        return fim == null
            ? 'Ativa sem prazo final'
            : 'Ativa até ${formatar(fim)}';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: _carregando
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _carregar,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ClubbarPageHeader(
                  titulo: 'Cortesias e promoções',
                  subtitulo:
                      'Planeje campanhas sem alterar ou republicar o cardápio.',
                  trailing: FilledButton.icon(
                    onPressed: _nova,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nova campanha'),
                  ),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Campanhas independentes do cardápio',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      FilterChip(
                        avatar: const Icon(Icons.bolt_rounded, size: 18),
                        label: const Text('Ativas agora'),
                        selected: _mostrarSomenteAtivas,
                        onSelected: (valor) =>
                            setState(() => _mostrarSomenteAtivas = valor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'O produto continua com seu preço normal no cardápio. Configure cortesias e promoções aqui, sem republicar.',
                  ),
                ),
                const SizedBox(height: 12),
                if (_campanhasExibidas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _mostrarSomenteAtivas
                              ? 'Não há campanhas ativas neste momento.'
                              : 'Não há campanhas cadastradas para este estabelecimento.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ..._campanhasExibidas.map(
                  (x) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Card(
                      child: ListTile(
                        leading: Icon(
                          x['tipo'] == 'PERCENTUAL'
                              ? Icons.percent_rounded
                              : x['tipo'] == 'ROLETA'
                              ? Icons.history_toggle_off_rounded
                              : x['tipo'] == 'PACOTE'
                              ? Icons.local_offer_outlined
                              : Icons.redeem_outlined,
                        ),
                        title: Text('${x['nmcampanha']}'),
                        subtitle: Text(
                          'Produto: ${x['nmproduto'] ?? 'Produto'}\n${x['tipo'] == 'PERCENTUAL'
                              ? 'Promoção: ${x['percentual_desconto']}% OFF'
                              : x['tipo'] == 'ROLETA'
                              ? 'Roleta descontinuada — edite para convertê-la em promoção percentual'
                              : x['tipo'] == 'PACOTE'
                              ? 'Promoção: ${x['qtitenspacote']} por R\$ ${x['vrpacote']}'
                              : 'Cortesia'} • ${x['resgates'] ?? 0} ${(x['tipo'] == 'CORTESIA' || x['tipo'] == 'ROLETA') ? 'resgates' : 'vendas'}\n${_descricaoPeriodo(x)}',
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

class _SelecionarProdutoPage extends StatefulWidget {
  final List<Map<String, dynamic>> produtos;
  final int produtoIdSelecionado;

  const _SelecionarProdutoPage({
    required this.produtos,
    required this.produtoIdSelecionado,
  });

  @override
  State<_SelecionarProdutoPage> createState() => _SelecionarProdutoPageState();
}

class _SelecionarProdutoPageState extends State<_SelecionarProdutoPage> {
  final _buscaController = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _produtosFiltrados {
    final busca = normalizarTextoBusca(_busca);
    if (busca.isEmpty) return widget.produtos;

    return widget.produtos.where((produto) {
      final nome = normalizarTextoBusca('${produto['nmproduto'] ?? ''}');
      final id = '${produto['produto_id'] ?? ''}';
      return nome.contains(busca) || id.contains(busca);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final produtos = _produtosFiltrados;

    return Scaffold(
      appBar: AppBar(title: const Text('Selecione o produto')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _buscaController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (valor) => setState(() => _busca = valor),
              decoration: InputDecoration(
                labelText: 'Pesquisar produto',
                hintText: 'Digite o nome ou código do produto',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _busca.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar pesquisa',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _buscaController.clear();
                          setState(() => _busca = '');
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: produtos.isEmpty
                ? const Center(child: Text('Nenhum produto encontrado.'))
                : ListView.separated(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: produtos.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final produto = produtos[index];
                      final produtoId = int.tryParse(
                        '${produto['produto_id']}',
                      );
                      final selecionado =
                          produtoId == widget.produtoIdSelecionado;

                      return ListTile(
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text('${produto['nmproduto'] ?? 'Produto'}'),
                        trailing: selecionado
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).pop(produto),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
