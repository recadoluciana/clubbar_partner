import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/clubbar_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/clubbar_app_bar.dart';
import '../../../core/widgets/clubbar_card.dart';
import '../../../core/widgets/clubbar_page_header.dart';

import '../models/leadparceiro.dart';
import '../repositories/leadparceiro_repository.dart';

class LeadParceiroConverterPage extends StatefulWidget {
  final LeadParceiro lead;

  const LeadParceiroConverterPage({
    super.key,
    required this.lead,
  });

  @override
  State<LeadParceiroConverterPage> createState() =>
      _LeadParceiroConverterPageState();
}

class _LeadParceiroConverterPageState
    extends State<LeadParceiroConverterPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = LeadParceiroRepository();

  final _razaoSocialController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _cepController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _bairroController = TextEditingController();

  bool _convertendo = false;

  @override
  void dispose() {
    _razaoSocialController.dispose();
    _cnpjController.dispose();
    _cepController.dispose();
    _enderecoController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroController.dispose();
    super.dispose();
  }

  String _somenteNumeros(String valor) {
    return valor.replaceAll(RegExp(r'\D'), '');
  }

  InputDecoration _decoracao({
    required String label,
    required IconData icone,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icone),
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
        borderSide: const BorderSide(
          color: ClubbarColors.ambar,
          width: 2,
        ),
      ),
    );
  }

  String? _validarObrigatorio(String? valor, String campo) {
    if ((valor ?? '').trim().isEmpty) {
      return 'Informe $campo.';
    }
    return null;
  }

  Future<bool> _confirmarConversao() async {
    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.handshake_rounded,
                color: ClubbarColors.ambarEscuro,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Confirmar conversão',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: Text(
            'Deseja converter "${widget.lead.nmestabelecimento}" em parceiro?\n\n'
            'Essa operação criará uma organização e um estabelecimento.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Confirmar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ClubbarColors.ambar,
                foregroundColor: ClubbarColors.preto,
              ),
            ),
          ],
        );
      },
    );

    return confirmado == true;
  }

  Future<void> _converter() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final confirmado = await _confirmarConversao();
    if (!confirmado || !mounted) return;

    setState(() {
      _convertendo = true;
    });

    try {
      await _repository.converterEmParceiro(
        leadparceiroId: widget.lead.leadparceiroId,
        razaoSocial: _razaoSocialController.text,
        cnpj: _cnpjController.text,
        cep: _cepController.text,
        endereco: _enderecoController.text,
        numero: _numeroController.text,
        complemento: _complementoController.text,
        bairro: _bairroController.text,
      );

      if (!mounted) return;

      AppSnackBar.sucesso(
        context,
        'Lead convertido em parceiro com sucesso.',
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      final mensagem = e.toString().replaceFirst('Exception: ', '').trim();
      AppSnackBar.erro(context, mensagem);
    } finally {
      if (mounted) {
        setState(() {
          _convertendo = false;
        });
      }
    }
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
              titulo: 'Converter em parceiro',
              subtitulo: 'Complete os dados cadastrais da organização',
              icone: Icons.handshake_rounded,
              mostrarDadosSessao: false,
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClubbarCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Lead selecionado',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: ClubbarColors.textoSecundario,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.lead.nmestabelecimento,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${widget.lead.tipo} • '
                                  '${widget.lead.nmcidade}/${widget.lead.sgestado}',
                                  style: const TextStyle(
                                    color: ClubbarColors.textoSecundario,
                                    fontWeight: FontWeight.w600,
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
                                  controller: _razaoSocialController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: _decoracao(
                                    label: 'Razão social',
                                    icone: Icons.business_rounded,
                                    hint: 'Bar do Crispim Ltda',
                                  ),
                                  validator: (valor) => _validarObrigatorio(
                                    valor,
                                    'a razão social',
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _cnpjController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(14),
                                  ],
                                  decoration: _decoracao(
                                    label: 'CNPJ',
                                    icone: Icons.badge_outlined,
                                    hint: 'Somente os 14 números',
                                  ),
                                  validator: (valor) {
                                    final cnpj = _somenteNumeros(valor ?? '');
                                    if (cnpj.isEmpty) {
                                      return 'Informe o CNPJ.';
                                    }
                                    if (cnpj.length != 14) {
                                      return 'O CNPJ deve possuir 14 números.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _cepController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(8),
                                  ],
                                  decoration: _decoracao(
                                    label: 'CEP',
                                    icone: Icons.location_on_outlined,
                                    hint: 'Somente os 8 números',
                                  ),
                                  validator: (valor) {
                                    final cep = _somenteNumeros(valor ?? '');
                                    if (cep.isNotEmpty && cep.length != 8) {
                                      return 'O CEP deve possuir 8 números.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _enderecoController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: _decoracao(
                                    label: 'Endereço',
                                    icone: Icons.signpost_outlined,
                                    hint: 'Rua das Flores',
                                  ),
                                  validator: (valor) => _validarObrigatorio(
                                    valor,
                                    'o endereço',
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: _numeroController,
                                        decoration: _decoracao(
                                          label: 'Número',
                                          icone: Icons.numbers_rounded,
                                          hint: '120',
                                        ),
                                        validator: (valor) =>
                                            _validarObrigatorio(
                                              valor,
                                              'o número',
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: _complementoController,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        decoration: _decoracao(
                                          label: 'Complemento',
                                          icone: Icons.apartment_rounded,
                                          hint: 'Sala 2',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _bairroController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: _decoracao(
                                    label: 'Bairro',
                                    icone: Icons.map_outlined,
                                    hint: 'Centro',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _convertendo ? null : _converter,
                              icon: _convertendo
                                  ? const SizedBox(
                                      width: 21,
                                      height: 21,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.handshake_rounded),
                              label: Text(
                                _convertendo
                                    ? 'Convertendo...'
                                    : 'Confirmar conversão',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ClubbarColors.ambar,
                                foregroundColor: ClubbarColors.preto,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
