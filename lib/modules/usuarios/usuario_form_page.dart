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

class UsuarioFormPage extends StatefulWidget {
  final int organizacaoId;
  final Usuario? usuario;

  const UsuarioFormPage({super.key, required this.organizacaoId, this.usuario});

  @override
  State<UsuarioFormPage> createState() => _UsuarioFormPageState();
}

class _UsuarioFormPageState extends State<UsuarioFormPage> {
  final _formKey = GlobalKey<FormState>();

  final UsuarioRepository _usuarioRepository = UsuarioRepository();
  final LojaRepository _lojaRepository = LojaRepository();

  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _salvando = false;
  bool _carregandoLojas = true;

  bool _ocultarSenha = true;
  bool _ocultarConfirmacaoSenha = true;

  List<Loja> _lojas = [];

  int? _lojaIdSelecionada;

  String _statusSelecionado = 'ATIVO';
  String _cargoSelecionado = 'BARMAN';

  bool get editando => widget.usuario != null;

  bool get usuarioPrincipal => editando && widget.usuario!.usuarioId == 1;

  static const List<String> _cargos = [
    'SUPERADMIN',
    'ADMIN',
    'GERENTE',
    'CAIXA',
    'BARMAN',
    'GARCOM',
    'PORTEIRO',
  ];

  @override
  void initState() {
    super.initState();

    final usuario = widget.usuario;

    if (usuario != null) {
      _nomeController.text = usuario.nmusuario;
      _emailController.text = usuario.emailuser;

      _lojaIdSelecionada = usuario.lojaId;

      _statusSelecionado = (usuario.situsuario ?? 'ATIVO').toUpperCase();

      _cargoSelecionado = usuario.dscargo.trim().toUpperCase();

      if (!_cargos.contains(_cargoSelecionado)) {
        _cargoSelecionado = 'BARMAN';
      }
    }

    _carregarLojas();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();

    super.dispose();
  }

  String _mensagemErro(Object erro) {
    final texto = erro
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Exception:', '')
        .trim();

    return texto.isEmpty ? 'Ocorreu um erro inesperado.' : texto;
  }

