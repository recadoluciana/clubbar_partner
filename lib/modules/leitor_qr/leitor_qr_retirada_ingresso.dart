import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

import '../../core/services/api_service.dart';
import '../../core/config/api_config.dart';

class LeitorQrRetiradaIngressoScreen extends StatefulWidget {
  const LeitorQrRetiradaIngressoScreen({super.key});

  @override
  State<LeitorQrRetiradaIngressoScreen> createState() =>
      _LeitorQrRetiradaIngressoScreenState();
}

class _LeitorQrRetiradaIngressoScreenState
    extends State<LeitorQrRetiradaIngressoScreen> {
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

  Future<void> tocarBeep() async {
    await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
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

  Future<void> _fecharResultadoDepois() async {
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _processarQr(String raw) async {
    if (processando) return;

    setState(() => processando = true);

    await tocarBeep();

    try {
      final data = jsonDecode(raw);

      final tipo = (data['idtipoproduto'] ?? '').toString().toUpperCase();

      if (tipo != 'I') {
        await tocarErro();
        await vibrarErro();

        if (!mounted) return;

        setState(() {
          processando = false;
          lendoQr = false;
        });

        _mostrarResultado(
          sucesso: false,
          mensagem: 'QR CODE DE RETIRADA DE PRODUTO',
        );

        await _fecharResultadoDepois();
        return;
      }

      final itvendaId = data['itvenda_id'];
      final loja = data['nmloja'];
      final cliente = data['nmcliente'];
      final produto = data['nmproduto'];
      final participante = data['nmparticipante'];
      final cpf = data['cpfparticipante'];

      final fotoUrl = ApiConfig.buildUrl(
        (data['urlfotoproduto'] ?? '').toString(),
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('QR Code do ingresso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                produto.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              if (fotoUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    fotoUrl,
                    height: 140,
                    width: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.image_not_supported, size: 70),
                  ),
                )
              else
                const Icon(
                  Icons.confirmation_number_outlined,
                  size: 80,
                  color: Colors.amber,
                ),

              const SizedBox(height: 14),

              Text(
                'Cliente: $cliente',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),

              if ((participante ?? '').toString().trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Participante: $participante',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],

              if ((cpf ?? '').toString().trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'CPF: $cpf',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
              ],

              const SizedBox(height: 8),

              Text(
                'Estabelecimento: $loja',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
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
                      mensagem: 'INGRESSO JÁ UTILIZADO',
                    );

                    await _fecharResultadoDepois();
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
                      mensagem: 'INGRESSO VALIDADO',
                    );

                    await _fecharResultadoDepois();
                  }
                } catch (e) {
                  if (!mounted) return;

                  Navigator.pop(context);

                  await tocarErro();
                  await vibrarErro();

                  if (!mounted) return;

                  setState(() {
                    processando = false;
                    lendoQr = false;
                  });

                  _mostrarResultado(
                    sucesso: false,
                    mensagem: 'ERRO AO VALIDAR INGRESSO',
                  );

                  await _fecharResultadoDepois();
                }
              },
              child: const Text('Validar ingresso'),
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
      await vibrarErro();

      if (!mounted) return;

      _mostrarResultado(sucesso: false, mensagem: 'QR CODE INVÁLIDO');

      await _fecharResultadoDepois();
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
        title: const Text('Leitor de ingresso'),
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
                width: 280,
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
                    'Ler QR Code do ingresso',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
    );
  }
}
