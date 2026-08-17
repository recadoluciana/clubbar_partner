import 'package:flutter/material.dart';

import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../auth/login_page.dart';
import '../lojas/loja_list_page.dart';
import '../organizacao/organizacao_list_page.dart';
import '../painel_gerencial/painel_gerencial_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _nomeOrganizacao = 'Organização';
  String _cargo = '';
  int? _organizacaoId;
  bool _carregando = true;

  bool get _podeVerGerencial => _cargo == 'SUPERADMIN' || _cargo == 'ADMIN';

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
  }

  Future<void> _carregarDadosUsuario() async {
    try {
      final dados = await Future.wait<dynamic>([
        StorageService.getNomeOrganizacao(),
        StorageService.getCargo(),
        StorageService.getOrganizacaoId(),
      ]);
      if (!mounted) return;
      final nome = (dados[0] as String? ?? '').trim();
      setState(() {
        _nomeOrganizacao = nome.isEmpty ? 'Organização' : nome;
        _cargo = (dados[1] as String? ?? '').trim().toUpperCase();
        _organizacaoId = dados[2] as int?;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _carregando = false);
      AppSnackBar.erro(context, 'Não foi possível carregar a organização.');
    }
  }

  Future<void> _abrirOrganizacao() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const OrganizacaoListPage()),
    );
    if (mounted) await _carregarDadosUsuario();
  }

  Future<void> _abrirGerencial() async {
    if (!_podeVerGerencial) {
      AppSnackBar.aviso(
        context,
        'O painel gerencial é exclusivo para Superadmin e Admin.',
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const PainelGerencialPage()),
    );
  }

  Future<void> _sair() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ClubbarColors.fundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: ClubbarColors.erro),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sair do Clubbar Parceiro',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        content: const Text('Deseja realmente encerrar sua sessão?'),
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, false),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sair'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ClubbarColors.erro,
              foregroundColor: ClubbarColors.branco,
            ),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await StorageService.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Widget _acoesHeader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_podeVerGerencial) ...[
          IconButton(
            onPressed: _abrirGerencial,
            tooltip: 'Painel Gerencial',
            icon: const Icon(Icons.analytics_rounded),
            style: IconButton.styleFrom(
              foregroundColor: ClubbarColors.branco,
              backgroundColor: ClubbarColors.sucesso,
            ),
          ),
          const SizedBox(width: 8),
        ],
        IconButton(
          onPressed: _abrirOrganizacao,
          tooltip: 'Editar organização',
          icon: const Icon(Icons.edit_rounded),
          style: IconButton.styleFrom(
            foregroundColor: ClubbarColors.preto,
            backgroundColor: ClubbarColors.ambar,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: ClubbarAppBar(mostrarSair: true, onSair: _sair),
      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: _nomeOrganizacao,
              subtitulo: 'Gerencie seus estabelecimentos',
              trailing: _carregando ? null : _acoesHeader(),
            ),
            Expanded(
              child: _carregando
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: ClubbarColors.ambar,
                      ),
                    )
                  : _organizacaoId == null || _organizacaoId == 0
                  ? const Center(child: Text('Organização não encontrada.'))
                  : LojaListPage(
                      key: ValueKey(_organizacaoId),
                      organizacaoId: _organizacaoId!,
                      embedded: true,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
