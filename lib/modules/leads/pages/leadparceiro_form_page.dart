import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/clubbar_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/clubbar_app_bar.dart';
import '../../../core/widgets/clubbar_card.dart';

import '../../../core/widgets/clubbar_page_header.dart';
import '../models/leadparceiro.dart';
import '../repositories/leadparceiro_repository.dart';

class LeadParceiroFormPage extends StatefulWidget {
  final LeadParceiro lead;

  const LeadParceiroFormPage({super.key, required this.lead});

  @override
  State<LeadParceiroFormPage> createState() => _LeadParceiroFormPageState();
}

class _LeadParceiroFormPageState extends State<LeadParceiroFormPage> {
  bool get _leadConvertido {
    return widget.lead.status == 'CONVERTIDO';
  }

  final _formKey = GlobalKey<FormState>();
  final _repository = LeadParceiroRepository();

  final _responsavelController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _emailController = TextEditingController();

  late String _tipoSelecionado;
  late String _statusSelecionado;
  bool _salvando = false;

  static const _tipos = ['BAR', 'CASA_NOTURNA', 'PRODUTOR_EVENTOS'];
  static const _status = [
    'NOVO',
    'CONTATADO',
    'NEGOCIANDO',
    'CONVERTIDO',
    'PERDIDO',
  ];

  @override
  void initState() {
    super.initState();
    _responsavelController.text = widget.lead.nmresponsavel;
    _telefoneController.text = _formatarTelefone(widget.lead.telefone);
    _emailController.text = widget.lead.email;
    _tipoSelecionado = widget.lead.tipo;
    _statusSelecionado = widget.lead.status;
  }

