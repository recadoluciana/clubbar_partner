import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../auth/login_page.dart';

class SuperAdminDashboardPage extends StatelessWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),

      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text('CLUBBAR • SUPERADMIN'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
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

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              'Painel Interno',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Gerencie parceiros e organizações.',
              style: TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 30),

            Wrap(
              spacing: 20,
              runSpacing: 20,

              children: [
                _card('Leads Parceiros', Icons.handshake),

                _card('Organizações', Icons.business),

                _card('Financeiro', Icons.attach_money),

                _card('Usuários', Icons.people),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(String titulo, IconData icone) {
    return Container(
      width: 260,
      height: 180,

      decoration: BoxDecoration(
        color: const Color(0xFF111111),

        borderRadius: BorderRadius.circular(22),
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(icone, size: 60, color: Colors.amber),

          const SizedBox(height: 18),

          Text(
            titulo,

            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }
}
