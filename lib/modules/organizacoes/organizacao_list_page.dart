import 'package:flutter/material.dart';

import '../../core/repositories/organizacao_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_footer.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/organizacao.dart';
import 'organizacao_form_page.dart';

class OrganizacaoListPage extends StatefulWidget {
  const OrganizacaoListPage({super.key});

  @override
  State<OrganizacaoListPage> createState() => _OrganizacaoListPageState();
}

class _OrganizacaoListPageState extends State<OrganizacaoListPage> {
  final OrganizacaoRepository _repository = OrganizacaoRepository();

  bool _carregando = true;
  Organizacao? _organizacao;

  String _somenteNumeros(String? valor) {
    return (valor ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _formatarCnpj(String? valor) {
    final numeros = _somenteNumeros(valor);

    if (numeros.length != 14) {
      return _valorOuTraco(valor);
    }

    return '${numeros.substring(0, 2)}.'
        '${numeros.substring(2, 5)}.'
        '${numeros.substring(5, 8)}/'
        '${numeros.substring(8, 12)}-'
        '${numeros.substring(12, 14)}';
  }

  String _formatarTelefone(String? valor) {
    final numeros = _somenteNumeros(valor);

    if (numeros.length == 11) {
      return '(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 7)}-'
          '${numeros.substring(7, 11)}';
    }

    if (numeros.length == 10) {
      return '(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 6)}-'
          '${numeros.substring(6, 10)}';
    }

    return _valorOuTraco(valor);
  }

  @override
  void initState() {
    super.initState();
    _carregarOrganizacao();
  }

  Future<void> _carregarOrganizacao() async {
    if (mounted) {
      setState(() {
        _carregando = true;
      });
    }

    try {
      final usuarioId = await StorageService.getUsuarioId();

      if (usuarioId == null || usuarioId == 0) {
        throw Exception('Usuário não encontrado no login.');
      }

      final organizacao = await _repository.buscarPorUsuario(usuarioId);

      if (!mounted) return;

      setState(() {
        _organizacao = organizacao;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _organizacao = null;
      });

      AppSnackBar.erro(context, 'Não foi possível carregar a organização.');
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  Future<void> _editarOrganizacao() async {
    final organizacao = _organizacao;

    if (organizacao == null) {
      AppSnackBar.aviso(context, 'Organização não encontrada.');

      return;
    }

    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OrganizacaoFormPage(organizacao: organizacao),
      ),
    );

    if (!mounted) return;

    if (resultado == true) {
      await _carregarOrganizacao();

      if (!mounted) return;

      AppSnackBar.sucesso(context, 'Organização atualizada com sucesso.');
    }
  }

  String _valorOuTraco(String? valor) {
    final texto = valor?.trim() ?? '';

    return texto.isEmpty ? '-' : texto;
  }

  Color _corStatus(String? status) {
    final valor = status?.trim().toUpperCase();

    if (valor == 'ATIVO') {
      return Colors.green.shade700;
    }

    if (valor == 'INATIVO') {
      return ClubbarColors.erro;
    }

    return ClubbarColors.textoSecundario;
  }

  Widget _linhaInformacao({
    required IconData icone,
    required String titulo,
    required String valor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: ClubbarColors.ambarClaro,
              shape: BoxShape.circle,
            ),
            child: Icon(icone, size: 20, color: ClubbarColors.preto),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ClubbarColors.textoSecundario,
                  ),
                ),

                const SizedBox(height: 2),

                SelectableText(
                  valor,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: ClubbarColors.textoPrincipal,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusOrganizacao(Organizacao organizacao) {
    final status = _valorOuTraco(organizacao.sitorganizacao);

    final cor = _corStatus(organizacao.sitorganizacao);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Text(
        status,
        style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _cardOrganizacao(Organizacao organizacao) {
    return Material(
      color: ClubbarColors.branco,
      elevation: 2,
      shadowColor: ClubbarColors.sombra,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ClubbarColors.borda),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: ClubbarColors.ambarClaro,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.business_rounded,
                    size: 27,
                    color: ClubbarColors.preto,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        organizacao.nmorganizacao,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: ClubbarColors.textoPrincipal,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        'Código ${organizacao.organizacaoId}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: ClubbarColors.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),

                _statusOrganizacao(organizacao),
              ],
            ),

            const SizedBox(height: 14),

            const Divider(color: ClubbarColors.divisor, height: 1),

            const SizedBox(height: 5),

            _linhaInformacao(
              icone: Icons.badge_outlined,
              titulo: 'CNPJ',
              valor: _formatarCnpj(organizacao.cnpjorganizacao),
            ),

            const Divider(color: ClubbarColors.divisor, height: 1),

            _linhaInformacao(
              icone: Icons.email_outlined,
              titulo: 'E-mail',
              valor: _valorOuTraco(organizacao.emailorganizacao),
            ),

            const Divider(color: ClubbarColors.divisor, height: 1),

            _linhaInformacao(
              icone: Icons.phone_outlined,
              titulo: 'Telefone',
              valor: _formatarTelefone(organizacao.telorganizacao),
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _editarOrganizacao,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Alterar organização'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ClubbarColors.ambar,
                  foregroundColor: ClubbarColors.preto,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _carregando ? null : _carregarOrganizacao,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Atualizar dados'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ClubbarColors.preto,
                  side: const BorderSide(color: ClubbarColors.borda),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _estadoVazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: ClubbarColors.branco,
          elevation: 1,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ClubbarColors.borda),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.business_center_outlined,
                  size: 52,
                  color: ClubbarColors.textoSecundario,
                ),

                const SizedBox(height: 12),

                const Text(
                  'Organização não encontrada',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: ClubbarColors.textoPrincipal,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Não foi possível carregar os dados da organização vinculada ao usuário.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: ClubbarColors.textoSecundario,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 16),

                ElevatedButton.icon(
                  onPressed: _carregarOrganizacao,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar novamente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ClubbarColors.ambar,
                    foregroundColor: ClubbarColors.preto,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

    final organizacao = _organizacao;

    if (organizacao == null) {
      return Expanded(child: _estadoVazio());
    }

    return Expanded(
      child: RefreshIndicator(
        color: ClubbarColors.ambar,
        onRefresh: _carregarOrganizacao,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          children: [_cardOrganizacao(organizacao)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,

      appBar: const ClubbarAppBar(mostrarVoltar: true),

      body: SafeArea(
        child: Column(
          children: [
            const ClubbarPageHeader(
              titulo: 'Organização',
              subtitulo: 'Dados cadastrais da empresa',
              icone: Icons.business_rounded,
            ),

            _conteudo(),

            const ClubbarFooter(),
          ],
        ),
      ),
    );
  }
}
