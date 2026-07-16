import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';

import '../../../core/config/api_config.dart';
import '../../../core/services/api_service.dart';
import 'package:flutter/services.dart';

class LeitorQrRetiradaScreen extends StatefulWidget {
  const LeitorQrRetiradaScreen({super.key});

  @override
  State<LeitorQrRetiradaScreen> createState() => _LeitorQrRetiradaScreenState();
}

class _LeitorQrRetiradaScreenState extends State<LeitorQrRetiradaScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool processando = false;
  bool lendoQr = false;
  bool confirmandoRetirada = false;

  static const String _prefixoProduto = 'CLUBBAR-PRODUTO:';

  @override
  void dispose() {
    _scannerController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> vibrarSucesso() async {
    final possuiVibrador = await Vibration.hasVibrator() ?? false;

    if (possuiVibrador) {
      await Vibration.vibrate(duration: 200);
    }
  }

  Future<void> vibrarErro() async {
    final possuiVibrador = await Vibration.hasVibrator() ?? false;

    if (possuiVibrador) {
      await Vibration.vibrate(pattern: [0, 300, 150, 300]);
    }
  }

  Future<void> tocarOk() async {
    await _audioPlayer.play(AssetSource('sounds/ok.mp3'));
  }

  Future<void> tocarErro() async {
    await _audioPlayer.play(AssetSource('sounds/error.mp3'));
  }

  Future<void> tocarBeep() async {
    await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
  }

  Future<void> _mostrarDiagnostico({
    required String titulo,
    required String conteudo,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF6F6F6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 90,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 430),
            child: SingleChildScrollView(
              child: SelectableText(
                conteudo,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: conteudo));

                if (!dialogContext.mounted) return;

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Diagnóstico copiado.')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  String _extrairToken(String valorLido) {
    final texto = valorLido.trim();

    if (!texto.startsWith(_prefixoProduto)) {
      throw Exception('Este QR Code não pertence a um produto Clubbar.');
    }

    final token = texto.substring(_prefixoProduto.length).trim();

    if (token.isEmpty) {
      throw Exception('Token do produto não encontrado.');
    }

    return token;
  }

  String _mensagemErro(Object erro) {
    final texto = erro.toString().replaceFirst('Exception: ', '').trim();

    if (texto.isEmpty) {
      return 'Não foi possível processar o QR Code.';
    }

    return texto;
  }

  bool _produtoJaUtilizado(Map<String, dynamic> produto) {
    final entregue = (produto['identregaitvenda'] ?? produto['entregue'] ?? '')
        .toString()
        .trim()
        .toUpperCase();

    final status = (produto['status'] ?? produto['situacao'] ?? '')
        .toString()
        .trim()
        .toUpperCase();

    final disponivel = produto['disponivel'];

    return entregue == 'SIM' ||
        status == 'UTILIZADO' ||
        status == 'ENTREGUE' ||
        disponivel == false;
  }

  String _textoCampo(
    Map<String, dynamic> dados,
    List<String> nomes, {
    String padrao = '',
  }) {
    for (final nome in nomes) {
      final valor = dados[nome];

      if (valor != null && valor.toString().trim().isNotEmpty) {
        return valor.toString().trim();
      }
    }

    return padrao;
  }

  Future<void> _iniciarLeitura() async {
    if (!mounted) return;

    setState(() {
      lendoQr = true;
      processando = false;
      confirmandoRetirada = false;
    });

    try {
      await _scannerController.start();
    } catch (_) {
      // A câmera pode já estar iniciada.
    }
  }

  Future<void> _pararLeitura() async {
    try {
      await _scannerController.stop();
    } catch (_) {
      // Evita falha caso a câmera já esteja parada.
    }

    if (!mounted) return;

    setState(() {
      lendoQr = false;
      processando = false;
      confirmandoRetirada = false;
    });
  }

  Future<void> _prepararNovaLeitura() async {
    if (!mounted) return;

    setState(() {
      processando = false;
      confirmandoRetirada = false;
      lendoQr = true;
    });

    await Future.delayed(const Duration(milliseconds: 350));

    try {
      await _scannerController.start();
    } catch (_) {
      // Ignora se a câmera já estiver ativa.
    }
  }

  Future<void> _mostrarResultado({
    required bool sucesso,
    required String titulo,
    required String mensagem,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final cor = sucesso ? Colors.green.shade700 : Colors.red.shade700;

        return AlertDialog(
          backgroundColor: cor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Icon(
            sucesso ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: Colors.white,
            size: 82,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                mensagem,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: TextButton.styleFrom(
                foregroundColor: cor,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 11,
                ),
              ),
              child: const Text(
                'Continuar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processarQr(String raw) async {
    if (processando) return;

    setState(() {
      processando = true;
    });

    await _scannerController.stop();
    await tocarBeep();

    try {
      final token = _extrairToken(
        raw,
      ); // extrai o token do QR code lido e depois busca o produto na API

      debugPrint('TOKEN LIDO: $token');

      /*
       * Troque apenas o nome deste método caso seu ApiService
       * use outra nomenclatura.
       *
       * A resposta esperada é um Map com os dados do produto.
       */
      final produto = await ApiService.buscarProdutoPorToken(token: token);

      if (!mounted) return;

      await _abrirConfirmacaoProduto(token: token, produto: produto);
    } catch (e) {
      await tocarErro();
      await vibrarErro();

      if (!mounted) return;

      final mensagem = _mensagemErro(e);

      await _mostrarDiagnostico(
        titulo: 'Produto de outro bar/casa noturna',
        conteudo: mensagem,
      );

      await _prepararNovaLeitura();
    }
  }

  Future<void> _abrirConfirmacaoProduto({
    required String token,
    required Map<String, dynamic> produto,
  }) async {
    final nomeProduto = _textoCampo(produto, [
      'nmproduto',
      'produto',
      'nome_produto',
    ], padrao: 'Produto Clubbar');

    final nomeCliente = _textoCampo(produto, [
      'nmcliente',
      'cliente',
      'nome_cliente',
    ], padrao: 'Não informado');

    final nomeLoja = _textoCampo(produto, [
      'nmloja',
      'loja',
      'nome_loja',
    ], padrao: 'Estabelecimento não informado');

    final observacao = _textoCampo(produto, ['dsobsitvenda', 'observacao']);

    final caminhoFoto = _textoCampo(produto, [
      'urlfotoproduto',
      'foto',
      'foto_url',
    ]);

    final fotoUrl = ApiConfig.buildUrl(caminhoFoto);
    final jaUtilizado = _produtoJaUtilizado(produto);

    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF6F6F6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titlePadding: EdgeInsets.zero,
              contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              title: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                decoration: BoxDecoration(
                  color: jaUtilizado
                      ? Colors.red.shade700
                      : Colors.green.shade700,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      jaUtilizado
                          ? Icons.cancel_rounded
                          : Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        jaUtilizado
                            ? 'Produto já utilizado'
                            : 'Produto disponível',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (fotoUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            fotoUrl,
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) {
                              return _placeholderProduto();
                            },
                          ),
                        )
                      else
                        _placeholderProduto(),

                      const SizedBox(height: 16),

                      Text(
                        nomeProduto,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 14),

                      _linhaInformacao(
                        icone: Icons.person_outline_rounded,
                        titulo: 'Cliente',
                        valor: nomeCliente,
                      ),

                      const SizedBox(height: 10),

                      _linhaInformacao(
                        icone: Icons.storefront_outlined,
                        titulo: 'Estabelecimento',
                        valor: nomeLoja,
                      ),

                      if (observacao.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.priority_high_rounded,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Observação',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      observacao,
                                      style: TextStyle(
                                        color: Colors.red.shade800,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (jaUtilizado) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Este produto não pode ser entregue novamente.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                ElevatedButton.icon(
                  onPressed: confirmandoRetirada
                      ? null
                      : () {
                          Navigator.pop(dialogContext, false);
                        },
                  icon: Icon(
                    jaUtilizado ? Icons.close_rounded : Icons.cancel_rounded,
                    size: 20,
                  ),
                  label: Text(
                    jaUtilizado ? 'Fechar' : 'Cancelar',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(120, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

                if (!jaUtilizado)
                  ElevatedButton.icon(
                    onPressed: confirmandoRetirada
                        ? null
                        : () async {
                            setDialogState(() {
                              confirmandoRetirada = true;
                            });

                            final sucesso = await _confirmarRetiradaPorToken(
                              token: token,
                              dialogContext: dialogContext,
                            );

                            if (!dialogContext.mounted) return;

                            if (!sucesso) {
                              setDialogState(() {
                                confirmandoRetirada = false;
                              });
                            }
                          },
                    icon: confirmandoRetirada
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      confirmandoRetirada
                          ? 'Confirmando...'
                          : 'Confirmar retirada',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (resultado != true) {
      await _prepararNovaLeitura();
    }
  }

  Future<bool> _confirmarRetiradaPorToken({
    required String token,
    required BuildContext dialogContext,
  }) async {
    try {
      /*
       * Troque apenas o nome deste método se a sua função
       * no ApiService tiver outro nome.
       */
      final resposta = await ApiService.confirmarRetiradaPorToken(token: token);

      if (!mounted) return false;

      Navigator.pop(dialogContext, true);

      final jaEntregue =
          resposta['already'] == true || resposta['ja_utilizado'] == true;

      if (jaEntregue) {
        await tocarErro();
        await vibrarErro();

        if (!mounted) return false;

        await _mostrarResultado(
          sucesso: false,
          titulo: 'Produto já utilizado',
          mensagem: 'Este produto já havia sido entregue anteriormente.',
        );
      } else {
        await tocarOk();
        await vibrarSucesso();

        if (!mounted) return false;

        await _mostrarResultado(
          sucesso: true,
          titulo: 'Produto entregue',
          mensagem: 'A retirada foi confirmada com sucesso.',
        );
      }

      await _prepararNovaLeitura();

      return true;
    } catch (e) {
      if (!mounted) return false;

      final mensagem = _mensagemErro(e);
      final jaUtilizado =
          mensagem.toLowerCase().contains('já foi utilizado') ||
          mensagem.toLowerCase().contains('ja foi utilizado') ||
          mensagem.toLowerCase().contains('já utilizado') ||
          mensagem.toLowerCase().contains('ja utilizado');

      await tocarErro();
      await vibrarErro();

      if (!mounted) return false;

      Navigator.pop(dialogContext, true);

      await _mostrarResultado(
        sucesso: false,
        titulo: jaUtilizado ? 'Produto já utilizado' : 'Erro na retirada',
        mensagem: mensagem,
      );

      await _prepararNovaLeitura();

      return true;
    }
  }

  Widget _placeholderProduto() {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        Icons.local_bar_rounded,
        size: 72,
        color: Colors.amber.shade800,
      ),
    );
  }

  Widget _linhaInformacao({
    required IconData icone,
    required String titulo,
    required String valor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: Colors.black87, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _areaLeitura() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            if (processando) return;
            if (capture.barcodes.isEmpty) return;

            final raw = capture.barcodes.first.rawValue;

            if (raw == null || raw.trim().isEmpty) return;

            _processarQr(raw);
          },
        ),

        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 0.75,
              colors: [Colors.transparent, Colors.black.withOpacity(0.58)],
              stops: const [0.55, 1],
            ),
          ),
        ),

        Center(
          child: Container(
            width: 270,
            height: 270,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.amber, width: 4),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),

        Positioned(
          left: 24,
          right: 24,
          bottom: 34,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.72),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              processando
                  ? 'Consultando produto...'
                  : 'Centralize o QR Code dentro da moldura',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),

        if (processando)
          Container(
            color: Colors.black.withOpacity(0.28),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: Colors.amber),
          ),
      ],
    );
  }

  Widget _telaInicialLeitor() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 50,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Leitor de retirada',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),

                const SizedBox(height: 8),

                Text(
                  'Leia o QR Code do produto exibido no aplicativo '
                  'do cliente ou em uma imagem de presente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _iniciarLeitura,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 24),
                    label: const Text(
                      'Ler QR Code',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lendoQr ? Colors.black : const Color(0xFFF6F6F6),

      appBar: AppBar(
        title: const Text(
          'Leitor de retirada',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          if (lendoQr)
            IconButton(
              tooltip: 'Fechar câmera',
              icon: const Icon(Icons.close_rounded),
              onPressed: processando ? null : _pararLeitura,
            ),
        ],
      ),

      body: lendoQr ? _areaLeitura() : _telaInicialLeitor(),
    );
  }
}
