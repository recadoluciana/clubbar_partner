import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../core/widgets/clubbar_card.dart';
import '../auth/login_page.dart';
import '../lojas/loja_list_page.dart';
import '../organizacao/organizacao_list_page.dart';
import '../painel_gerencial/painel_gerencial_page.dart';
import '../usuarios/usuario_list_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _nomeOrganizacao = 'Organização';
  String _nomeUsuario = 'Usuário';
  String _cargo = '';
  int? _organizacaoId;
  bool _carregando = true;
  DateTime _agora = DateTime.now();
  Timer? _timer;

  bool get _podeEditarOrganizacao => _cargo == 'SUPERADMIN';
  bool get _podeVerGerencial =>
      _cargo == 'SUPERADMIN' || _cargo == 'ADMIN' || _cargo == 'GERENTE';

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _agora = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregarDadosUsuario() async {
    try {
      final dados = await Future.wait<dynamic>([
        StorageService.getNomeOrganizacao(),
        StorageService.getCargo(),
        StorageService.getOrganizacaoId(),
        StorageService.getNomeUsuario(),
      ]);
      if (!mounted) return;
      final nome = (dados[0] as String? ?? '').trim();
      setState(() {
        _nomeOrganizacao = nome.isEmpty ? 'Organização' : nome;
        _cargo = (dados[1] as String? ?? '').trim().toUpperCase();
        _organizacaoId = dados[2] as int?;
        final usuario = (dados[3] as String? ?? '').trim();
        _nomeUsuario = usuario.isEmpty ? 'Usuário' : usuario;
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

  Future<void> _abrirLojas() async {
    final organizacaoId = _organizacaoId;
    if (organizacaoId == null || organizacaoId <= 0) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LojaListPage(organizacaoId: organizacaoId),
      ),
    );
  }

  Future<void> _abrirUsuarios() async {
    final organizacaoId = _organizacaoId;
    if (organizacaoId == null || organizacaoId <= 0) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => UsuarioListPage(organizacaoId: organizacaoId),
      ),
    );
  }

  Future<void> _abrirGerencial() async {
    if (!_podeVerGerencial) {
      AppSnackBar.aviso(
        context,
        'Seu cargo não possui acesso ao painel gerencial.',
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

  String _nomeCargo() {
    if (_cargo == 'SUPERADMIN') return 'Superadministrador';
    if (_cargo == 'ADMIN') return 'Administrador';
    if (_cargo == 'GERENTE') return 'Gerente';
    return _cargo;
  }

  String _subtitulo() {
    final dataHora = DateFormat('dd/MM/yyyy HH:mm:ss', 'pt_BR').format(_agora);
    return '$_nomeUsuario • ${_nomeCargo()} • $dataHora';
  }

  Widget _opcao({
    required String titulo,
    required String subtitulo,
    required IconData icone,
    required VoidCallback? onTap,
  }) {
    final habilitado = onTap != null;
    return ClubbarCard(
      onTap: onTap,
      elevation: 1,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: habilitado
                  ? ClubbarColors.ambarClaro
                  : ClubbarColors.borda,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icone,
              color: habilitado
                  ? ClubbarColors.preto
                  : ClubbarColors.textoSecundario,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: habilitado
                        ? ClubbarColors.textoPrincipal
                        : ClubbarColors.textoSecundario,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: const TextStyle(
                    color: ClubbarColors.textoSecundario,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            habilitado ? Icons.chevron_right_rounded : Icons.lock_rounded,
            color: ClubbarColors.textoSecundario,
          ),
        ],
      ),
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
              subtitulo: _subtitulo(),
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
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _opcao(
                          titulo: 'Editar Organização',
                          subtitulo: _podeEditarOrganizacao
                              ? 'Atualize os dados cadastrais da organização.'
                              : 'Disponível somente para o Superadministrador.',
                          icone: Icons.business_rounded,
                          onTap: _podeEditarOrganizacao
                              ? _abrirOrganizacao
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _opcao(
                          titulo: 'Gerenciar Lojas',
                          subtitulo: _cargo == 'GERENTE'
                              ? 'Consulte e edite os dados da sua loja.'
                              : 'Cadastre e administre as lojas da organização.',
                          icone: Icons.storefront_rounded,
                          onTap: _abrirLojas,
                        ),
                        const SizedBox(height: 14),
                        _opcao(
                          titulo: 'Gerenciar Usuários',
                          subtitulo: _cargo == 'GERENTE'
                              ? 'Administre os usuários vinculados à sua loja.'
                              : 'Liste, inclua, altere e exclua acessos.',
                          icone: Icons.manage_accounts_rounded,
                          onTap: _abrirUsuarios,
                        ),
                        const SizedBox(height: 14),
                        _opcao(
                          titulo: 'Painel Gerencial da Organização',
                          subtitulo:
                              'Acompanhe vendas, lojas, produtos e ingressos.',
                          icone: Icons.analytics_rounded,
                          onTap: _podeVerGerencial ? _abrirGerencial : null,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
