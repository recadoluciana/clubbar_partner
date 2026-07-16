import 'package:flutter/material.dart';

import 'package:clubbar_admin/core/services/storage_service.dart';
import 'package:clubbar_admin/core/theme/clubbar_colors.dart';
import 'package:clubbar_admin/core/widgets/app_snackbar.dart';
import 'package:clubbar_admin/core/widgets/clubbar_card.dart';
import 'package:clubbar_admin/core/widgets/dashboard_menu_card.dart';

import 'package:clubbar_admin/modules/auth/login_page.dart';
import 'package:clubbar_admin/modules/categorias/categoria_list_page.dart';
import 'package:clubbar_admin/modules/eventos/evento_list_page.dart';
import 'package:clubbar_admin/modules/lojas/loja_list_page.dart';
import 'package:clubbar_admin/modules/organizacoes/organizacao_form_page.dart';
import 'package:clubbar_admin/modules/painel_gerencial/painel_gerencial_page.dart';
import 'package:clubbar_admin/modules/produtos/produto_list_page.dart';
import 'package:clubbar_admin/modules/usuarios/usuario_list_page.dart';

import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _nomeUsuario = 'Usuário';
  String _nomeOrganizacao = 'Organização';

  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
  }

  Future<void> _carregarDadosUsuario() async {
    try {
      final nomeUsuario = await StorageService.getNomeUsuario();
      final nomeOrganizacao = await StorageService.getNomeOrganizacao();

      if (!mounted) return;

      setState(() {
        _nomeUsuario = nomeUsuario?.trim().isNotEmpty == true
            ? nomeUsuario!.trim()
            : 'Usuário';

        _nomeOrganizacao = nomeOrganizacao?.trim().isNotEmpty == true
            ? nomeOrganizacao!.trim()
            : 'Organização';

        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _carregando = false;
      });

      AppSnackBar.erro(
        context,
        'Não foi possível carregar os dados do usuário.',
      );
    }
  }

  Future<int?> _getOrganizacaoId() async {
    return StorageService.getOrganizacaoId();
  }

  Future<void> _abrirModulo(BuildContext context, String chaveModulo) async {
    final organizacaoId = await _getOrganizacaoId();

    if (organizacaoId == null || organizacaoId == 0) {
      if (!context.mounted) return;

      AppSnackBar.erro(context, 'Organização não encontrada no login.');

      return;
    }

    Widget? destino;

    switch (chaveModulo) {
      case 'organizacao':
        destino = const OrganizacaoFormPage();
        break;

      case 'lojas':
        destino = LojaListPage(organizacaoId: organizacaoId);
        break;

      case 'categorias':
        destino = CategoriaListPage(organizacaoId: organizacaoId);
        break;

      case 'produtos':
        destino = ProdutoListPage(organizacaoId: organizacaoId);
        break;

      case 'eventos':
        destino = EventoListPage(organizacaoId: organizacaoId);
        break;

      case 'usuarios':
        destino = UsuarioListPage(organizacaoId: organizacaoId);
        break;

      case 'painel':
        destino = const PainelGerencialPage();
        break;
    }

    if (destino == null) {
      if (!context.mounted) return;

      AppSnackBar.aviso(context, 'Este módulo ainda não está disponível.');

      return;
    }

    if (!context.mounted) return;

    await Navigator.push(context, MaterialPageRoute(builder: (_) => destino!));
  }

  Future<void> _sair() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: ClubbarColors.fundo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: ClubbarColors.erro),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sair do Clubbar Admin',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: const Text(
            'Deseja realmente encerrar sua sessão?',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancelar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ClubbarColors.textoPrincipal,
                side: const BorderSide(color: ClubbarColors.borda),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sair'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ClubbarColors.erro,
                foregroundColor: ClubbarColors.branco,
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

  Widget _cardUsuario() {
    return ClubbarCard(
      elevation: 1,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: ClubbarColors.ambarClaro,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              size: 31,
              color: ClubbarColors.preto,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, $_nomeUsuario',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: ClubbarColors.textoPrincipal,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Administrador',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ClubbarColors.textoSecundario,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  _nomeOrganizacao,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ClubbarColors.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradeModulos() {
    final modulos = <_DashboardItem>[
      _DashboardItem(
        chave: 'organizacao',
        titulo: 'Organização',
        subtitulo: 'Dados da empresa',
        icone: Icons.business_rounded,
      ),
      _DashboardItem(
        chave: 'lojas',
        titulo: 'Lojas',
        subtitulo: 'Bares e casas',
        icone: Icons.storefront_rounded,
      ),
      _DashboardItem(
        chave: 'categorias',
        titulo: 'Categorias',
        subtitulo: 'Categorias dos produtos',
        icone: Icons.category_rounded,
      ),
      _DashboardItem(
        chave: 'produtos',
        titulo: 'Produtos',
        subtitulo: 'Cadastro de produtos',
        icone: Icons.inventory_2_rounded,
      ),
      _DashboardItem(
        chave: 'eventos',
        titulo: 'Eventos',
        subtitulo: 'Agenda de shows',
        icone: Icons.event_rounded,
      ),
      _DashboardItem(
        chave: 'usuarios',
        titulo: 'Usuários',
        subtitulo: 'Acessos da equipe',
        icone: Icons.people_alt_rounded,
      ),
      _DashboardItem(
        chave: 'painel',
        titulo: 'Gerencial',
        subtitulo: 'Indicadores e gráficos',
        icone: Icons.analytics_rounded,
      ),
    ];

    return GridView.builder(
      itemCount: modulos.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.96,
      ),
      itemBuilder: (context, index) {
        final modulo = modulos[index];

        return DashboardMenuCard(
          titulo: modulo.titulo,
          subtitulo: modulo.subtitulo,
          icone: modulo.icone,
          onTap: () {
            _abrirModulo(context, modulo.chave);
          },
        );
      },
    );
  }

  Widget _conteudo() {
    if (_carregando) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(color: ClubbarColors.ambar),
        ),
      );
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: _carregarDadosUsuario,
        color: ClubbarColors.ambar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            _cardUsuario(),

            const SizedBox(height: 22),

            const Text(
              'Gerenciamento',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: ClubbarColors.textoPrincipal,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Escolha uma opção para continuar.',
              style: TextStyle(
                fontSize: 13,
                color: ClubbarColors.textoSecundario,
              ),
            ),

            const SizedBox(height: 16),

            _gradeModulos(),

            const SizedBox(height: 26),

            const Text(
              'Clubbar Admin',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ClubbarColors.textoDesabilitado,
              ),
            ),
          ],
        ),
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
              titulo: 'Painel Administrativo',
              subtitulo: _nomeOrganizacao,
              icone: Icons.dashboard_rounded,
            ),

            _conteudo(),
          ],
        ),
      ),
    );
  }
}

class _DashboardItem {
  final String chave;
  final String titulo;
  final String subtitulo;
  final IconData icone;

  const _DashboardItem({
    required this.chave,
    required this.titulo,
    required this.subtitulo,
    required this.icone,
  });
}
