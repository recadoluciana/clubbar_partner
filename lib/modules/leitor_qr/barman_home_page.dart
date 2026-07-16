import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/config/api_config.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../auth/login_page.dart';
import 'leitor_qr_retirada_page.dart';

class BarmanHomePage extends StatefulWidget {
  const BarmanHomePage({super.key});

  @override
  State<BarmanHomePage> createState() => _BarmanHomePageState();
}

class _BarmanHomePageState extends State<BarmanHomePage> {
  String nomeUsuario = 'Barman';
  String nomeLoja = '';
  String logoLoja = '';
  String dataHoraAtual = '';

  bool carregando = true;
  String? erro;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    carregarDados();
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

  String _montarUrlImagem(String caminho) {
    final valor = caminho.trim();

    if (valor.isEmpty) {
      return '';
    }

    if (valor.startsWith('http://') || valor.startsWith('https://')) {
      return valor;
    }

    return valor.startsWith('/')
        ? '${ApiConfig.baseUrl}$valor'
        : '${ApiConfig.baseUrl}/$valor';
  }

  Future<void> carregarDados() async {
    if (mounted) {
      setState(() {
        carregando = true;
        erro = null;
      });
    }

    try {
      final nome = await StorageService.getNomeUsuario();
      final usuarioId = await StorageService.getUsuarioId();

      if (usuarioId == null || usuarioId == 0) {
        throw Exception('Usuário não identificado. Faça login novamente.');
      }

      final dadosLoja = await ApiService.buscarLojaDoUsuario(
        usuarioId: usuarioId,
      );

      final nomeLojaRecebido = (dadosLoja['nmloja'] ?? '').toString().trim();

      final caminhoLogo = (dadosLoja['urllogoloja'] ?? '').toString().trim();

      if (!mounted) return;

      setState(() {
        nomeUsuario = nome?.trim().isNotEmpty == true ? nome!.trim() : 'Barman';

        nomeLoja = nomeLojaRecebido.isNotEmpty
            ? nomeLojaRecebido
            : 'Loja não identificada';

        logoLoja = _montarUrlImagem(caminhoLogo);

        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        erro = e.toString().replaceFirst('Exception: ', '').trim();

        carregando = false;
      });
    }
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

  Widget _logoDaLoja() {
    Widget placeholder() {
      return const Icon(
        Icons.storefront_rounded,
        size: 48,
        color: Colors.black87,
      );
    }

    if (logoLoja.isEmpty) {
      return placeholder();
    }

    return Image.network(
      logoLoja,
      width: 94,
      height: 94,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        return placeholder();
      },
    );
  }

  Widget _cardLoja() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD54F), Color(0xFFFFECB3), Color(0xFFF6F6F6)],
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
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber.shade300, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(child: _logoDaLoja()),
          ),

          const SizedBox(height: 16),

          Text(
            nomeLoja,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Atendente: $nomeUsuario',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            dataHoraAtual,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardInformacao() {
    return Container(
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
            child: const Icon(Icons.info_outline_rounded, color: Colors.blue),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Leitura de produto',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
    );
  }

  Widget _conteudo() {
    if (carregando) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    if (erro != null) {
      return Expanded(
        child: RefreshIndicator(
          onRefresh: carregarDados,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 70),

              Icon(
                Icons.cloud_off_rounded,
                size: 68,
                color: Colors.grey.shade400,
              ),

              const SizedBox(height: 16),

              const Text(
                'Não foi possível carregar a loja',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),

              const SizedBox(height: 8),

              Text(
                erro!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: carregarDados,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: carregarDados,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  children: [
                    _cardLoja(),

                    const SizedBox(height: 22),

                    _cardInformacao(),

                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton.icon(
                        onPressed: abrirLeitorQr,
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 25,
                        ),
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitulo = carregando
        ? 'Carregando dados da loja...'
        : nomeLoja.isEmpty
        ? 'Atendente: $nomeUsuario'
        : '$nomeLoja • Atendente: $nomeUsuario';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      appBar: ClubbarAppBar(mostrarSair: true, onSair: sair),

      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: 'Clubbar Barman',
              subtitulo: subtitulo,
              icone: Icons.local_bar_rounded,
              imagemUrl: logoLoja,
            ),

            _conteudo(),
          ],
        ),
      ),
    );
  }
}
