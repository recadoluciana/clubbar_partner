import 'package:flutter/material.dart';
import 'package:clubbar_partner/core/services/storage_service.dart';
import 'package:clubbar_partner/core/theme/clubbar_colors.dart';
import 'package:clubbar_partner/core/widgets/app_snackbar.dart';
import 'package:clubbar_partner/core/widgets/dashboard_menu_card.dart';

import 'package:clubbar_partner/modules/auth/login_page.dart';
import 'package:clubbar_partner/modules/categorias/categoria_list_page.dart';
import 'package:clubbar_partner/modules/eventos/evento_list_page.dart';
import 'package:clubbar_partner/modules/lojas/loja_list_page.dart';
import 'package:clubbar_partner/modules/painel_gerencial/painel_gerencial_page.dart';
import 'package:clubbar_partner/modules/produtos/produto_list_page.dart';
import 'package:clubbar_partner/modules/usuarios/usuario_list_page.dart';
import 'package:clubbar_partner/modules/organizacao/organizacao_list_page.dart';

import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../core/widgets/clubbar_footer.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _nomeOrganizacao = 'Organização';

  bool _carregando = true;

  @override
  void initState() {
    super.initState();

    _carregarDadosUsuario();

    if (!mounted) return;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _carregarDadosUsuario() async {
    try {
      final nomeOrganizacao = await StorageService.getNomeOrganizacao();

      if (!mounted) return;

      setState(() {
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

  Future<int?> _getOrganizacaoId() {
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
        destino = const OrganizacaoListPage();
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
                  'Sair do Clubbar Parceiro',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: const Text('Deseja realmente encerrar sua sessão?'),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancelar'),
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
      (_) => false,
    );
  }

  Widget _gradeModulos() {
    final modulos = <_DashboardItem>[
      const _DashboardItem(
        chave: 'organizacao',
        titulo: 'Organização',
        subtitulo: 'Dados da empresa',
        icone: Icons.business_rounded,
      ),
      const _DashboardItem(
        chave: 'lojas',
        titulo: 'Lojas',
        subtitulo: 'Estabelecimentos',
        icone: Icons.storefront_rounded,
      ),
      const _DashboardItem(
        chave: 'categorias',
        titulo: 'Categorias',
        subtitulo: 'Organização do menu',
        icone: Icons.category_rounded,
      ),
      const _DashboardItem(
        chave: 'produtos',
        titulo: 'Produtos',
        subtitulo: 'Cardápio',
        icone: Icons.inventory_2_rounded,
      ),
      const _DashboardItem(
        chave: 'eventos',
        titulo: 'Eventos',
        subtitulo: 'Shows e ingressos',
        icone: Icons.event_rounded,
      ),
      const _DashboardItem(
        chave: 'usuarios',
        titulo: 'Usuários',
        subtitulo: 'Acessos',
        icone: Icons.people_alt_rounded,
      ),
      const _DashboardItem(
        chave: 'painel',
        titulo: 'Gerencial',
        subtitulo: 'Indicadores',
        icone: Icons.analytics_rounded,
      ),
    ];

    return GridView.builder(
      padding: EdgeInsets.zero,
      itemCount: modulos.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.75,
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
        color: ClubbarColors.ambar,
        onRefresh: _carregarDadosUsuario,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ClubbarColors.branco,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ClubbarColors.borda),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: ClubbarColors.ambarClaro,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      color: ClubbarColors.preto,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Organização atual',
                          style: TextStyle(
                            fontSize: 11,
                            color: ClubbarColors.textoSecundario,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _nomeOrganizacao,
                          style: const TextStyle(
                            fontSize: 16,
                            color: ClubbarColors.textoPrincipal,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _gradeModulos(),
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
              subtitulo: 'Escolha uma opção para continuar',
            ),

            _conteudo(),

            const ClubbarFooter(),
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
