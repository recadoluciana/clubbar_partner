import 'package:flutter/material.dart';

import '../../core/repositories/superadmin_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';

import '../auth/login_page.dart';
import '../leads/pages/leadparceiro_list_page.dart';
import '../organizacoes/organizacao_form_page.dart';
import '../usuarios/usuario_list_page.dart';

class SuperAdminDashboardPage extends StatefulWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  State<SuperAdminDashboardPage> createState() =>
      _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage> {
  final SuperAdminRepository _repo = SuperAdminRepository();

  bool _carregando = true;

  Map<String, dynamic> _dados = {};

  String _nomeOrganizacao = '';
  String _nomeUsuario = '';
  String _cargo = '';

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  void _abrirLeads() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LeadParceiroListPage()));
  }

  Future<void> _inicializar() async {
    await _carregarDadosSessao();
    await _carregarDashboard();
  }

  int? _organizacaoId;

  Future<void> _carregarDadosSessao() async {
    final nomeOrganizacao = await StorageService.getNomeOrganizacao() ?? '';

    final nomeUsuario = await StorageService.getNomeUsuario() ?? '';

    final cargo = await StorageService.getCargo() ?? '';

    final organizacaoId = await StorageService.getOrganizacaoId();

    if (!mounted) return;

    setState(() {
      _nomeOrganizacao = nomeOrganizacao;
      _nomeUsuario = nomeUsuario;
      _cargo = cargo;
      _organizacaoId = organizacaoId;
    });
  }

  Future<void> _carregarDashboard() async {
    if (mounted) {
      setState(() {
        _carregando = true;
      });
    }

    try {
      final result = await _repo.dashboard();

      if (!mounted) return;

      setState(() {
        _dados = result;
      });
    } catch (e) {
      if (!mounted) return;

      _mostrarMensagem(
        'Não foi possível carregar o painel administrativo.',
        erro: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  void _mostrarMensagem(String mensagem, {bool erro = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            mensagem,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: erro ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Future<void> _atualizar() async {
    await _carregarDadosSessao();
    await _carregarDashboard();

    if (!mounted) return;

    _mostrarMensagem('Painel atualizado com sucesso.');
  }

  Future<void> _sair() async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Encerrar sessão',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text('Deseja realmente sair do Clubbar Parceiro?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context, true);
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sair'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (sair != true) return;

    await StorageService.clearToken();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  void _abrirUsuarios() {
    if (_organizacaoId == null) {
      _mostrarMensagem(
        'Não foi possível identificar a organização do usuário.',
        erro: true,
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UsuarioListPage(organizacaoId: _organizacaoId!),
      ),
    );
  }

  Future<void> _abrirOrganizacao() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const OrganizacaoFormPage()));

    if (!mounted) return;
    await _carregarDadosSessao();
    await _carregarDashboard();
  }

  int _valorInteiro(String chave) {
    final valor = _dados[chave];

    if (valor is num) return valor.toInt();

    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  int _totalParceiros() {
    final total = _valorInteiro('organizacoes');
    return total > 0 ? total - 1 : 0;
  }

  double _valorVendasHoje() {
    final valor = _dados['valor_vendas_hoje'];

    if (valor == null) return 0;

    if (valor is num) {
      return valor.toDouble();
    }

    return double.tryParse(valor.toString().replaceAll(',', '.')) ?? 0;
  }

  String _formatarMoeda(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Widget _cardOrganizacao() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.shade200),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 7, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.business_rounded,
              size: 27,
              color: Colors.black87,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Organização',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  _nomeOrganizacao.isEmpty ? 'Clubbar' : _nomeOrganizacao,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _abrirOrganizacao,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Editar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: BorderSide(color: Colors.amber.shade600),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardIndicador({
    required String titulo,
    required String valor,
    required IconData icone,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 145,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, size: 25, color: Colors.black87),
              ),

              const SizedBox(height: 10),

              Text(
                valor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                titulo,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dashboard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int colunas = 2;

        if (constraints.maxWidth >= 1000) {
          colunas = 4;
        } else if (constraints.maxWidth >= 700) {
          colunas = 3;
        }

        return GridView.count(
          crossAxisCount: colunas,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.35,
          children: [
            _cardIndicador(
              titulo: 'Leads novos',
              valor: '${_dados['leads_novos'] ?? 0}',
              icone: Icons.handshake_rounded,
              onTap: _abrirLeads,
            ),

            _cardIndicador(
              titulo: 'Parceiros',
              valor: '${_totalParceiros()}',
              icone: Icons.business_rounded,
            ),

            _cardIndicador(
              titulo: 'Estabelecimentos',
              valor: '${_dados['lojas'] ?? 0}',
              icone: Icons.storefront_rounded,
            ),

            _cardIndicador(
              titulo: 'Usuários',
              valor: '${_dados['usuarios'] ?? 0}',
              icone: Icons.manage_accounts_rounded,
              onTap: _abrirUsuarios,
            ),

            _cardIndicador(
              titulo: 'Vendas hoje',
              valor: '${_dados['vendas_hoje'] ?? 0}',
              icone: Icons.shopping_cart_rounded,
            ),

            _cardIndicador(
              titulo: 'Faturamento hoje',
              valor: _formatarMoeda(_valorVendasHoje()),
              icone: Icons.monetization_on_rounded,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      appBar: ClubbarAppBar(
        mostrarSair: true,
        onSair: _sair,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _carregando ? null : _atualizar,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            const ClubbarPageHeader(
              titulo: 'Painel Administrativo',
              subtitulo: 'Visão geral e administração do app',
              icone: Icons.dashboard_rounded,
              mostrarDataHora: false,
            ),

            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _atualizar,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _cardOrganizacao(),

                                const SizedBox(height: 18),

                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.insights_rounded,
                                      size: 22,
                                      color: Colors.black87,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Indicadores',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                _dashboard(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
