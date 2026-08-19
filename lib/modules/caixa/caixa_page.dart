import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/api_config.dart';
import '../../core/repositories/categoria_repository.dart';
import '../../core/repositories/produto_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_footer.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/categoria.dart';
import '../auth/login_page.dart';
import 'caixa_repository.dart';

class CaixaPage extends StatefulWidget {
  const CaixaPage({super.key});

  @override
  State<CaixaPage> createState() => _CaixaPageState();
}

class _CaixaPageState extends State<CaixaPage> {
  final _caixa = CaixaRepository();
  final _categoriasRepo = CategoriaRepository();
  final _produtosRepo = ProdutoRepository();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  Map<String, dynamic>? _contexto;
  Map<String, dynamic> _carrinho = const {'itens': [], 'total': 0};
  List<Categoria> _categorias = [];
  List<Map<String, dynamic>> _produtos = [];
  int? _categoriaId;
  bool _carregando = true;
  bool _checkoutEmAndamento = false;
  final _buscaController = TextEditingController();
  String _busca = '';
  String _nomeUsuario = 'Usuário';
  String _cargo = 'Caixa';
  DateTime _agora = DateTime.now();
  Timer? _relogioCabecalho;

  List<Map<String, dynamic>> get _itens => (_carrinho['itens'] as List? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  int get _quantidade => _itens.fold(
    0,
    (total, item) => total + (int.tryParse('${item['qtitcarrinho']}') ?? 0),
  );
  double get _total => double.tryParse('${_carrinho['total'] ?? 0}') ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ClubbarFooter.visibility.value = false;
    });
    _carregarIdentificacao();
    _relogioCabecalho = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _agora = DateTime.now());
    });
    _carregar();
  }

  @override
  void dispose() {
    _relogioCabecalho?.cancel();
    _buscaController.dispose();
    ClubbarFooter.visibility.value = true;
    super.dispose();
  }

  Future<void> _carregarIdentificacao() async {
    final dados = await Future.wait([
      StorageService.getNomeUsuario(),
      StorageService.getCargo(),
    ]);
    if (!mounted) return;
    setState(() {
      _nomeUsuario = dados[0]?.trim().isNotEmpty == true
          ? dados[0]!.trim()
          : 'Usuário';
      _cargo = _formatarCargo(dados[1] ?? 'Caixa');
    });
  }

  String _formatarCargo(String valor) => valor
      .trim()
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .where((parte) => parte.isNotEmpty)
      .map((parte) => '${parte[0].toUpperCase()}${parte.substring(1)}')
      .join(' ');

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final contexto = await _caixa.contexto();
      final lojaId = int.parse('${contexto['loja_id']}');
      final resultados = await Future.wait([
        _categoriasRepo.listar(lojaId),
        _produtosRepo.listar(lojaId),
        _caixa.carrinho(),
      ]);
      if (!mounted) return;
      setState(() {
        _contexto = contexto;
        _categorias = (resultados[0] as List<Categoria>)
            .where((c) => (c.sitcategoria ?? 'ATIVA').toUpperCase() == 'ATIVA')
            .toList();
        _produtos = (resultados[1] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where(
              (p) =>
                  '${p['sitproduto'] ?? 'ATIVO'}'.toUpperCase() == 'ATIVO' &&
                  '${p['idtipoproduto'] ?? 'P'}'.toUpperCase() == 'P',
            )
            .toList();
        _carrinho = resultados[2] as Map<String, dynamic>;
        if (_categorias.isNotEmpty &&
            !_categorias.any((c) => c.categoriaId == _categoriaId)) {
          _categoriaId = _categorias.first.categoriaId;
        }
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<Map<String, dynamic>> get _produtosVisiveis {
    final termo = _busca.trim().toLowerCase();
    return _produtos.where((produto) {
      final pertenceCategoria =
          int.tryParse('${produto['categoria_id']}') == _categoriaId;
      final texto =
          '${produto['nmproduto'] ?? ''} '
                  '${produto['dsproduto'] ?? ''} ${produto['nmcategoria'] ?? ''}'
              .toLowerCase();
      return pertenceCategoria && (termo.isEmpty || texto.contains(termo));
    }).toList();
  }

  String? _imagem(Map<String, dynamic> produto) {
    final valor = '${produto['urlfotoproduto'] ?? ''}'.trim();
    if (valor.isEmpty) return null;
    return valor.startsWith('http') ? valor : ApiConfig.buildUrl(valor);
  }

  Future<void> _abrirProduto(Map<String, dynamic> produto) async {
    final pedido = await Navigator.push<_ProdutoPedido>(
      context,
      MaterialPageRoute(
        builder: (_) => _ProdutoCashierPage(
          produto: produto,
          imagem: _imagem(produto),
          moeda: _moeda,
        ),
      ),
    );
    if (pedido == null) return;
    try {
      await _caixa.adicionar(
        int.parse('${produto['produto_id']}'),
        quantidade: pedido.quantidade,
        observacao: pedido.observacao,
      );
      final carrinho = await _caixa.carrinho();
      if (!mounted) return;
      setState(() => _carrinho = carrinho);
      AppSnackBar.sucesso(
        context,
        '${pedido.quantidade}x ${produto['nmproduto']} adicionado ao carrinho.',
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _abrirCarrinho() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setLocal) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .82,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Carrinho do Caixa',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cliente: ${_contexto?['cliente_nome'] ?? 'Consumidor nao identificado'}',
                  ),
                  const Divider(height: 28),
                  Expanded(
                    child: _itens.isEmpty
                        ? const Center(child: Text('Carrinho vazio.'))
                        : ListView.builder(
                            itemCount: _itens.length,
                            itemBuilder: (_, index) {
                              final item = _itens[index];
                              final observacao = '${item['dsobsitcar'] ?? ''}'
                                  .trim();
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('${item['nmproduto']}'),
                                subtitle: Text(
                                  '${item['qtitcarrinho']} unidade(s)'
                                  '${observacao.isEmpty ? '' : '\nObs.: $observacao'}',
                                ),
                                isThreeLine: observacao.isNotEmpty,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_moeda.format(item['subtotal'] ?? 0)),
                                    IconButton(
                                      tooltip: 'Remover uma unidade',
                                      onPressed: () async {
                                        try {
                                          await _caixa.removerUmaUnidade(
                                            int.parse('${item['produto_id']}'),
                                            observacao: observacao,
                                          );
                                          final carrinho = await _caixa
                                              .carrinho();
                                          if (!mounted) return;
                                          setState(() => _carrinho = carrinho);
                                          if (sheetContext.mounted) {
                                            setLocal(() {});
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            AppSnackBar.erro(
                                              this.context,
                                              e.toString().replaceFirst(
                                                'Exception: ',
                                                '',
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                      color: Colors.redAccent,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(),
                  Text(
                    'Total: ${_moeda.format(_total)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _itens.isEmpty || _checkoutEmAndamento
                        ? null
                        : () async {
                            Navigator.pop(sheetContext);
                            await _iniciarPix();
                          },
                    icon: const Icon(Icons.payments_rounded),
                    label: const Text('Receber por Pix agora'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _itens.isEmpty || _checkoutEmAndamento
                        ? null
                        : () async {
                            Navigator.pop(sheetContext);
                            await _iniciarCartao();
                          },
                    icon: const Icon(Icons.credit_card_rounded),
                    label: const Text('Receber por cartão'),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _itens.isEmpty
                        ? null
                        : () async {
                            Navigator.pop(sheetContext);
                            await _limparCarrinho();
                          },
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Limpar carrinho'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _iniciarCartao() async {
    setState(() => _checkoutEmAndamento = true);
    try {
      final checkout = await _caixa.checkoutCartao();
      final id = '${checkout['pagamento_id']}';
      final url = Uri.parse('${checkout['checkout_url']}');
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      await _aguardarConfirmacao(id);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _checkoutEmAndamento = false);
    }
  }

  Future<void> _iniciarPix() async {
    setState(() => _checkoutEmAndamento = true);
    try {
      final pix = await _caixa.checkoutPix();
      final id = '${pix['pagamento_id']}';
      final imagem = '${pix['encoded_image'] ?? ''}'.split(',').last;
      final payload = '${pix['payload'] ?? ''}';
      final simulacaoDisponivel = pix['simulacao_sandbox_disponivel'] == true;
      await _carregar();
      if (!mounted) return;
      var dialogoAberto = true;
      var acaoEmAndamento = false;
      var simulacaoEnviada = false;
      final restante = ValueNotifier<int>(600);
      final relogio = Timer.periodic(const Duration(seconds: 1), (_) {
        if (restante.value > 0) restante.value--;
        if (restante.value == 0 && dialogoAberto && mounted) {
          dialogoAberto = false;
          Navigator.of(context, rootNavigator: true).pop();
        }
      });
      unawaited(
        _aguardarConfirmacao(
          id,
          silencioso: true,
          deveContinuar: () => dialogoAberto,
          aoConfirmar: () {
            if (dialogoAberto && mounted) Navigator.of(context).pop();
          },
        ),
      );
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Receber por Pix'),
          content: SizedBox(
            width: 310,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Peça ao cliente para escanear o QR Code.'),
                const SizedBox(height: 16),
                if (imagem.isNotEmpty)
                  Image.memory(base64Decode(imagem), width: 210, height: 210),
                const SizedBox(height: 12),
                ValueListenableBuilder<int>(
                  valueListenable: restante,
                  builder: (_, segundos, child) => Text(
                    'Aguardando confirmacao do Asaas... '
                    '${(segundos ~/ 60).toString().padLeft(2, '0')}:'
                    '${(segundos % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (simulacaoDisponivel)
              FilledButton.tonalIcon(
                onPressed: () async {
                  if (acaoEmAndamento || simulacaoEnviada) return;
                  acaoEmAndamento = true;
                  simulacaoEnviada = true;
                  try {
                    final retorno = await _caixa.simularPagamentoPix(id);
                    acaoEmAndamento = false;
                    if (dialogContext.mounted) {
                      AppSnackBar.info(dialogContext, '${retorno['mensagem']}');
                    }
                  } catch (e) {
                    acaoEmAndamento = false;
                    simulacaoEnviada = false;
                    if (dialogContext.mounted) {
                      AppSnackBar.erro(
                        dialogContext,
                        e.toString().replaceFirst('Exception: ', ''),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.science_outlined),
                label: const Text('Simular pagamento (Sandbox)'),
              ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: payload));
                if (dialogContext.mounted) {
                  AppSnackBar.info(dialogContext, 'C\u00f3digo Pix copiado.');
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar Pix'),
            ),
            TextButton.icon(
              onPressed: () async {
                if (acaoEmAndamento) return;
                acaoEmAndamento = true;
                try {
                  await _caixa.cancelarPix(id);
                  await _carregar();
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) {
                    AppSnackBar.sucesso(
                      context,
                      'QR Code cancelado. O carrinho foi liberado para edicao.',
                    );
                  }
                } catch (e) {
                  acaoEmAndamento = false;
                  if (dialogContext.mounted) {
                    AppSnackBar.erro(
                      dialogContext,
                      e.toString().replaceFirst('Exception: ', ''),
                    );
                  }
                }
              },
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Cancelar PIX e editar pedido'),
            ),
            TextButton.icon(
              onPressed: acaoEmAndamento
                  ? null
                  : () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Fechar e continuar'),
            ),
          ],
        ),
      );
      final tempoEsgotado = restante.value == 0;
      dialogoAberto = false;
      relogio.cancel();
      restante.dispose();
      if (tempoEsgotado && mounted) {
        AppSnackBar.info(
          context,
          'Tempo de espera encerrado. O pagamento pode ser consultado depois.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _checkoutEmAndamento = false);
    }
  }

  Future<void> _aguardarConfirmacao(
    String id, {
    bool silencioso = false,
    bool Function()? deveContinuar,
    VoidCallback? aoConfirmar,
  }) async {
    if (!silencioso && mounted) {
      AppSnackBar.aviso(context, 'Aguardando a confirmação do pagamento...');
    }
    try {
      for (var tentativa = 0; tentativa < 300; tentativa++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (deveContinuar != null && !deveContinuar()) return;
        final retorno = await _caixa.tickets(id);
        if ('${retorno['status']}'.toUpperCase() == 'PAGO') {
          final tickets = (retorno['tickets'] as List? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          await _imprimirTickets(tickets, int.parse('${retorno['venda_id']}'));
          await _carregar();
          if (mounted) {
            aoConfirmar?.call();
            AppSnackBar.sucesso(
              context,
              'Pagamento confirmado e tickets gerados.',
            );
          }
          return;
        }
      }
      if (mounted) {
        AppSnackBar.aviso(
          context,
          'Pagamento ainda não confirmado. Consulte novamente em instantes.',
        );
      }
    } catch (e) {
      if (silencioso) aoConfirmar?.call();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _imprimirTickets(
    List<Map<String, dynamic>> tickets,
    int vendaId, {
    bool segundaVia = false,
  }) async {
    if (tickets.isEmpty) {
      throw Exception('A venda foi paga, mas não retornou tickets.');
    }
    final documento = pw.Document();
    for (final ticket in tickets) {
      documento.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            80 * PdfPageFormat.mm,
            120 * PdfPageFormat.mm,
          ),
          margin: const pw.EdgeInsets.all(8 * PdfPageFormat.mm),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'CLUBBAR',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('${ticket['loja']}', textAlign: pw.TextAlign.center),
              if (segundaVia)
                pw.Text(
                  'SEGUNDA VIA',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              pw.Divider(),
              pw.Text(
                '${ticket['produto']}',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if ('${ticket['observacao'] ?? ''}'.trim().isNotEmpty)
                pw.Text(
                  'Obs.: ${ticket['observacao']}',
                  textAlign: pw.TextAlign.center,
                ),
              pw.SizedBox(height: 8),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: '${ticket['qr_token']}',
                width: 42 * PdfPageFormat.mm,
                height: 42 * PdfPageFormat.mm,
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Venda #$vendaId • Item #${ticket['itvenda_id']}',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Text(
                'Apresente este QR Code ao Barman ou Garçom.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
      );
    }
    await Printing.layoutPdf(
      onLayout: (_) => documento.save(),
      name: 'tickets-clubbar-venda-$vendaId.pdf',
    );
  }

  Future<void> _limparCarrinho() async {
    try {
      await _caixa.limparCarrinho();
      await _carregar();
      if (mounted) AppSnackBar.sucesso(context, 'Carrinho limpo.');
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _reimprimirUltimaVenda() async {
    try {
      final retorno = await _caixa.ticketsUltimaVenda();
      final tickets = (retorno['tickets'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      await _imprimirTickets(
        tickets,
        int.parse('${retorno['venda_id']}'),
        segundaVia: true,
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _sair() async {
    await StorageService.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: ClubbarAppBar(mostrarSair: true, onSair: _sair),
    body: _carregando || _contexto == null
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              ClubbarPageHeader(
                titulo: 'Clubbar Cashier - ${_contexto!['nmloja']}',
                subtitulo:
                    '$_nomeUsuario • $_cargo • ${_contexto!['nmloja']} • '
                    '${DateFormat('dd/MM/yyyy HH:mm:ss', 'pt_BR').format(_agora)}',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Reimprimir última venda',
                      onPressed: _reimprimirUltimaVenda,
                      icon: const Icon(Icons.print_rounded),
                    ),
                    IconButton(
                      tooltip: 'Carrinho ($_quantidade)',
                      onPressed: _abrirCarrinho,
                      icon: Badge(
                        isLabelVisible: _quantidade > 0,
                        label: Text('$_quantidade'),
                        child: const Icon(Icons.shopping_cart_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                child: TextField(
                  controller: _buscaController,
                  onChanged: (valor) => setState(() => _busca = valor),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Buscar produto',
                    hintText: 'Digite o nome ou a descrição',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _busca.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar busca',
                            onPressed: () {
                              _buscaController.clear();
                              setState(() => _busca = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                height: 58,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._categorias.map(
                      (categoria) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(categoria.nmcategoria),
                          selected: _categoriaId == categoria.categoriaId,
                          onSelected: (_) => setState(
                            () => _categoriaId = categoria.categoriaId,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _carregar,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: .72,
                        ),
                    itemCount: _produtosVisiveis.length,
                    itemBuilder: (_, index) {
                      final produto = _produtosVisiveis[index];
                      final imagem = _imagem(produto);
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _abrirProduto(produto),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ColoredBox(
                                  color: Colors.white,
                                  child: imagem == null
                                      ? const Icon(
                                          Icons.fastfood_rounded,
                                          size: 50,
                                        )
                                      : Image.network(
                                          imagem,
                                          fit: BoxFit.contain,
                                        ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${produto['nmproduto']}',
                                      maxLines: 2,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      _moeda.format(
                                        double.tryParse(
                                              '${produto['vrprecoprod']}',
                                            ) ??
                                            0,
                                      ),
                                    ),
                                  ],
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
  );
}

class _ProdutoPedido {
  final int quantidade;
  final String observacao;

  const _ProdutoPedido(this.quantidade, this.observacao);
}

class _ProdutoCashierPage extends StatefulWidget {
  final Map<String, dynamic> produto;
  final String? imagem;
  final NumberFormat moeda;

  const _ProdutoCashierPage({
    required this.produto,
    required this.imagem,
    required this.moeda,
  });

  @override
  State<_ProdutoCashierPage> createState() => _ProdutoCashierPageState();
}

class _ProdutoCashierPageState extends State<_ProdutoCashierPage> {
  final _observacaoController = TextEditingController();
  int _quantidade = 1;

  double _numero(Object? valor) =>
      double.tryParse('${valor ?? 0}'.replaceAll(',', '.')) ?? 0;

  @override
  void dispose() {
    _observacaoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final produto = widget.produto;
    final descricao = '${produto['dsproduto'] ?? ''}'.trim();
    final preco = _numero(produto['vrprecofinal'] ?? produto['vrprecoprod']);
    final precoOriginal = _numero(produto['vrprecoprod']);
    final temDesconto =
        produto['descontoativo'] == true && precoOriginal > preco;

    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (widget.imagem != null)
              Container(
                height: 260,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Image.network(
                  widget.imagem!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.fastfood_rounded, size: 72),
                ),
              )
            else
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: ClubbarColors.ambarClaro,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.fastfood_rounded, size: 72),
              ),
            const SizedBox(height: 20),
            Text(
              '${produto['nmproduto']}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '${produto['nmcategoria'] ?? 'Sem categoria'}',
              style: const TextStyle(
                color: ClubbarColors.textoSecundario,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (descricao.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(descricao, style: const TextStyle(fontSize: 16)),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  widget.moeda.format(preco),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (temDesconto) ...[
                  const SizedBox(width: 10),
                  Text(
                    widget.moeda.format(precoOriginal),
                    style: const TextStyle(
                      color: ClubbarColors.textoSecundario,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 34),
            const Text(
              'Quantidade',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _quantidade > 1
                      ? () => setState(() => _quantidade--)
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '$_quantidade',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: () => setState(() => _quantidade++),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _observacaoController,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observação',
                hintText: 'Ex.: sem gelo, retirar cebola...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                _ProdutoPedido(_quantidade, _observacaoController.text.trim()),
              ),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: Text(
                'Adicionar $_quantidade ao carrinho • '
                '${widget.moeda.format(preco * _quantidade)}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
