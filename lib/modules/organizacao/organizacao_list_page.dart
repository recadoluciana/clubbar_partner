import 'package:flutter/material.dart';

import '../../core/repositories/organizacao_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/organizacao.dart';
import 'organizacao_form_page.dart';
import '../usuarios/usuario_list_page.dart';

class OrganizacaoListPage extends StatefulWidget {
  const OrganizacaoListPage({super.key});

  @override
  State<OrganizacaoListPage> createState() => _OrganizacaoListPageState();
}

class _OrganizacaoListPageState extends State<OrganizacaoListPage> {
  final OrganizacaoRepository _repository = OrganizacaoRepository();

  bool _carregando = true;
  Organizacao? _organizacao;

  @override
  void initState() {
    super.initState();
    _carregarOrganizacao();
  }

  String _formatarCidade(Organizacao organizacao) {
    final codigo = organizacao.cidadeId?.toString() ?? '-';
    final cidade = organizacao.nmcidade?.trim() ?? '';
    final estado = organizacao.sgestado?.trim() ?? '';

    if (cidade.isEmpty) {
      return 'Código $codigo';
    }

    if (estado.isEmpty) {
      return '$codigo • $cidade';
    }

    return '$codigo • $cidade/$estado';
  }

  String _somenteNumeros(String? valor) {
    return (valor ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _valorOuTraco(Object? valor) {
    final texto = valor?.toString().trim() ?? '';

    return texto.isEmpty ? '-' : texto;
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

  String _formatarCep(String? valor) {
    final numeros = _somenteNumeros(valor);

    if (numeros.length != 8) {
      return _valorOuTraco(valor);
    }

    return '${numeros.substring(0, 5)}-'
        '${numeros.substring(5, 8)}';
  }

  String _formatarData(DateTime? data) {
    if (data == null) {
      return '-';
    }

    final local = data.toLocal();

    String doisDigitos(int valor) {
      return valor.toString().padLeft(2, '0');
    }

    return '${doisDigitos(local.day)}/'
        '${doisDigitos(local.month)}/'
        '${local.year} às '
        '${doisDigitos(local.hour)}:'
        '${doisDigitos(local.minute)}';
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
      debugPrint('[ORGANIZAÇÃO] Erro ao carregar: $e');

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

  Future<void> _editarOrganizacao(OrganizacaoSecao secao) async {
    final organizacao = _organizacao;

    if (organizacao == null) {
      AppSnackBar.aviso(context, 'Organização não encontrada.');

      return;
    }

    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            OrganizacaoFormPage(organizacao: organizacao, secao: secao),
      ),
    );

    if (!mounted) return;

    if (resultado == true) {
      await _carregarOrganizacao();

      if (!mounted) return;

      AppSnackBar.sucesso(context, 'Organização atualizada com sucesso.');
    }
  }

  Color _corStatus(String? status) {
    final valor = status?.trim().toUpperCase() ?? '';

    if (valor == 'ATIVA' || valor == 'ATIVO') {
      return ClubbarColors.sucesso;
    }

    if (valor == 'INATIVA' || valor == 'INATIVO') {
      return ClubbarColors.erro;
    }

    return ClubbarColors.textoSecundario;
  }

  Widget _statusOrganizacao(Organizacao organizacao) {
    final status = _valorOuTraco(organizacao.sitorganizacao);

    final cor = _corStatus(organizacao.sitorganizacao);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: cor,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _tituloSecao({required IconData icone, required String titulo}) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: ClubbarColors.ambarClaro,
            shape: BoxShape.circle,
          ),
          child: Icon(icone, size: 21, color: ClubbarColors.preto),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: ClubbarColors.textoPrincipal,
            ),
          ),
        ),
      ],
    );
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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ClubbarColors.fundo,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icone, size: 18, color: ClubbarColors.textoSecundario),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: ClubbarColors.textoSecundario,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  valor,
                  style: const TextStyle(
                    fontSize: 13.5,
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

  Widget _divisor() {
    return const Divider(color: ClubbarColors.divisor, height: 1);
  }

  Widget _cardSecao({
    required IconData icone,
    required String titulo,
    required List<Widget> children,
    VoidCallback? onEditar,
  }) {
    return Material(
      color: ClubbarColors.branco,
      elevation: 1,
      shadowColor: ClubbarColors.sombra,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ClubbarColors.borda),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _tituloSecao(icone: icone, titulo: titulo),
                ),
                if (onEditar != null)
                  IconButton(
                    tooltip: 'Editar $titulo',
                    onPressed: onEditar,
                    icon: const Icon(Icons.edit_rounded),
                    color: ClubbarColors.preto,
                    style: IconButton.styleFrom(
                      backgroundColor: ClubbarColors.ambarClaro,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 13),
            _divisor(),
            const SizedBox(height: 3),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _cardIdentificacao(Organizacao organizacao) {
    return _cardSecao(
      icone: Icons.business_rounded,
      titulo: 'Identificação',
      onEditar: () => _editarOrganizacao(OrganizacaoSecao.empresa),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ClubbarColors.fundo,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.account_balance_outlined,
                  size: 18,
                  color: ClubbarColors.textoSecundario,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Razão social',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: ClubbarColors.textoSecundario,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: SelectableText(
                            _valorOuTraco(organizacao.rzsocialorganizacao),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: ClubbarColors.textoPrincipal,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _statusOrganizacao(organizacao),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _divisor(),
        _linhaInformacao(
          icone: Icons.storefront_outlined,
          titulo: 'Nome fantasia',
          valor: _valorOuTraco(organizacao.nmorganizacao),
        ),
        _divisor(),
        _linhaInformacao(
          icone: Icons.badge_outlined,
          titulo: 'CNPJ',
          valor: _formatarCnpj(organizacao.cnpjorganizacao),
        ),
      ],
    );
  }

  Widget _cardContato(Organizacao organizacao) {
    return _cardSecao(
      icone: Icons.contact_phone_rounded,
      titulo: 'Contato',
      onEditar: () => _editarOrganizacao(OrganizacaoSecao.contato),
      children: [
        _linhaInformacao(
          icone: Icons.email_outlined,
          titulo: 'E-mail',
          valor: _valorOuTraco(organizacao.emailorganizacao),
        ),
        _divisor(),
        _linhaInformacao(
          icone: Icons.phone_outlined,
          titulo: 'Telefone',
          valor: _formatarTelefone(organizacao.telorganizacao),
        ),
      ],
    );
  }

  Widget _cardEndereco(Organizacao organizacao) {
    return _cardSecao(
      icone: Icons.location_on_rounded,
      titulo: 'Endereço',
      onEditar: () => _editarOrganizacao(OrganizacaoSecao.endereco),
      children: [
        _linhaInformacao(
          icone: Icons.markunread_mailbox_outlined,
          titulo: 'CEP',
          valor: _formatarCep(organizacao.ceporganizacao),
        ),
        _divisor(),
        _linhaInformacao(
          icone: Icons.route_outlined,
          titulo: 'Endereço',
          valor: _valorOuTraco(organizacao.endorganizacao),
        ),
        _divisor(),
        _linhaInformacao(
          icone: Icons.pin_outlined,
          titulo: 'Número',
          valor: _valorOuTraco(organizacao.nrendorganizacao),
        ),
        _divisor(),
        _linhaInformacao(
          icone: Icons.add_home_work_outlined,
          titulo: 'Complemento',
          valor: _valorOuTraco(organizacao.complorganizacao),
        ),
        _divisor(),
        _linhaInformacao(
          icone: Icons.holiday_village_outlined,
          titulo: 'Bairro',
          valor: _valorOuTraco(organizacao.nmbairro),
        ),
        _divisor(),
        _linhaInformacao(
          icone: Icons.location_city_outlined,
          titulo: 'Cidade',
          valor: _formatarCidade(organizacao),
        ),
      ],
    );
  }

  Widget _cardSistema(Organizacao organizacao) {
    return _cardSecao(
      icone: Icons.info_outline_rounded,
      titulo: 'Informações do sistema',
      children: [
        _linhaInformacao(
          icone: Icons.tag_rounded,
          titulo: 'ID da organização',
          valor: organizacao.organizacaoId.toString(),
        ),
        _divisor(),
        _linhaInformacao(
          icone: Icons.person_add_alt_rounded,
          titulo: 'Lead de origem',
          valor: _valorOuTraco(organizacao.leadparceiroId),
        ),
        _divisor(),
        _linhaInformacao(
          icone: Icons.calendar_today_outlined,
          titulo: 'Data de criação',
          valor: _formatarData(organizacao.dtcriacao),
        ),
        _divisor(),
        _linhaInformacao(
          icone: Icons.update_rounded,
          titulo: 'Última atualização',
          valor: _formatarData(organizacao.dtultatu),
        ),
      ],
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
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 28),
          children: [
            _cardIdentificacao(organizacao),
            const SizedBox(height: 14),
            _cardContato(organizacao),
            const SizedBox(height: 14),
            _cardEndereco(organizacao),
            const SizedBox(height: 14),
            _cardSistema(organizacao),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: ClubbarAppBar(
        mostrarVoltar: true,
        actions: [
          IconButton(
            tooltip: 'Gerenciar usuários',
            icon: const Icon(Icons.people_alt_rounded),
            onPressed: _organizacao == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UsuarioListPage(
                        organizacaoId: _organizacao!.organizacaoId,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: _carregando
                  ? 'Carregando...'
                  : (_organizacao?.nmorganizacao.trim().isNotEmpty == true
                        ? _organizacao!.nmorganizacao.trim()
                        : 'Organização não identificada'),
              subtitulo: 'Gerencie os dados da sua organização',
            ),
            _conteudo(),
          ],
        ),
      ),
    );
  }
}
