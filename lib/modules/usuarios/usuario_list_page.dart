import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/repositories/loja_repository.dart';
import '../../core/repositories/usuario_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';
import '../../models/usuario.dart';
import 'usuario_form_page.dart';

class UsuarioListPage extends StatefulWidget {
  final int organizacaoId;

  const UsuarioListPage({super.key, required this.organizacaoId});

  @override
  State<UsuarioListPage> createState() => _UsuarioListPageState();
}

class _UsuarioListPageState extends State<UsuarioListPage> {
  final UsuarioRepository _repository = UsuarioRepository();

  final LojaRepository _lojaRepository = LojaRepository();

  final TextEditingController _buscaController = TextEditingController();

  bool _carregando = true;
  bool _excluindo = false;

  String? _erro;

  List<Usuario> _usuarios = [];
  List<Usuario> _usuariosFiltrados = [];
  List<Loja> _lojas = [];

  @override
  void initState() {
    super.initState();

    _carregarTudo();
  }

  @override
  void dispose() {
    _buscaController.dispose();

    super.dispose();
  }

  String _extrairMensagemErro(Object erro) {
    final texto = erro.toString();

    try {
      final inicio = texto.indexOf('{');
      final fim = texto.lastIndexOf('}');

      if (inicio != -1 && fim != -1 && fim > inicio) {
        final jsonTexto = texto.substring(inicio, fim + 1);

        final decoded = jsonDecode(jsonTexto);

        if (decoded is Map && decoded['detail'] != null) {
          return decoded['detail'].toString();
        }
      }
    } catch (_) {}

    final mensagem = texto
        .replaceFirst('Exception: ', '')
        .replaceFirst('Exception:', '')
        .trim();

    return mensagem.isEmpty ? 'Ocorreu um erro inesperado.' : mensagem;
  }

  Future<void> _carregarTudo() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final usuarios = await _repository.listar(widget.organizacaoId);

      final lojas = await _lojaRepository.listar(widget.organizacaoId);

      if (!mounted) return;

      setState(() {
        _usuarios = usuarios;
        _lojas = lojas;

        _usuariosFiltrados = _aplicarFiltro(usuarios, _buscaController.text);

        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      final mensagem = _extrairMensagemErro(e);

      setState(() {
        _carregando = false;
        _erro = mensagem;
      });

      AppSnackBar.erro(context, mensagem);
    }
  }

  String _nomeCargo(String cargo) {
    switch (cargo.trim().toUpperCase()) {
      case 'SUPERADMIN':
        return 'Superadministrador';

      case 'ADMIN':
        return 'Administrador';

      case 'GERENTE':
        return 'Gerente';

      case 'CAIXA':
        return 'Caixa';

      case 'BARMAN':
        return 'Barman';

      case 'GARCOM':
        return 'Garçom';

      case 'PORTEIRO':
        return 'Porteiro';

      default:
        return cargo;
    }
  }

  List<Usuario> _aplicarFiltro(List<Usuario> usuarios, String texto) {
    final busca = texto.trim().toLowerCase();

    if (busca.isEmpty) {
      return List<Usuario>.from(usuarios);
    }

    return usuarios.where((usuario) {
      return usuario.usuarioId.toString().contains(busca) ||
          usuario.nmusuario.toLowerCase().contains(busca) ||
          usuario.emailuser.toLowerCase().contains(busca) ||
          usuario.dscargo.toLowerCase().contains(busca) ||
          _nomeCargo(usuario.dscargo).toLowerCase().contains(busca) ||
          (usuario.situsuario ?? '').toLowerCase().contains(busca) ||
          _nomeLoja(usuario.lojaId).toLowerCase().contains(busca);
    }).toList();
  }

  void _filtrar(String texto) {
    setState(() {
      _usuariosFiltrados = _aplicarFiltro(_usuarios, texto);
    });
  }

  void _limparBusca() {
    _buscaController.clear();

    _filtrar('');

    FocusScope.of(context).unfocus();
  }

  String _nomeLoja(int? lojaId) {
    if (lojaId == null) {
      return 'Sem loja vinculada';
    }

    for (final loja in _lojas) {
      if (loja.lojaId == lojaId) {
        return loja.nmloja;
      }
    }

    return 'Loja não encontrada';
  }

