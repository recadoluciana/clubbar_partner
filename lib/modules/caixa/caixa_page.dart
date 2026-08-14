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
    _carregar();
  }

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
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<Map<String, dynamic>> get _produtosVisiveis => _categoriaId == null
      ? _produtos
      : _produtos
            .where((p) => int.tryParse('${p['categoria_id']}') == _categoriaId)
            .toList();

  String? _imagem(Map<String, dynamic> produto) {
    final valor = '${produto['urlfotoproduto'] ?? ''}'.trim();
    if (valor.isEmpty) return null;
    return valor.startsWith('http') ? valor : ApiConfig.buildUrl(valor);
  }

  Future<void> _adicionar(Map<String, dynamic> produto) async {
    try {
      await _caixa.adicionar(int.parse('${produto['produto_id']}'));
      final carrinho = await _caixa.carrinho();
      if (!mounted) return;
      setState(() => _carrinho = carrinho);
      AppSnackBar.sucesso(context, '${produto['nmproduto']} adicionado.');
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                if (_itens.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Carrinho vazio.', textAlign: TextAlign.center),
                  ),
                ..._itens.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${item['nmproduto']}'),
                    subtitle: Text('${item['qtitcarrinho']} unidade(s)'),
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
                              );
                              final carrinho = await _caixa.carrinho();
                              if (!mounted) return;
                              setState(() => _carrinho = carrinho);
                              if (sheetContext.mounted) setLocal(() {});
                            } catch (e) {
                              if (mounted) {
                                AppSnackBar.erro(
                                  this.context,
                                  e.toString().replaceFirst('Exception: ', ''),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
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
      final restante = ValueNotifier<int>(600);
      final relogio = Timer.periodic(const Duration(seconds: 1), (_) {
        if (restante.value > 0) restante.value--;
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
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Peça ao cliente para escanear o QR Code.'),
                const SizedBox(height: 16),
                if (imagem.isNotEmpty)
                  Image.memory(base64Decode(imagem), width: 260, height: 260),
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
                  if (acaoEmAndamento) return;
                  acaoEmAndamento = true;
                  try {
                    final retorno = await _caixa.simularPagamentoPix(id);
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text('${retorno['mensagem']}')),
                      );
                    }
                  } catch (e) {
                    acaoEmAndamento = false;
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Exception: ', ''),
                          ),
                        ),
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
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Código Pix copiado.')),
                  );
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
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceFirst('Exception: ', ''),
                        ),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Cancelar PIX e editar pedido'),
            ),
          ],
        ),
      );
      dialogoAberto = false;
      relogio.cancel();
      restante.dispose();
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
    appBar: ClubbarAppBar(
      mostrarSair: true,
      onSair: _sair,
      actions: [
        IconButton(
          tooltip: 'Reimprimir ultima venda',
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
    body: _carregando || _contexto == null
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              ClubbarPageHeader(
                titulo: 'Cardápio Digital',
                subtitulo: '${_contexto!['nmloja']} • Frente de Caixa',
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
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('Todos'),
                        selected: _categoriaId == null,
                        onSelected: (_) => setState(() => _categoriaId = null),
                      ),
                    ),
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
                          onTap: () => _adicionar(produto),
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
                                    const SizedBox(height: 6),
                                    const Row(
                                      children: [
                                        Icon(Icons.add_shopping_cart, size: 17),
                                        SizedBox(width: 4),
                                        Text('Adicionar'),
                                      ],
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
