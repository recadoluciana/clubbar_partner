import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'modules/auth/login_page.dart';
import 'modules/dashboard/dashboard_page.dart';
import 'modules/leitor_qr/barman_home_page.dart';
import 'modules/leitor_qr/ticketman_home_page.dart';
import 'modules/caixa/caixa_page.dart';

class ClubbarPartnerApp extends StatelessWidget {
  const ClubbarPartnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Clubbar Partner',
      theme: AppTheme.light,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
  String? _cargo;

  @override
  void initState() {
    super.initState();
    _verificarToken();
  }

  Future<void> _verificarToken() async {
    final token = await StorageService.getToken();
    final cargo = await StorageService.getCargo();

    if (!mounted) return;

    setState(() {
      _temToken = token != null && token.isNotEmpty;
      _cargo = cargo;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_temToken) {
      final cargoUpper = (_cargo ?? '').trim().toUpperCase();

      if (cargoUpper == 'TICKETMAN') {
        return const TicketmanHomePage();
      }

      if (cargoUpper == 'BARMAN' || cargoUpper == 'WAITER') {
        return const BarmanHomePage();
      }

      if (cargoUpper == 'CASHIER') return const CaixaPage();

      if (cargoUpper == 'SUPERADMIN' ||
          cargoUpper == 'ADMIN' ||
          cargoUpper == 'MANAGER') {
        return const DashboardPage();
      }
      return const LoginPage();
    }

    return const LoginPage();
  }
}