  Future<void> _abrirNovoUsuario() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UsuarioFormPage(organizacaoId: widget.organizacaoId),
      ),
    );

    if (resultado == true) {
      await _carregarTudo();
    }
  }

  Future<void> _abrirEdicao(Usuario usuario) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UsuarioFormPage(
          organizacaoId: widget.organizacaoId,
          usuario: usuario,
        ),
      ),
    );

    if (resultado == true) {
      await _carregarTudo();
    }
  }

  Future<void> _excluirUsuario(Usuario usuario) async {
    if (_excluindo) return;

    if (usuario.usuarioId == 1) {
      AppSnackBar.erro(
        context,
        'O usuário principal do sistema não pode ser excluído.',
      );

      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: ClubbarColors.fundo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: ClubbarColors.erro),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Excluir usuário',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: Text(
            'Deseja realmente excluir o usuário '
            '"${usuario.nmusuario}"?',
          ),
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
              icon: const Icon(Icons.delete_rounded),
              label: const Text('Excluir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ClubbarColors.erro,
                foregroundColor: ClubbarColors.branco,
              ),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    setState(() {
      _excluindo = true;
    });

    try {
      await _repository.excluir(
        organizacaoId: widget.organizacaoId,
        usuarioId: usuario.usuarioId,
      );

      if (!mounted) return;

      AppSnackBar.sucesso(context, 'Usuário excluído com sucesso.');

      await _carregarTudo();
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, _extrairMensagemErro(e));
    } finally {
      if (mounted) {
        setState(() {
          _excluindo = false;
        });
      }
    }
  }

  Widget _campoBusca() {
    return TextField(
      controller: _buscaController,
      onChanged: _filtrar,
      decoration: InputDecoration(
        hintText: 'Buscar por nome, e-mail, cargo ou loja',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _buscaController.text.isNotEmpty
            ? IconButton(
                onPressed: _limparBusca,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        filled: true,
        fillColor: ClubbarColors.branco,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ClubbarColors.borda),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ClubbarColors.borda),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ClubbarColors.ambar, width: 2),
        ),
      ),
    );
  }

  Widget _badgeCargo(Usuario usuario) {
    final principal = usuario.usuarioId == 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: principal ? ClubbarColors.ambarClaro : ClubbarColors.infoClaro,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (principal) ...[
            const Icon(
              Icons.lock_rounded,
              size: 13,
              color: ClubbarColors.preto,
            ),
            const SizedBox(width: 4),
          ],

          Flexible(
            child: Text(
              _nomeCargo(usuario.dscargo),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: principal ? ClubbarColors.preto : ClubbarColors.info,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardUsuario(Usuario usuario) {
    final status = (usuario.situsuario ?? 'ATIVO').toUpperCase();

    final ativo = status == 'ATIVO' || status == 'ATIVA';

    final principal = usuario.usuarioId == 1;

    return ClubbarCard(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      onTap: () => _abrirEdicao(usuario),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: principal
                      ? ClubbarColors.ambar
                      : ClubbarColors.ambarClaro,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: principal
                    ? const Icon(Icons.admin_panel_settings_rounded, size: 29)
                    : Text(
                        usuario.nmusuario.trim().isEmpty
                            ? '?'
                            : usuario.nmusuario.trim()[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            usuario.nmusuario,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: ativo
                                ? ClubbarColors.sucessoClaro
                                : ClubbarColors.erroClaro,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            ativo ? 'Ativo' : 'Inativo',
                            style: TextStyle(
                              color: ativo
                                  ? ClubbarColors.sucesso
                                  : ClubbarColors.erro,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 7),

                    Text(
                      usuario.emailuser,
                      style: const TextStyle(
                        fontSize: 13,
                        color: ClubbarColors.textoSecundario,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _badgeCargo(usuario),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              size: 15,
                              color: ClubbarColors.textoSecundario,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _nomeLoja(usuario.lojaId),
                              style: const TextStyle(
                                fontSize: 12,
                                color: ClubbarColors.textoSecundario,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    if (principal) ...[
                      const SizedBox(height: 7),

                      const Text(
                        'Usuário principal do sistema',
                        style: TextStyle(
                          fontSize: 11,
                          color: ClubbarColors.textoSecundario,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Divider(height: 1, color: ClubbarColors.divisor),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _excluindo ? null : () => _abrirEdicao(usuario),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar'),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: principal || _excluindo
                      ? null
                      : () => _excluirUsuario(usuario),
                  icon: Icon(
                    principal
                        ? Icons.lock_rounded
                        : Icons.delete_outline_rounded,
                  ),
                  label: Text(principal ? 'Protegido' : 'Excluir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: principal
                        ? ClubbarColors.borda
                        : ClubbarColors.erroClaro,
                    foregroundColor: principal
                        ? ClubbarColors.textoSecundario
                        : ClubbarColors.erro,
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _conteudo() {
    if (_carregando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: CircularProgressIndicator(color: ClubbarColors.ambar),
        ),
      );
    }

    if (_erro != null) {
      return ClubbarCard(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 58),

            const SizedBox(height: 12),

            const Text(
              'Não foi possível carregar os usuários',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),

            const SizedBox(height: 8),

            Text(_erro!, textAlign: TextAlign.center),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _carregarTudo,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_usuariosFiltrados.isEmpty) {
      return ClubbarCard(
        child: Column(
          children: [
            const Icon(Icons.people_alt_rounded, size: 58),

            const SizedBox(height: 12),

            const Text(
              'Nenhum usuário encontrado',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _abrirNovoUsuario,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Cadastrar usuário'),
            ),
          ],
        ),
      );
    }

    return Column(children: _usuariosFiltrados.map(_cardUsuario).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,

      appBar: const ClubbarAppBar(mostrarVoltar: true),

      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: 'Usuários',
              subtitulo: _carregando
                  ? 'Carregando usuários...'
                  : '${_usuarios.length} usuário(s) cadastrado(s)',
              icone: Icons.people_alt_rounded,
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                children: [
                  _campoBusca(),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _abrirNovoUsuario,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text(
                              'Novo Usuário',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ClubbarColors.ambar,
                              foregroundColor: ClubbarColors.preto,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      SizedBox(
                        width: 52,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _carregarTudo,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: ClubbarColors.textoPrincipal,
                            side: const BorderSide(color: ClubbarColors.borda),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Icon(Icons.refresh_rounded),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _carregarTudo,
                color: ClubbarColors.ambar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  children: [_conteudo()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
