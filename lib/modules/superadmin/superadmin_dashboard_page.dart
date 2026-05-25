import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../auth/login_page.dart';
import '../../core/repositories/superadmin_repository.dart';

class SuperAdminDashboardPage extends StatefulWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  State<SuperAdminDashboardPage> createState() =>
      _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage> {
  final _repo = SuperAdminRepository();

  bool carregando = true;

  Map<String, dynamic> dados = {};

  @override
  void initState() {
    super.initState();

    carregar();
  }

  Future<void> carregar() async {
    try {
      final result = await _repo.dashboard();

      if (!mounted) return;

      setState(() {
        dados = result;
      });
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CLUBBAR • SUPERADMIN'),

        centerTitle: true,

        actions: [
          IconButton(
            tooltip: 'Atualizar',

            icon: const Icon(Icons.refresh),

            onPressed: carregar,
          ),

          const SizedBox(width: 8),

          IconButton(
            tooltip: 'Sair',

            icon: const Icon(Icons.logout),

            onPressed: () async {
              final sair = await showDialog<bool>(
                context: context,

                builder: (_) => AlertDialog(
                  title: const Text('Sair'),

                  content: const Text('Deseja encerrar a sessão?'),

                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),

                      child: const Text('Cancelar'),
                    ),

                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),

                      child: const Text('Sair'),
                    ),
                  ],
                ),
              );

              if (sair != true) {
                return;
              }

              await StorageService.clearToken();

              if (!context.mounted) {
                return;
              }

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            },
          ),

          const SizedBox(width: 12),
        ],
      ),

      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),

              child: Wrap(
                spacing: 20,
                runSpacing: 20,

                children: [
                  _card(
                    'Leads Novos',
                    '${dados['leads_novos']}',
                    Icons.handshake,
                  ),

                  _card(
                    'Organizações',
                    '${dados['organizacoes']}',
                    Icons.business,
                  ),

                  _card('Lojas', '${dados['lojas']}', Icons.store),

                  _card(
                    'Vendas Hoje',
                    '${dados['vendas_hoje']}',
                    Icons.shopping_cart,
                  ),

                  _card(
                    'Faturamento Hoje',

                    'R\$ ${((dados['valor_vendas_hoje'] ?? 0).toDouble().toStringAsFixed(2))}',

                    Icons.monetization_on,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _card(String titulo, String valor, IconData icone) {
    return Container(
      width: 280,
      height: 250,

      margin: const EdgeInsets.all(10),

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,

          colors: [Color(0xFF1A1A1A), Color(0xFF080808)],
        ),

        borderRadius: BorderRadius.circular(26),

        border: Border.all(color: const Color(0x33F5C542)),

        boxShadow: [
          BoxShadow(
            color: const Color(0x66F5C542),

            blurRadius: 18,

            spreadRadius: 1,

            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Container(
            width: 64,
            height: 64,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              gradient: const LinearGradient(
                colors: [Color(0xFFF5C542), Color(0xFFFFD84D)],
              ),
            ),

            child: Icon(icone, size: 32, color: Colors.black),
          ),

          const SizedBox(height: 12),

          Text(
            valor,

            style: const TextStyle(
              color: Colors.white,

              fontSize: 34,

              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            titulo,

            textAlign: TextAlign.center,

            style: const TextStyle(color: Colors.white70, fontSize: 20),
          ),
        ],
      ),
    );
  }
}
