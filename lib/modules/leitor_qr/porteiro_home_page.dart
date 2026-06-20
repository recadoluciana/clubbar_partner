import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../leitor_qr/leitor_qr_retirada_ingresso.dart';
import '../auth/login_page.dart';
import '../../core/services/storage_service.dart';

class PorteiroHomePage extends StatefulWidget {
  const PorteiroHomePage({super.key});

  @override
  State<PorteiroHomePage> createState() => _PorteiroHomePageState();
}

class _PorteiroHomePageState extends State<PorteiroHomePage> {
  String nomeUsuario = '';
  String dataHoraAtual = '';

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    carregarUsuario();
    iniciarRelogio();
  }

  Future<void> carregarUsuario() async {
    final nome = await StorageService.getNomeUsuario();

    if (!mounted) return;

    setState(() {
      nomeUsuario = nome ?? 'Porteiro';
    });
  }

  void iniciarRelogio() {
    dataHoraAtual = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        dataHoraAtual = DateFormat(
          'dd/MM/yyyy HH:mm:ss',
        ).format(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,

        title: Image.asset('assets/images/logo.png', height: 45),

        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () async {
              await StorageService.clearToken();

              if (!context.mounted) return;

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Clubbar Entrance',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 20),

                const Icon(Icons.security, size: 90, color: Colors.amber),

                const SizedBox(height: 24),

                Text(
                  'Olá, $nomeUsuario',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  dataHoraAtual,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Validação de ingressos e controle de acesso',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const LeitorQrRetiradaIngressoScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text(
                      'Ler QRCode do Ingresso',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
}