  @override
  void dispose() {
    _responsavelController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _somenteNumeros(String valor) => valor.replaceAll(RegExp(r'\D'), '');

  String _formatarTelefone(String valor) {
    final numeros = _somenteNumeros(valor);
    if (numeros.length == 11) {
      return '(${numeros.substring(0, 2)}) ${numeros.substring(2, 7)}-${numeros.substring(7)}';
    }
    if (numeros.length == 10) {
      return '(${numeros.substring(0, 2)}) ${numeros.substring(2, 6)}-${numeros.substring(6)}';
    }
    return valor;
  }

  String _nomeTipo(String tipo) {
    switch (tipo) {
      case 'CASA_NOTURNA':
        return 'Casa noturna';
      case 'PRODUTOS_EVENTOS':
        return 'Produtor de Eventos';
      default:
        return 'Bar';
    }
  }

  String _nomeStatus(String status) {
    switch (status) {
      case 'CONTATADO':
        return 'Contatado';
      case 'NEGOCIANDO':
        return 'Negociando';
      case 'CONVERTIDO':
        return 'Convertido';
      case 'PERDIDO':
        return 'Perdido';
      default:
        return 'Novo';
    }
  }

  String _formatarData(DateTime? data) {
    if (data == null) return 'Não informado';
    final local = data.toLocal();
    String dois(int valor) => valor.toString().padLeft(2, '0');
    return '${dois(local.day)}/${dois(local.month)}/${local.year} às ${dois(local.hour)}:${dois(local.minute)}';
  }

  InputDecoration _decoracao({
    required String label,
    required IconData icone,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
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

  Widget _campoLeitura({
    required String label,
    required String valor,
    required IconData icone,
    int maxLines = 1,
  }) {
    return TextFormField(
      initialValue: valor,
      readOnly: true,
      maxLines: maxLines,
      decoration: _decoracao(
        label: label,
        icone: icone,
        suffixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: ClubbarColors.textoSecundario,
        ),
      ),
    );
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();

    final statusParaSalvar = _leadConvertido
        ? 'CONVERTIDO'
        : _statusSelecionado;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      await _repository.atualizar(
        leadparceiroId: widget.lead.leadparceiroId,
        nmresponsavel: _responsavelController.text.trim(),
        tipo: _tipoSelecionado,
        telefone: _somenteNumeros(_telefoneController.text),
        email: _emailController.text.trim().toLowerCase(),
        status: statusParaSalvar,
      );

      if (!mounted) return;
      AppSnackBar.sucesso(context, 'Lead atualizado com sucesso.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.erro(
        context,
        e.toString().replaceFirst('Exception: ', '').trim(),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mensagem = widget.lead.mensagem?.trim();

    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: SafeArea(
        child: Column(
          children: [
            const ClubbarPageHeader(
              titulo: 'Atendimento do Lead',
              subtitulo: 'Atualize os dados de contato e a situação comercial',
              icone: Icons.handshake_rounded,
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
                            child: const Icon(
                              Icons.storefront_rounded,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.lead.nmestabelecimento,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.lead.nmcidade}/${widget.lead.sgestado}',
                                  style: const TextStyle(
                                    color: ClubbarColors.textoSecundario,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: ClubbarColors.ambarClaro,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '#${widget.lead.leadparceiroId}',
                              style: const TextStyle(
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
                            controller: _responsavelController,
                            textCapitalization: TextCapitalization.words,
                            maxLength: 120,
                            decoration: _decoracao(
                              label: 'Nome do responsável',
                              icone: Icons.person_outline_rounded,
                            ),
                            validator: (value) {
                              if ((value?.trim() ?? '').length < 3) {
                                return 'Informe pelo menos 3 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _telefoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                              _TelefoneInputFormatter(),
                            ],
                            decoration: _decoracao(
                              label: 'Telefone',
                              icone: Icons.phone_outlined,
                            ),
                            validator: (value) {
                              final numeros = _somenteNumeros(value ?? '');
                              if (numeros.length != 10 &&
                                  numeros.length != 11) {
                                return 'Informe um telefone válido com DDD';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            enableSuggestions: false,
                            maxLength: 160,
                            decoration: _decoracao(
                              label: 'E-mail',
                              icone: Icons.email_outlined,
                            ),
                            validator: (value) {
                              final texto = value?.trim() ?? '';
                              if (!RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(texto)) {
                                return 'Informe um e-mail válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _tipoSelecionado,
                            isExpanded: true,
                            decoration: _decoracao(
                              label: 'Tipo',
                              icone: Icons.category_outlined,
                            ),
                            items: _tipos
                                .map(
                                  (tipo) => DropdownMenuItem(
                                    value: tipo,
                                    child: Text(_nomeTipo(tipo)),
                                  ),
                                )
                                .toList(),
                            onChanged: _salvando
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() => _tipoSelecionado = value);
                                  },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: _statusSelecionado,
                            isExpanded: true,
                            decoration:
                                _decoracao(
                                  label: 'Status',
                                  icone: _leadConvertido
                                      ? Icons.lock_rounded
                                      : Icons.track_changes_rounded,
                                ).copyWith(
                                  helperText: _leadConvertido
                                      ? 'O status não pode ser alterado após a conversão.'
                                      : null,
                                  suffixIcon: _leadConvertido
                                      ? const Icon(
                                          Icons.lock_rounded,
                                          color: Colors.green,
                                        )
                                      : null,
                                ),
                            items: _status
                                .map(
                                  (status) => DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(_nomeStatus(status)),
                                  ),
                                )
                                .toList(),
                            onChanged: _leadConvertido
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
                      child: Column(
                        children: [
                          _campoLeitura(
                            label: 'Estabelecimento',
                            valor: widget.lead.nmestabelecimento,
                            icone: Icons.storefront_outlined,
                          ),
                          const SizedBox(height: 14),
                          _campoLeitura(
                            label: 'Estado',
                            valor:
                                '${widget.lead.nmestado} - ${widget.lead.sgestado}',
                            icone: Icons.map_outlined,
                          ),
                          const SizedBox(height: 14),
                          _campoLeitura(
                            label: 'Cidade',
                            valor: widget.lead.nmcidade,
                            icone: Icons.location_city_outlined,
                          ),
                          const SizedBox(height: 14),
                          _campoLeitura(
                            label: 'Mensagem enviada',
                            valor: mensagem == null || mensagem.isEmpty
                                ? 'Nenhuma mensagem informada'
                                : mensagem,
                            icone: Icons.message_outlined,
                            maxLines: 4,
                          ),
                          const SizedBox(height: 14),
                          _campoLeitura(
                            label: 'Data do cadastro',
                            valor: _formatarData(widget.lead.dtcriacao),
                            icone: Icons.calendar_today_outlined,
                          ),
                          const SizedBox(height: 14),
                          _campoLeitura(
                            label: 'Última atualização',
                            valor: _formatarData(widget.lead.dtultatu),
                            icone: Icons.update_rounded,
                          ),
                          const SizedBox(height: 14),
                          _campoLeitura(
                            label: 'Tempo desde o cadastro',
                            valor: widget.lead.diasEspera == 1
                                ? '1 dia'
                                : '${widget.lead.diasEspera} dias',
                            icone: Icons.schedule_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
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
      ),
    );
  }
}

class _TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final numeros = newValue.text.replaceAll(RegExp(r'\D'), '');
    String texto;

    if (numeros.length <= 2) {
      texto = numeros;
    } else if (numeros.length <= 6) {
      texto = '(${numeros.substring(0, 2)}) ${numeros.substring(2)}';
    } else if (numeros.length <= 10) {
      texto =
          '(${numeros.substring(0, 2)}) ${numeros.substring(2, 6)}-${numeros.substring(6)}';
    } else {
      texto =
          '(${numeros.substring(0, 2)}) ${numeros.substring(2, 7)}-${numeros.substring(7, 11)}';
    }

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
