import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/repositories/organizacao_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/masks.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/organizacao.dart';

enum OrganizacaoSecao { empresa, contato }

class OrganizacaoFormPage extends StatefulWidget {
  final Organizacao organizacao;
  final OrganizacaoSecao secao;

  const OrganizacaoFormPage({
    super.key,
    required this.organizacao,
    required this.secao,
  });

  @override
  State<OrganizacaoFormPage> createState() => _OrganizacaoFormPageState();
}

class _OrganizacaoFormPageState extends State<OrganizacaoFormPage> {
  final _formKey = GlobalKey<FormState>();

  final OrganizacaoRepository _repository = OrganizacaoRepository();

  final _nomeController = TextEditingController();
  final _responsavelController = TextEditingController();

  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();

  bool _salvando = false;
  String _status = 'ATIVA';

  Organizacao get _organizacao => widget.organizacao;

  @override
  void initState() {
    super.initState();
    _preencherCampos();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _responsavelController.dispose();

    _emailController.dispose();
    _telefoneController.dispose();

    super.dispose();
  }

  void _preencherCampos() {
    _nomeController.text = _organizacao.nmorganizacao;

    _responsavelController.text = _organizacao.nmresponsavelprincipal ?? '';

    _emailController.text = _organizacao.emailorganizacao ?? '';

    _telefoneController.text = Formatters.telefone(
      _organizacao.telorganizacao ?? '',
    );

    _status = _organizacao.sitorganizacao.trim().isEmpty
        ? 'ATIVA'
        : _organizacao.sitorganizacao.toUpperCase();
  }

  String get _tituloPagina {
    switch (widget.secao) {
      case OrganizacaoSecao.empresa:
        return 'Dados da empresa';

      case OrganizacaoSecao.contato:
        return 'Contato';
    }
  }

  Map<String, dynamic> _montarPayload() {
    switch (widget.secao) {
      case OrganizacaoSecao.empresa:
        return {
          'nmorganizacao': _nomeController.text.trim(),
          'nmresponsavelprincipal': _responsavelController.text.trim().isEmpty
              ? null
              : _responsavelController.text.trim(),
        };

      case OrganizacaoSecao.contato:
        return {
          'emailorganizacao': _emailController.text.trim().toLowerCase(),
          'telorganizacao': Validators.somenteNumeros(_telefoneController.text),
        };
    }
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();

    final formularioValido = _formKey.currentState?.validate() ?? false;

    if (!formularioValido) {
      return;
    }

    final usuarioId = await StorageService.getUsuarioId();

    if (usuarioId == null || usuarioId <= 0) {
      if (!mounted) return;

      AppSnackBar.erro(
        context,
        'Usuário não encontrado. Faça login novamente.',
      );

      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      await _repository.atualizar(usuarioId, _montarPayload());

      if (!mounted) return;

      AppSnackBar.sucesso(context, '$_tituloPagina atualizado com sucesso.');

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      AppSnackBar.erro(
        context,
        e.toString().replaceFirst('Exception: ', '').trim(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  InputDecoration _decoracao({
    required String label,
    required IconData icone,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icone, color: ClubbarColors.textoSecundario),
      filled: true,
      fillColor: ClubbarColors.branco,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ClubbarColors.erro),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ClubbarColors.erro, width: 2),
      ),
    );
  }

  Widget _campoEmpresa() {
    return Column(
      children: [
        TextFormField(
          controller: _nomeController,
          textCapitalization: TextCapitalization.words,
          maxLength: 120,
          inputFormatters: [LengthLimitingTextInputFormatter(120)],
          decoration: _decoracao(
            label: 'Nome fantasia',
            icone: Icons.storefront_outlined,
          ),
          validator: (valor) {
            final texto = valor?.trim() ?? '';

            if (texto.length < 3) {
              return 'Informe pelo menos 3 caracteres.';
            }

            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _responsavelController,
          textCapitalization: TextCapitalization.words,
          maxLength: 120,
          inputFormatters: [LengthLimitingTextInputFormatter(120)],
          decoration: _decoracao(
            label: 'Responsável principal',
            icone: Icons.person_outline_rounded,
          ),
          validator: (valor) {
            final texto = valor?.trim() ?? '';
            return texto.length < 2 ? 'Informe o responsável principal.' : null;
          },
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration:
              _decoracao(
                label: 'Situação da empresa',
                icone: Icons.toggle_on_outlined,
              ).copyWith(
                helperText:
                    'A situação é controlada exclusivamente pela equipe Clubbar.',
                helperMaxLines: 2,
              ),
          items: const [
            DropdownMenuItem(value: 'ATIVA', child: Text('Ativa')),
            DropdownMenuItem(value: 'INATIVA', child: Text('Inativa')),
          ],
          onChanged: null,
        ),
      ],
    );
  }

  Widget _campoContato() {
    return Column(
      children: [
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 255,
          inputFormatters: [LengthLimitingTextInputFormatter(255)],
          decoration: _decoracao(
            label: 'E-mail',
            hint: 'contato@empresa.com.br',
            icone: Icons.email_outlined,
          ),
          validator: (valor) {
            final texto = valor?.trim() ?? '';

            if (texto.isEmpty) {
              return 'Informe o e-mail.';
            }

            if (!Validators.emailValido(texto)) {
              return 'Informe um e-mail válido.';
            }

            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _telefoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            TelefoneInputFormatter(),
            LengthLimitingTextInputFormatter(15),
          ],
          decoration: _decoracao(
            label: 'Telefone ou celular',
            hint: '(35) 99999-9999',
            icone: Icons.phone_outlined,
          ),
          validator: (valor) {
            final numeros = Validators.somenteNumeros(valor ?? '');

            if (numeros.length != 10 && numeros.length != 11) {
              return 'Informe um telefone válido com DDD.';
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _formularioDaSecao() {
    switch (widget.secao) {
      case OrganizacaoSecao.empresa:
        return _campoEmpresa();

      case OrganizacaoSecao.contato:
        return _campoContato();
    }
  }

  Widget _conteudo() {
    return Expanded(
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          ClubbarCard(
            elevation: 1,
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _formularioDaSecao(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _salvando ? null : _salvar,
                      icon: _salvando
                          ? const SizedBox(
                              width: 21,
                              height: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ClubbarColors.preto,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _salvando ? 'Salvando...' : 'Salvar alterações',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
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
                  ),
                ],
              ),
            ),
          ),
        ],
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
              titulo: _tituloPagina,
              subtitulo: 'Atualize os dados da empresa',
            ),
            _conteudo(),
          ],
        ),
      ),
    );
  }
}
