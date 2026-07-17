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

  bool _salvando = false;
  bool _carregandoLojas = true;
  bool _ocultarSenha = true;

  List<Loja> _lojas = [];
  int? _lojaIdSelecionada;
  String _statusSelecionado = 'ATIVO';

  bool get editando => widget.usuario != null;

  @override
  void initState() {
    super.initState();

    final usuario = widget.usuario;

    if (usuario != null) {
      _nomeController.text = usuario.nmusuario;
      _emailController.text = usuario.emailuser;
      _lojaIdSelecionada = usuario.lojaId;
      _statusSelecionado = usuario.situsuario ?? 'ATIVO';
    }

    _carregarLojas();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  String _mensagemErro(Object erro) {
    final texto = erro.toString().replaceFirst('Exception: ', '').trim();
    return texto.isEmpty ? 'Ocorreu um erro inesperado.' : texto;
  }

  Future<void> _carregarLojas() async {
    setState(() => _carregandoLojas = true);

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
      setState(() => _carregandoLojas = false);
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
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ClubbarColors.ambar, width: 2),
      ),
    );
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      final senha = _senhaController.text.trim();

      if (editando) {
        await _usuarioRepository.atualizar(
          organizacaoId: widget.organizacaoId,
          usuarioId: widget.usuario!.usuarioId,
          nome: _nomeController.text.trim(),
          email: _emailController.text.trim(),
          senha: senha.isEmpty ? null : senha,
          lojaId: _lojaIdSelecionada,
          situsuario: _statusSelecionado,
        );
      } else {
        await _usuarioRepository.criar(
          organizacaoId: widget.organizacaoId,
          nome: _nomeController.text.trim(),
          email: _emailController.text.trim(),
          senha: senha,
          lojaId: _lojaIdSelecionada,
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
      if (mounted) setState(() => _salvando = false);
    }
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
                  : 'Cadastre um acesso ao sistema',
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
                    ClubbarCard(
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: const BoxDecoration(
                              color: ClubbarColors.ambarClaro,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_rounded, size: 31),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              editando ? 'Dados do usuário' : 'Novo usuário',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                            validator: (value) {
                              final texto = value?.trim() ?? '';
                              if (texto.isEmpty) {
                                return 'Informe o nome do usuário';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _decoracaoCampo(
                              label: 'E-mail',
                              icone: Icons.email_outlined,
                            ),
                            validator: (value) {
                              final texto = value?.trim() ?? '';
                              if (texto.isEmpty) return 'Informe o e-mail';
                              if (!RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(texto)) {
                                return 'Informe um e-mail válido';
                              }
                              return null;
                            },
                          ),
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
                            validator: (value) {
                              final senha = value?.trim() ?? '';
                              if (!editando && senha.isEmpty) {
                                return 'Informe a senha';
                              }
                              if (senha.isNotEmpty && senha.length < 6) {
                                return 'Use pelo menos 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _carregandoLojas
                              ? const CircularProgressIndicator(
                                  color: ClubbarColors.ambar,
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
                                    if (value == null) return;
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
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: ClubbarColors.info,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Vincule o usuário a uma loja para limitar '
                              'as operações ao estabelecimento correto.',
                              style: TextStyle(
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
