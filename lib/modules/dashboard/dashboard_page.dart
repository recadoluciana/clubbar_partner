import 'package:flutter/material.dart';

import 'package:clubbar_admin/core/services/storage_service.dart';
import 'package:clubbar_admin/modules/auth/login_page.dart';
import 'package:clubbar_admin/modules/categorias/categoria_list_page.dart';
import 'package:clubbar_admin/modules/eventos/evento_list_page.dart';
import 'package:clubbar_admin/modules/lojas/loja_list_page.dart';
import 'package:clubbar_admin/modules/organizacoes/organizacao_form_page.dart';
import 'package:clubbar_admin/modules/produtos/produto_list_page.dart';
import 'package:clubbar_admin/modules/painel_gerencial/painel_gerencial_page.dart';
import 'package:clubbar_admin/modules/usuarios/usuario_list_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _nomeUsuario = 'Usuário';
  String _nomeOrganizacao = 'Organização';

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
  }

  Future<void> _carregarDadosUsuario() async {
    final nomeUsuario = await StorageService.getNomeUsuario();
    final nomeOrganizacao = await StorageService.getNomeOrganizacao();

    if (!mounted) return;

    setState(() {
      _nomeUsuario = nomeUsuario ?? 'Usuário';
      _nomeOrganizacao = nomeOrganizacao ?? 'Organização';
    });
  }

  Future<void> _sair(BuildContext context) async {
    await StorageService.clearToken();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<int?> _getOrganizacaoId() async {
    return await StorageService.getOrganizacaoId();
  }

  Future<void> _abrirModulo(BuildContext context, String chaveModulo) async {
    final organizacaoId = await _getOrganizacaoId();

    if (organizacaoId == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organização não encontrada no login.')),
      );
      return;
    }

    Widget? destino;

    if (chaveModulo == 'organizacao') {
      destino = const OrganizacaoFormPage();
    } else if (chaveModulo == 'lojas') {
      destino = LojaListPage(organizacaoId: organizacaoId);
    } else if (chaveModulo == 'categorias') {
      destino = CategoriaListPage(organizacaoId: organizacaoId);
    } else if (chaveModulo == 'produtos') {
      destino = ProdutoListPage(organizacaoId: organizacaoId);
    } else if (chaveModulo == 'usuarios') {
      destino = UsuarioListPage(organizacaoId: organizacaoId);
    } else if (chaveModulo == 'eventos') {
      destino = EventoListPage(organizacaoId: organizacaoId);
    } else if (chaveModulo == 'painel') {
      destino = const PainelGerencialPage();
    }

    if (destino == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Módulo "$chaveModulo" ainda não implementado.'),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => destino!));
  }

  @override
  Widget build(BuildContext context) {
    final modulos = [
      _DashboardItem(
        chave: 'organizacao',
        titulo: 'Minha organização',
        subtitulo: 'Altere os dados da sua organização',
        icone: Icons.business,
      ),
      _DashboardItem(
        chave: 'lojas',
        titulo: 'Bares e casas noturnas',
        subtitulo:
            'Cadastre e gerencie os bares e casas noturnas da sua organização',
        icone: Icons.store,
      ),
      _DashboardItem(
        chave: 'categorias',
        titulo: 'Categorias de produto',
        subtitulo: 'Cadastre e gerencie categorias de produtos',
        icone: Icons.category,
      ),
      _DashboardItem(
        chave: 'produtos',
        titulo: 'Produtos',
        subtitulo: 'Cadastre e gerencie os produtos',
        icone: Icons.inventory_2,
      ),
      _DashboardItem(
        chave: 'eventos',
        titulo: 'Agenda de Shows',
        subtitulo: 'Cadastre e gerencie sua agenda de shows e eventos',
        icone: Icons.event,
      ),
      _DashboardItem(
        chave: 'usuarios',
        titulo: 'Usuários',
        subtitulo: 'Cadastre e gerencie usuários da organização',
        icone: Icons.people,
      ),
      _DashboardItem(
        chave: 'painel',
        titulo: 'Controle gerencial',
        subtitulo: 'Indicadores e gráficos gerenciais',
        icone: Icons.analytics,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clubbar Admin'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: () => _sair(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: Colors.orange.shade100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.account_circle, size: 42),
                    const SizedBox(height: 10),
                    Text(
                      _nomeUsuario,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_nomeOrganizacao),
                    const SizedBox(height: 4),
                    const Text('Administrador'),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dashboard),
                      title: const Text('Início'),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.business),
                      title: const Text('Minha organização'),
                      onTap: () {
                        Navigator.pop(context);
                        _abrirModulo(context, 'organizacao');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.store),
                      title: const Text('Bares'),
                      onTap: () {
                        Navigator.pop(context);
                        _abrirModulo(context, 'lojas');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.category),
                      title: const Text('Categorias de produto'),
                      onTap: () {
                        Navigator.pop(context);
                        _abrirModulo(context, 'categorias');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.inventory_2),
                      title: const Text('Produtos'),
                      onTap: () {
                        Navigator.pop(context);
                        _abrirModulo(context, 'produtos');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.event),
                      title: const Text('Eventos'),
                      onTap: () {
                        Navigator.pop(context);
                        _abrirModulo(context, 'eventos');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.people),
                      title: const Text('Usuários'),
                      onTap: () {
                        Navigator.pop(context);
                        _abrirModulo(context, 'usuarios');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.analytics),
                      title: const Text('Controle gerencial'),
                      onTap: () {
                        Navigator.pop(context);
                        _abrirModulo(context, 'painel');
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sair'),
                onTap: () => _sair(context),
              ),
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = 2;

          if (constraints.maxWidth >= 1200) {
            crossAxisCount = 4;
          } else if (constraints.maxWidth >= 800) {
            crossAxisCount = 2;
          } else if (constraints.maxWidth < 600) {
            crossAxisCount = 1;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, $_nomeUsuario 👋',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Você está gerenciando: $_nomeOrganizacao',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Primeiros passos',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Revise sua organização, cadastre bares, categorias, produtos, usuários e eventos.',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                GridView.builder(
                  itemCount: modulos.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.45,
                  ),
                  itemBuilder: (context, index) {
                    final item = modulos[index];

                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _abrirModulo(context, item.chave),
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                child: Icon(item.icone, size: 26),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                item.titulo,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Text(
                                  item.subtitulo,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Row(
                                children: [
                                  Text(
                                    'Abrir',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardItem {
  final String chave;
  final String titulo;
  final String subtitulo;
  final IconData icone;

  _DashboardItem({
    required this.chave,
    required this.titulo,
    required this.subtitulo,
    required this.icone,
  });
}
