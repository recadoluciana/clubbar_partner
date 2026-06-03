import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../../core/services/storage_service.dart';
import 'leitor_qr_retirada_page.dart';
import '../auth/login_page.dart';

class BarmanHomePage extends StatefulWidget {
  const BarmanHomePage({super.key});

  @override
  State<BarmanHomePage> createState() => _BarmanHomePageState();
}

class _BarmanHomePageState extends State<BarmanHomePage> {
  String nomeUsuario = '';
  String dataHoje = '';
  String dataHoraAtual = '';
  Timer? _timer;

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
  void initState() {
    super.initState();

    carregarUsuario();
    iniciarRelogio();
  }

  Future<void> carregarUsuario() async {
    final nome = await StorageService.getNomeUsuario();

    if (!mounted) return;

    setState(() {
      nomeUsuario = nome ?? 'Atendente';
      dataHoje = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    });
  }

  void abrirLeitorQr() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LeitorQrRetiradaScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text('Clubbar Barman'),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await StorageService.clearToken();

              if (!mounted) return;

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
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_bar_rounded,
                  size: 84,
                  color: Colors.black,
                ),
                const SizedBox(height: 24),

                Text(
                  'Olá, $nomeUsuario',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  dataHoraAtual,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Use esta tela para entregar produtos aos clientes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: abrirLeitorQr,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text(
                      'Ler QrCode do Produto',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
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
}
