import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/repositories/organizacao_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/organizacao.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/masks.dart';

enum OrganizacaoSecao { empresa, contato, endereco }

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
  final _razaoSocialController = TextEditingController();
  final _cnpjController = TextEditingController();

  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();

  final _cepController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeIdController = TextEditingController();

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
    _razaoSocialController.dispose();
    _cnpjController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _cepController.dispose();
    _enderecoController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroController.dispose();
    _cidadeIdController.dispose();

    super.dispose();
  }

  void _preencherCampos() {
    _nomeController.text = _organizacao.nmorganizacao;
    _razaoSocialController.text = _organizacao.rzsocialorganizacao ?? '';
    _cnpjController.text = Formatters.cnpj(_organizacao.cnpjorganizacao ?? '');

    _emailController.text = _organizacao.emailorganizacao ?? '';
    _telefoneController.text = Formatters.telefone(
      _organizacao.telorganizacao ?? '',
    );

    _cepController.text = Formatters.cep(_organizacao.ceporganizacao ?? '');
    _enderecoController.text = _organizacao.endorganizacao ?? '';
    _numeroController.text = _organizacao.nrendorganizacao ?? '';
    _complementoController.text = _organizacao.complorganizacao ?? '';
    _bairroController.text = _organizacao.nmbairro ?? '';
    _cidadeIdController.text = _organizacao.cidadeId?.toString() ?? '';

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
      case OrganizacaoSecao.endereco:
        return 'Endereço';
    }
  }

  IconData get _iconePagina {
    switch (widget.secao) {
      case OrganizacaoSecao.empresa:
        return Icons.business_rounded;
      case OrganizacaoSecao.contato:
        return Icons.contact_phone_rounded;
      case OrganizacaoSecao.endereco:
        return Icons.location_on_rounded;
    }
  }

  Map<String, dynamic> _montarPayload() {
    switch (widget.secao) {
      case OrganizacaoSecao.empresa:
        return {
          'nmorganizacao': _nomeController.text.trim(),
          'rzsocialorganizacao': _razaoSocialController.text.trim().isEmpty
              ? null
              : _razaoSocialController.text.trim(),
          'cnpjorganizacao': Validators.somenteNumeros(_cnpjController.text),
          'sitorganizacao': _status,
        };

      case OrganizacaoSecao.contato:
        return {
          'emailorganizacao': _emailController.text.trim().toLowerCase(),
          'telorganizacao': Validators.somenteNumeros(_telefoneController.text),
        };

      case OrganizacaoSecao.endereco:
        return {
          'ceporganizacao': Validators.somenteNumeros(_cepController.text),
          'endorganizacao': _enderecoController.text.trim(),
          'nrendorganizacao': _numeroController.text.trim(),
          'complorganizacao': _complementoController.text.trim().isEmpty
              ? null
              : _complementoController.text.trim(),
          'nmbairro': _bairroController.text.trim(),
          'cidade_id': int.tryParse(_cidadeIdController.text.trim()),
        };
    }
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
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
          controller: _razaoSocialController,
          textCapitalization: TextCapitalization.words,
          maxLength: 160,
          inputFormatters: [LengthLimitingTextInputFormatter(160)],
          decoration: _decoracao(
            label: 'Razão social',
            icone: Icons.account_balance_outlined,
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _cnpjController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            CnpjInputFormatter(),
            LengthLimitingTextInputFormatter(18),
          ],
          decoration: _decoracao(
            label: 'CNPJ',
            hint: '00.000.000/0000-00',
            icone: Icons.badge_outlined,
          ),
          validator: (valor) {
            final texto = valor?.trim() ?? '';

            if (texto.isEmpty) {
              return 'Informe o CNPJ.';
            }

            if (!Validators.cnpjValido(texto)) {
              return 'Informe um CNPJ válido.';
            }

            return null;
          },
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: _decoracao(
            label: 'Situação',
            icone: Icons.toggle_on_outlined,
          ),
          items: const [
            DropdownMenuItem(value: 'ATIVA', child: Text('Ativa')),
            DropdownMenuItem(value: 'INATIVA', child: Text('Inativa')),
          ],
          onChanged: _salvando
              ? null
              : (valor) {
                  if (valor == null) return;

                  setState(() {
                    _status = valor;
                  });
                },
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

  Widget _campoEndereco() {
    return Column(
      children: [
        TextFormField(
          controller: _cepController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            CepInputFormatter(),
            LengthLimitingTextInputFormatter(9),
          ],
          decoration: _decoracao(
            label: 'CEP',
            hint: '00000-000',
            icone: Icons.markunread_mailbox_outlined,
          ),
          validator: (valor) {
            final numeros = Validators.somenteNumeros(valor ?? '');

            if (numeros.length != 8) {
              return 'Informe um CEP válido.';
            }

            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _enderecoController,
          textCapitalization: TextCapitalization.words,
          maxLength: 255,
          inputFormatters: [LengthLimitingTextInputFormatter(255)],
          decoration: _decoracao(
            label: 'Endereço',
            icone: Icons.route_outlined,
          ),
          validator: (valor) {
            if ((valor?.trim() ?? '').isEmpty) {
              return 'Informe o endereço.';
            }

            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _numeroController,
          maxLength: 20,
          inputFormatters: [LengthLimitingTextInputFormatter(20)],
          decoration: _decoracao(label: 'Número', icone: Icons.pin_outlined),
          validator: (valor) {
            if ((valor?.trim() ?? '').isEmpty) {
              return 'Informe o número.';
            }

            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _complementoController,
          textCapitalization: TextCapitalization.words,
          maxLength: 120,
          inputFormatters: [LengthLimitingTextInputFormatter(120)],
          decoration: _decoracao(
            label: 'Complemento',
            icone: Icons.add_home_work_outlined,
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _bairroController,
          textCapitalization: TextCapitalization.words,
          maxLength: 120,
          inputFormatters: [LengthLimitingTextInputFormatter(120)],
          decoration: _decoracao(
            label: 'Bairro',
            icone: Icons.holiday_village_outlined,
          ),
          validator: (valor) {
            if ((valor?.trim() ?? '').isEmpty) {
              return 'Informe o bairro.';
            }

            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _cidadeIdController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _decoracao(
            label: 'Código da cidade',
            hint: _organizacao.nmcidade == null
                ? 'Informe o código'
                : '${_organizacao.nmcidade}/${_organizacao.sgestado ?? ''}',
            icone: Icons.location_city_outlined,
          ),
          validator: (valor) {
            final cidadeId = int.tryParse(valor?.trim() ?? '');

            if (cidadeId == null || cidadeId <= 0) {
              return 'Informe uma cidade válida.';
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
      case OrganizacaoSecao.endereco:
        return _campoEndereco();
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
              subtitulo: 'Atualize os dados da organização',
              icone: _iconePagina,
            ),
            _conteudo(),
          ],
        ),
      ),
    );
  }
}
