import 'package:flutter/material.dart';

import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';

import 'modules/auth/login_page.dart';
import 'modules/dashboard/dashboard_page.dart';
import 'modules/superadmin/superadmin_dashboard_page.dart';

class ClubbarAdminApp extends StatelessWidget {
  const ClubbarAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Clubbar Admin',
      theme: AppTheme.light,
      home: const SplashDeciderPage(),
    );
  }
}

class SplashDeciderPage extends StatefulWidget {
  const SplashDeciderPage({super.key});

  @override
  State<SplashDeciderPage> createState() => _SplashDeciderPageState();
}

class _SplashDeciderPageState extends State<SplashDeciderPage> {
  bool _carregando = true;
  bool _temToken = false;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _verificarToken();
  }

  Future<void> _verificarToken() async {
    final token = await StorageService.getToken();
    final isSuperAdmin = await StorageService.isSuperAdmin();

    if (!mounted) return;

    setState(() {
      _temToken = token != null && token.isNotEmpty;
      _isSuperAdmin = isSuperAdmin;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_temToken && _isSuperAdmin) {
      return const SuperAdminDashboardPage();
    }

    if (_temToken) {
      return const DashboardPage();
    }

    return const LoginPage();
  }
}
