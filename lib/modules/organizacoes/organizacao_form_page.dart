import 'package:flutter/material.dart';

import '../../core/repositories/organizacao_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../models/organizacao.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../core/widgets/clubbar_footer.dart';
import 'package:flutter/services.dart';

class OrganizacaoFormPage extends StatefulWidget {
  final Organizacao? organizacao;

  const OrganizacaoFormPage({super.key, this.organizacao});

  @override
  State<OrganizacaoFormPage> createState() => _OrganizacaoFormPageState();
}

class _OrganizacaoFormPageState extends State<OrganizacaoFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = OrganizacaoRepository();

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _cnpjController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();

  bool _salvando = false;
  bool _carregando = true;
  bool _editando = false;

  String _status = 'ATIVA';

  bool get editando => _editando;

  bool _emailValido(String email) {
    final regex = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

    return regex.hasMatch(email);
  }

  bool _cnpjValido(String valor) {
    final cnpj = valor.replaceAll(RegExp(r'[^0-9]'), '');

    if (cnpj.length != 14) {
      return false;
    }

    if (RegExp(r'^(\d)\1{13}$').hasMatch(cnpj)) {
      return false;
    }

    int calcularDigito(String base, List<int> pesos) {
      var soma = 0;

      for (var i = 0; i < pesos.length; i++) {
        soma += int.parse(base[i]) * pesos[i];
      }

      final resto = soma % 11;

      return resto < 2 ? 0 : 11 - resto;
    }

    final primeiroDigito = calcularDigito(cnpj.substring(0, 12), [
      5,
      4,
      3,
      2,
      9,
      8,
      7,
      6,
      5,
      4,
      3,
      2,
    ]);

    final segundoDigito = calcularDigito(
      '${cnpj.substring(0, 12)}$primeiroDigito',
      [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2],
    );

    return cnpj.endsWith('$primeiroDigito$segundoDigito');
  }

  @override
  void initState() {
    super.initState();
    _inicializarTela();
  }

  Future<void> _inicializarTela() async {
    if (widget.organizacao != null) {
      _preencherCampos(widget.organizacao!);

      if (!mounted) return;

      setState(() {
        _editando = true;
        _carregando = false;
      });

      return;
    }

    await _carregarOrganizacao();
  }

  void _preencherCampos(Organizacao org) {
    _nomeController.text = org.nmorganizacao;
    _cnpjController.text = org.cnpjorganizacao ?? '';
    _emailController.text = org.emailorganizacao ?? '';
    _telefoneController.text = org.telorganizacao ?? '';
    _status = org.sitorganizacao ?? 'ATIVA';
  }

  Future<void> _carregarOrganizacao() async {
    try {
      final usuarioId = await StorageService.getUsuarioId();

      if (usuarioId == null || usuarioId == 0) {
        if (!mounted) return;

        setState(() {
          _carregando = false;
          _editando = false;
        });

        AppSnackBar.aviso(
          context,
          'Usuário não identificado. Faça login novamente.',
        );

        return;
      }

      final organizacao = await _repository.buscarPorUsuario(usuarioId);

      if (!mounted) return;

      _preencherCampos(organizacao);

      setState(() {
        _editando = true;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar organização: $e');

      if (!mounted) return;

      setState(() {
        _carregando = false;
        _editando = false;
      });

      AppSnackBar.erro(context, _mensagemErro(e));
    }
  }

  String _mensagemErro(Object erro) {
    final texto = erro.toString().replaceFirst('Exception: ', '').trim();

    if (texto.isEmpty) {
      return 'Ocorreu um erro inesperado.';
    }

    return texto;
  }

  String _somenteNumeros(String valor) {
    return valor.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _formatarCnpj(String valor) {
    final numeros = _somenteNumeros(valor);

    if (numeros.isEmpty) return '';

    final limitado = numeros.length > 14 ? numeros.substring(0, 14) : numeros;

    final buffer = StringBuffer();

    for (var i = 0; i < limitado.length; i++) {
      if (i == 2 || i == 5) {
        buffer.write('.');
      } else if (i == 8) {
        buffer.write('/');
      } else if (i == 12) {
        buffer.write('-');
      }

      buffer.write(limitado[i]);
    }

    return buffer.toString();
  }

  String _formatarTelefone(String valor) {
    final numeros = _somenteNumeros(valor);

    if (numeros.isEmpty) return '';

    final limitado = numeros.length > 11 ? numeros.substring(0, 11) : numeros;

    if (limitado.length <= 2) {
      return '($limitado';
    }

    if (limitado.length <= 6) {
      return '(${limitado.substring(0, 2)}) '
          '${limitado.substring(2)}';
    }

    if (limitado.length <= 10) {
      return '(${limitado.substring(0, 2)}) '
          '${limitado.substring(2, 6)}-'
          '${limitado.substring(6)}';
    }

    return '(${limitado.substring(0, 2)}) '
        '${limitado.substring(2, 7)}-'
        '${limitado.substring(7)}';
  }

  InputDecoration _decoracaoCampo({
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

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      final dados = {
        'nmorganizacao': _nomeController.text.trim(),
        'cnpjorganizacao': _somenteNumeros(_cnpjController.text),
        'emailorganizacao': _emailController.text.trim(),
        'telorganizacao': _somenteNumeros(_telefoneController.text),
        'sitorganizacao': _status,
      };

      if (editando) {
        final usuarioId = await StorageService.getUsuarioId();

        if (usuarioId == null || usuarioId == 0) {
          throw Exception('Usuário não encontrado. Faça login novamente.');
        }

        await _repository.atualizar(usuarioId, dados);
      } else {
        await _repository.criar({
          'nmorganizacao': _nomeController.text.trim(),
          'cnpjorganizacao': _somenteNumeros(_cnpjController.text),
        });
      }

      if (!mounted) return;

      AppSnackBar.sucesso(
        context,
        editando
            ? 'Organização atualizada com sucesso.'
            : 'Organização criada com sucesso.',
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

  Widget _formulario() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nomeController,
            maxLength: 120,
            inputFormatters: [LengthLimitingTextInputFormatter(120)],
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome da organização',
              hintText: 'Digite o nome da organização',
              prefixIcon: Icon(Icons.business_outlined),
              border: OutlineInputBorder(),
              counterText: '',
            ),
            validator: (valor) {
              final texto = valor?.trim() ?? '';

              if (texto.isEmpty) {
                return 'Informe o nome da organização.';
              }

              if (texto.length < 3) {
                return 'O nome deve ter pelo menos 3 caracteres.';
              }

              if (texto.length > 120) {
                return 'O nome pode ter no máximo 120 caracteres.';
              }

              return null;
            },
          ),

          const SizedBox(height: 14),

          TextFormField(
            controller: _cnpjController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              CnpjInputFormatter(),
              LengthLimitingTextInputFormatter(18),
            ],
            decoration: const InputDecoration(
              labelText: 'CNPJ',
              hintText: '00.000.000/0000-00',
              prefixIcon: Icon(Icons.badge_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (valor) {
              final cnpj = valor?.trim() ?? '';

              if (cnpj.isEmpty) {
                return 'Informe o CNPJ.';
              }

              if (!_cnpjValido(cnpj)) {
                return 'Informe um CNPJ válido.';
              }

              return null;
            },
          ),

          if (editando) ...[
            const SizedBox(height: 14),

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 150,
              inputFormatters: [LengthLimitingTextInputFormatter(150)],
              decoration: const InputDecoration(
                labelText: 'E-mail',
                hintText: 'contato@empresa.com.br',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
                counterText: '',
              ),
              validator: (valor) {
                final email = valor?.trim() ?? '';

                if (email.isEmpty) {
                  return 'Informe o e-mail.';
                }

                if (!_emailValido(email)) {
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
              decoration: const InputDecoration(
                labelText: 'Telefone / celular',
                hintText: '(35) 99999-9999',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (valor) {
                final numeros = (valor ?? '').replaceAll(RegExp(r'[^0-9]'), '');

                if (numeros.isEmpty) {
                  return 'Informe o telefone.';
                }

                if (numeros.length != 10 && numeros.length != 11) {
                  return 'Informe um telefone válido com DDD.';
                }

                if (numeros.length == 11 && numeros[2] != '9') {
                  return 'O celular deve começar com 9 após o DDD.';
                }

                return null;
              },
            ),

            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: _decoracaoCampo(
                label: 'Status',
                icone: Icons.toggle_on_outlined,
              ),
              items: const [
                DropdownMenuItem(value: 'ATIVA', child: Text('Ativa')),
                DropdownMenuItem(value: 'INATIVA', child: Text('Inativa')),
              ],
              onChanged: _salvando
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _status = value;
                      });
                    },
            ),
          ],

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
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          const SizedBox(height: 4),
          ClubbarCard(
            elevation: 1,
            padding: const EdgeInsets.all(18),
            child: _formulario(),
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
              titulo: editando ? 'Organização' : 'Nova Organização',
              subtitulo: editando
                  ? 'Gerencie os dados da empresa'
                  : 'Cadastre os dados da empresa',
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

class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var numeros = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.length > 11) {
      numeros = numeros.substring(0, 11);
    }

    String texto;

    if (numeros.isEmpty) {
      texto = '';
    } else if (numeros.length <= 2) {
      texto = '($numeros';
    } else if (numeros.length <= 6) {
      texto = '(${numeros.substring(0, 2)}) ${numeros.substring(2)}';
    } else if (numeros.length <= 10) {
      texto =
          '(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 6)}-'
          '${numeros.substring(6)}';
    } else {
      texto =
          '(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 7)}-'
          '${numeros.substring(7)}';
    }

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

class CnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var numeros = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.length > 14) {
      numeros = numeros.substring(0, 14);
    }

    final buffer = StringBuffer();

    for (var i = 0; i < numeros.length; i++) {
      if (i == 2 || i == 5) {
        buffer.write('.');
      }

      if (i == 8) {
        buffer.write('/');
      }

      if (i == 12) {
        buffer.write('-');
      }

      buffer.write(numeros[i]);
    }

    final texto = buffer.toString();

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
