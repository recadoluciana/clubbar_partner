import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/auth_service.dart';
import '../dashboard/dashboard_page.dart';
import '../../core/services/storage_service.dart';
import '../superadmin/superadmin_dashboard_page.dart';
import '../leitor_qr/barman_home_page.dart';
import '../leitor_qr/porteiro_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  bool _carregando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preencha e-mail e senha.')));
      return;
    }

    setState(() {
      _carregando = true;
    });

    try {
      await AuthService.login(email, senha);

      final isSuperAdmin = await StorageService.isSuperAdmin();
      final cargo = await StorageService.getCargo();
      final cargoUpper = (cargo ?? '').trim().toUpperCase();

      if (!mounted) return;

      if (cargoUpper == 'CAIXA') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tela do caixa será implementada.')),
        );
        return;
      }

      Widget? destino;

      if (cargoUpper == 'GARCOM' || cargoUpper == 'BARMAN') {
        destino = const BarmanHomePage();
      } else if (cargoUpper == 'PORTEIRO') {
        destino = const PorteiroHomePage();
      } else if (isSuperAdmin) {
        destino = const SuperAdminDashboardPage();
      } else if (cargoUpper == 'ADMIN' || cargoUpper == 'GERENTE') {
        destino = const DashboardPage();
      }

      if (destino == null) {
        await StorageService.clearToken();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário não possui cargo definido.')),
        );
        return;
      }

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => destino!));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

              if (kIsWeb) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              } else {
                exit(0);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Login - Clubbar Parceiro',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 20),
                const Icon(Icons.lock_outline, size: 90),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _senhaController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _carregando ? null : _fazerLogin,
                    child: _carregando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar'),
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
