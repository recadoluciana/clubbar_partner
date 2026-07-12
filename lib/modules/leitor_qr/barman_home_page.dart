import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/storage_service.dart';
import '../auth/login_page.dart';
import 'leitor_qr_retirada_page.dart';

class BarmanHomePage extends StatefulWidget {
  const BarmanHomePage({super.key});

  @override
  State<BarmanHomePage> createState() => _BarmanHomePageState();
}

class _BarmanHomePageState extends State<BarmanHomePage> {
  String nomeUsuario = 'Atendente';
  String dataHoraAtual = '';

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    carregarUsuario();
    iniciarRelogio();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void iniciarRelogio() {
    _atualizarRelogio();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(_atualizarRelogio);
    });
  }

  void _atualizarRelogio() {
    dataHoraAtual = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
  }

  Future<void> carregarUsuario() async {
    final nome = await StorageService.getNomeUsuario();

    if (!mounted) return;

    setState(() {
      nomeUsuario = nome?.trim().isNotEmpty == true
          ? nome!.trim()
          : 'Atendente';
    });
  }

  Future<void> abrirLeitorQr() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LeitorQrRetiradaScreen()),
    );
  }

  Future<void> sair() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Sair do Clubbar Barman',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('Deseja realmente encerrar sua sessão?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sair'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    await StorageService.clearToken();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        title: Image.asset(
          'assets/images/logo.png',
          height: 45,
          errorBuilder: (_, _, _) {
            return const Text(
              'CLUBBAR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sair',
            onPressed: sair,
          ),
        ],
      ),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFD54F),
                          Color(0xFFFFECB3),
                          Color(0xFFF6F6F6),
                        ],
                      ),
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
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.amber.shade200,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.local_bar_rounded,
                            size: 44,
                            color: Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 18),

                        const Text(
                          'Clubbar Barman',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Olá, $nomeUsuario',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          dataHoraAtual,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.blue,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Leitura de produto',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Leia o QR Code exibido na carteira do cliente '
                                'ou na imagem de um presente Clubbar.',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: abrirLeitorQr,
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 25),
                      label: const Text(
                        'Ler QR Code do produto',
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

                  const SizedBox(height: 12),

                  Text(
                    'O produto somente será baixado após a confirmação.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
