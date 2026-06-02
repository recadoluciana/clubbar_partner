import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/services/api_service.dart';
import 'package:vibration/vibration.dart';

class LeitorQrRetiradaScreen extends StatefulWidget {
  const LeitorQrRetiradaScreen({super.key});

  @override
  State<LeitorQrRetiradaScreen> createState() => _LeitorQrRetiradaScreenState();
}

class _LeitorQrRetiradaScreenState extends State<LeitorQrRetiradaScreen> {
  bool processando = false;
  bool lendoQr = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> vibrarSucesso() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 200);
    }
  }

  Future<void> vibrarErro() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 300, 150, 300]);
    }
  }

  Future<void> tocarOk() async {
    await _audioPlayer.play(AssetSource('sounds/ok.mp3'));
  }

  Future<void> tocarErro() async {
    await _audioPlayer.play(AssetSource('sounds/error.mp3'));
  }

  Future<void> _mostrarResultado({
    required bool sucesso,
    required String mensagem,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: sucesso ? Colors.green : Colors.red,
        title: Icon(
          sucesso ? Icons.check_circle : Icons.cancel,
          color: Colors.white,
          size: 82,
        ),
        content: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _processarQr(String raw) async {
    if (processando) return;

    setState(() => processando = true);

    try {
      final data = jsonDecode(raw);

      final itvendaId = data['itvenda_id'];
      final loja = data['nmloja'];
      final cliente = data['nmcliente'];
      final produto = data['nmproduto'];
      final observacao = data['dsobsitvenda'];

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('QR Code lido'),
          content: Text(
            'Cliente: $cliente\n'
            'Estabelecimento: $loja\n'
            'Produto: $produto\n'
            'Observação: ${observacao ?? ""}\n'
            'Item Venda: $itvendaId',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);

                setState(() {
                  processando = false;
                  lendoQr = false;
                });
              },
              child: const Text('Fechar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final resposta = await ApiService.confirmarRetirada(
                    itvendaId: itvendaId is int
                        ? itvendaId
                        : int.parse(itvendaId.toString()),
                  );

                  if (!mounted) return;

                  Navigator.pop(context);

                  if (resposta['already'] == true) {
                    await tocarErro();
                    await vibrarErro();

                    if (!mounted) return;

                    setState(() {
                      processando = false;
                      lendoQr = false;
                    });

                    _mostrarResultado(
                      sucesso: false,
                      mensagem: 'PRODUTO JÁ ENTREGUE',
                    );

                    await Future.delayed(const Duration(seconds: 2));

                    if (mounted) {
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                  } else {
                    await tocarOk();
                    await vibrarSucesso();

                    if (!mounted) return;

                    setState(() {
                      processando = false;
                      lendoQr = false;
                    });

                    _mostrarResultado(
                      sucesso: true,
                      mensagem: 'PRODUTO ENTREGUE',
                    );

                    await Future.delayed(const Duration(seconds: 2));

                    if (mounted) {
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                  }
                } catch (e) {
                  if (!mounted) return;

                  Navigator.pop(context);

                  await tocarErro();
                  await tocarErro();
                  await vibrarErro();

                  if (!mounted) return;

                  setState(() {
                    processando = false;
                    lendoQr = false;
                  });

                  _mostrarResultado(
                    sucesso: false,
                    mensagem: 'ERRO NA RETIRADA',
                  );

                  await Future.delayed(const Duration(seconds: 2));

                  if (mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                }
              },
              child: const Text('Confirmar retirada'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        processando = false;
        lendoQr = false;
      });

      await tocarErro();

      if (!mounted) return;

      _mostrarResultado(sucesso: false, mensagem: 'QR CODE INVÁLIDO');

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Leitor de retirada'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (lendoQr)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  lendoQr = false;
                  processando = false;
                });
              },
            ),
        ],
      ),
      body: lendoQr
          ? Stack(
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    final barcode = capture.barcodes.firstOrNull;
                    final raw = barcode?.rawValue;

                    if (raw != null && raw.isNotEmpty) {
                      _processarQr(raw);
                    }
                  },
                ),
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFFFC107),
                        width: 4,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: SizedBox(
                width: 260,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      lendoQr = true;
                      processando = false;
                    });
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text(
                    'Ler QR Code',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
    );
  }
}