  String _nomeCargo(String cargo) {
    switch (cargo) {
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

  Future<void> _carregarLojas() async {
    setState(() {
      _carregandoLojas = true;
    });

    try {
      final lista = await _lojaRepository.listar(widget.organizacaoId);

      if (!mounted) return;

      int? lojaSelecionada = _lojaIdSelecionada;

      if (lojaSelecionada != null &&
          !lista.any((loja) => loja.lojaId == lojaSelecionada)) {
        lojaSelecionada = null;
      }

      setState(() {
        _lojas = lista;
        _lojaIdSelecionada = lojaSelecionada;
        _carregandoLojas = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _carregandoLojas = false;
      });

      AppSnackBar.erro(context, 'Não foi possível carregar as lojas.');
    }
  }

  InputDecoration _decoracaoCampo({
    required String label,
    required IconData icone,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icone, color: ClubbarColors.textoSecundario),
      suffixIcon: suffixIcon,
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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ClubbarColors.borda),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ClubbarColors.ambar, width: 2),
      ),
    );
  }

  String? _validarNome(String? value) {
    final texto = value?.trim() ?? '';

    if (texto.isEmpty) {
      return 'Informe o nome do usuário';
    }

    if (texto.length < 3) {
      return 'Informe um nome válido';
    }

    if (texto.length > 200) {
      return 'O nome deve possuir no máximo 200 caracteres';
    }

    return null;
  }

  String? _validarEmail(String? value) {
    final texto = value?.trim().toLowerCase() ?? '';

    if (texto.isEmpty) {
      return 'Informe o e-mail';
    }

    if (texto.length > 200) {
      return 'O e-mail deve possuir no máximo 200 caracteres';
    }

    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!regex.hasMatch(texto)) {
      return 'Informe um e-mail válido';
    }

    return null;
  }

  String? _validarSenha(String? value) {
    final senha = value?.trim() ?? '';

    if (!editando && senha.isEmpty) {
      return 'Informe a senha';
    }

    if (senha.isNotEmpty && senha.length < 6) {
      return 'Use pelo menos 6 caracteres';
    }

    return null;
  }

  String? _validarConfirmacaoSenha(String? value) {
    final senha = _senhaController.text.trim();
    final confirmacao = value?.trim() ?? '';

    if (!editando && confirmacao.isEmpty) {
      return 'Confirme a senha';
    }

    if (senha.isNotEmpty && confirmacao.isEmpty) {
      return 'Confirme a nova senha';
    }

    if (senha.isEmpty && editando) {
      return null;
    }

    if (senha != confirmacao) {
      return 'As senhas não conferem';
    }

    return null;
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      final nome = _nomeController.text.trim();

      final email = _emailController.text.trim().toLowerCase();

      final senha = _senhaController.text.trim();

      // O usuário 1 mantém obrigatoriamente
      // o cargo que já possui.
      final cargo = usuarioPrincipal
          ? widget.usuario!.dscargo
          : _cargoSelecionado;

      if (editando) {
        await _usuarioRepository.atualizar(
          organizacaoId: widget.organizacaoId,
          usuarioId: widget.usuario!.usuarioId,
          nome: nome,
          email: email,
          senha: senha.isEmpty ? null : senha,
          lojaId: _lojaIdSelecionada,
          dscargo: cargo,
          situsuario: _statusSelecionado,
        );
      } else {
        await _usuarioRepository.criar(
          organizacaoId: widget.organizacaoId,
          nome: nome,
          email: email,
          senha: senha,
          lojaId: _lojaIdSelecionada,
          dscargo: cargo,
          situsuario: _statusSelecionado,
        );
      }

      if (!mounted) return;

      AppSnackBar.sucesso(
        context,
        editando
            ? 'Usuário atualizado com sucesso.'
            : 'Usuário criado com sucesso.',
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(context, _mensagemErro(e));
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  Widget _cabecalhoUsuario() {
    return ClubbarCard(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: ClubbarColors.ambarClaro,
              shape: BoxShape.circle,
            ),
            child: Icon(
              usuarioPrincipal
                  ? Icons.admin_panel_settings_rounded
                  : Icons.person_rounded,
              size: 31,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editando ? 'Dados do usuário' : 'Novo usuário',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                if (usuarioPrincipal) ...[
                  const SizedBox(height: 5),

                  const Text(
                    'Usuário principal do Clubbar',
                    style: TextStyle(
                      color: ClubbarColors.textoSecundario,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (usuarioPrincipal)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ClubbarColors.ambarClaro,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 15),
                  SizedBox(width: 5),
                  Text(
                    'Principal',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _campoCargo() {
    return DropdownButtonFormField<String>(
      initialValue: _cargoSelecionado,
      isExpanded: true,
      decoration: _decoracaoCampo(
        label: 'Cargo',
        icone: Icons.badge_outlined,
        suffixIcon: usuarioPrincipal
            ? const Icon(
                Icons.lock_outline_rounded,
                color: ClubbarColors.textoSecundario,
              )
            : null,
      ),
      items: _cargos
          .map(
            (cargo) => DropdownMenuItem<String>(
              value: cargo,
              child: Text(_nomeCargo(cargo)),
            ),
          )
          .toList(),
      onChanged: usuarioPrincipal || _salvando
          ? null
          : (value) {
              if (value == null) return;

              setState(() {
                _cargoSelecionado = value;
              });
            },
    );
  }

  Widget _botaoSalvar() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _salvando ? null : _salvar,
        icon: _salvando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ClubbarColors.preto,
                ),
              )
            : Icon(
                editando ? Icons.save_rounded : Icons.person_add_alt_1_rounded,
              ),
        label: Text(
          _salvando
              ? 'Salvando...'
              : editando
              ? 'Salvar Alterações'
              : 'Cadastrar Usuário',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: ClubbarColors.ambar,
          foregroundColor: ClubbarColors.preto,
          disabledBackgroundColor: ClubbarColors.ambarClaro,
          disabledForegroundColor: ClubbarColors.textoSecundario,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
            ClubbarPageHeader(
              titulo: editando ? 'Editar Usuário' : 'Novo Usuário',
              subtitulo: editando
                  ? 'Atualize os dados de acesso'
                  : 'Cadastre um novo acesso ao sistema',
              icone: Icons.people_alt_rounded,
            ),

            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    _cabecalhoUsuario(),

                    const SizedBox(height: 16),

                    ClubbarCard(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nomeController,
                            textCapitalization: TextCapitalization.words,
                            decoration: _decoracaoCampo(
                              label: 'Nome do usuário',
                              icone: Icons.person_outline_rounded,
                            ),
                            validator: _validarNome,
                          ),

                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: _decoracaoCampo(
                              label: 'E-mail',
                              icone: Icons.email_outlined,
                              hint: 'E-mail utilizado para acessar o sistema',
                            ),
                            validator: _validarEmail,
                          ),

                          const SizedBox(height: 14),

                          _campoCargo(),

                          if (usuarioPrincipal) ...[
                            const SizedBox(height: 8),

                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'O cargo do usuário principal não pode ser alterado.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ClubbarColors.textoSecundario,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _senhaController,
                            obscureText: _ocultarSenha,
                            decoration: _decoracaoCampo(
                              label: editando
                                  ? 'Nova senha (opcional)'
                                  : 'Senha',
                              icone: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                tooltip: _ocultarSenha
                                    ? 'Mostrar senha'
                                    : 'Ocultar senha',
                                onPressed: () {
                                  setState(() {
                                    _ocultarSenha = !_ocultarSenha;
                                  });
                                },
                                icon: Icon(
                                  _ocultarSenha
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                ),
                              ),
                            ),
                            validator: _validarSenha,
                          ),

                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _confirmarSenhaController,
                            obscureText: _ocultarConfirmacaoSenha,
                            decoration: _decoracaoCampo(
                              label: editando
                                  ? 'Confirmar nova senha'
                                  : 'Confirmar senha',
                              icone: Icons.lock_reset_rounded,
                              suffixIcon: IconButton(
                                tooltip: _ocultarConfirmacaoSenha
                                    ? 'Mostrar confirmação'
                                    : 'Ocultar confirmação',
                                onPressed: () {
                                  setState(() {
                                    _ocultarConfirmacaoSenha =
                                        !_ocultarConfirmacaoSenha;
                                  });
                                },
                                icon: Icon(
                                  _ocultarConfirmacaoSenha
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                ),
                              ),
                            ),
                            validator: _validarConfirmacaoSenha,
                          ),

                          const SizedBox(height: 14),

                          _carregandoLojas
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    color: ClubbarColors.ambar,
                                  ),
                                )
                              : DropdownButtonFormField<int?>(
                                  initialValue: _lojaIdSelecionada,
                                  isExpanded: true,
                                  decoration: _decoracaoCampo(
                                    label: 'Loja',
                                    icone: Icons.storefront_outlined,
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Sem loja vinculada'),
                                    ),
                                    ..._lojas.map(
                                      (loja) => DropdownMenuItem<int?>(
                                        value: loja.lojaId,
                                        child: Text(loja.nmloja),
                                      ),
                                    ),
                                  ],
                                  onChanged: _salvando
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _lojaIdSelecionada = value;
                                          });
                                        },
                                ),

                          const SizedBox(height: 14),

                          DropdownButtonFormField<String>(
                            initialValue: _statusSelecionado,
                            decoration: _decoracaoCampo(
                              label: 'Status',
                              icone: Icons.verified_user_outlined,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'ATIVO',
                                child: Text('Ativo'),
                              ),
                              DropdownMenuItem(
                                value: 'INATIVO',
                                child: Text('Inativo'),
                              ),
                            ],
                            onChanged: _salvando
                                ? null
                                : (value) {
                                    if (value == null) {
                                      return;
                                    }

                                    setState(() {
                                      _statusSelecionado = value;
                                    });
                                  },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    ClubbarCard(
                      elevation: 0,
                      backgroundColor: ClubbarColors.infoClaro,
                      borderColor: ClubbarColors.info,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: ClubbarColors.info,
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              usuarioPrincipal
                                  ? 'Este é o usuário principal do sistema. '
                                        'O cargo e a exclusão deste usuário '
                                        'são protegidos. Nome, e-mail e senha '
                                        'podem ser atualizados normalmente.'
                                  : 'O e-mail é utilizado como chave de acesso. '
                                        'Ao vincular uma loja, o usuário poderá '
                                        'ser direcionado às operações daquele '
                                        'estabelecimento.',
                              style: const TextStyle(
                                color: ClubbarColors.info,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _botaoSalvar(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
