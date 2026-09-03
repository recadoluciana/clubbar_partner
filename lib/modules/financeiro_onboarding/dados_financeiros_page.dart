import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/repositories/localidade_repository.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_localidade_field.dart';
import '../../core/widgets/clubbar_page_header.dart';
import 'titular_financeiro_repository.dart';

class DadosFinanceirosPage extends StatefulWidget {
  final bool mostrarIntegracao;
  const DadosFinanceirosPage({super.key, this.mostrarIntegracao = false});

  @override
  State<DadosFinanceirosPage> createState() => _DadosFinanceirosPageState();
}

class _DadosFinanceirosPageState extends State<DadosFinanceirosPage> {
  final _repo = TitularFinanceiroRepository();
  final _localidadeRepository = LocalidadeRepository();
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _c = {
    for (final nome in [
      'cpfcnpj',
      'nome',
      'fantasia',
      'nascimento',
      'email',
      'telefone',
      'cep',
      'endereco',
      'numero',
      'complemento',
      'bairro',
      'faturamento',
    ])
      nome: TextEditingController(),
  };
  int? _organizacaoId, _estadoId, _cidadeId;
  String _tipo = 'PJ', _status = 'NAO_INICIADO', _onboardingUrl = '';
  String _nomeOrganizacao = 'Empresa';
  bool _carregando = true, _processando = false, _consultandoCep = false;
  String? _ultimoCepConsultado;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    for (final x in _c.values) {
      x.dispose();
    }
    super.dispose();
  }

  String _texto(dynamic v) => v?.toString() ?? '';
  void _preencher(Map<String, dynamic> d) {
    _tipo = _texto(d['tipotitular']).isEmpty ? 'PJ' : _texto(d['tipotitular']);
    _status = _texto(d['status_asaas']).isEmpty
        ? 'NAO_INICIADO'
        : _texto(d['status_asaas']);
    _onboardingUrl = _texto(d['onboarding_url']);
    _estadoId = d['estado_id'] as int?;
    _cidadeId = d['cidade_id'] as int?;
    final mapa = {
      'cpfcnpj': 'cpfcnpj',
      'nome': 'nmrazaosocial',
      'fantasia': 'nmfantasia',
      'nascimento': 'dtnascimento',
      'email': 'email',
      'telefone': 'telefone',
      'cep': 'cep',
      'endereco': 'endereco',
      'numero': 'numero',
      'complemento': 'complemento',
      'bairro': 'bairro',
      'faturamento': 'vrfaturamentomensal',
    };
    for (final e in mapa.entries) {
      _c[e.key]!.text = _texto(d[e.value]);
    }
    _c['nascimento']!.text = _formatarDataExibicao(d['dtnascimento']);
    _c['faturamento']!.text = _formatarMoeda(d['vrfaturamentomensal']);
  }

  Future<void> _carregar() async {
    try {
      final id = await StorageService.getOrganizacaoId();
      if (id == null) throw Exception('Empresa não identificada.');
      final nomeOrganizacao = (await StorageService.getNomeOrganizacao() ?? '')
          .trim();
      final dados = await _repo.consultar(id);
      if (!mounted) return;
      setState(() {
        _organizacaoId = id;
        _nomeOrganizacao = nomeOrganizacao.isEmpty
            ? 'Empresa'
            : nomeOrganizacao;
        _preencher(dados);
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String? _obrigatorio(String? v) =>
      (v ?? '').trim().isEmpty ? 'Campo obrigatório.' : null;

  String _formatarDataExibicao(dynamic valor) {
    final texto = _texto(valor).trim();
    if (texto.isEmpty) return '';
    final data = DateTime.tryParse(texto);
    return data == null ? texto : DateFormat('dd/MM/yyyy').format(data);
  }

  String? _dataNascimentoIso() {
    final texto = _c['nascimento']!.text.trim();
    if (texto.isEmpty) return null;
    try {
      return DateFormat(
        'yyyy-MM-dd',
      ).format(DateFormat('dd/MM/yyyy').parseStrict(texto));
    } catch (_) {
      return null;
    }
  }

  String _formatarMoeda(dynamic valor) {
    final numero = valor is num
        ? valor.toDouble()
        : double.tryParse(_texto(valor).replaceAll(',', '.')) ?? 0;
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(numero);
  }

  Future<void> _selecionarNascimento() async {
    DateTime inicial = DateTime(1990, 1, 1);
    final texto = _c['nascimento']!.text.trim();
    try {
      inicial = DateFormat('dd/MM/yyyy').parseStrict(texto);
    } catch (_) {}
    final selecionada = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
    if (selecionada != null && mounted) {
      setState(() {
        _c['nascimento']!.text = DateFormat('dd/MM/yyyy').format(selecionada);
      });
    }
  }

  Future<void> _buscarCep() async {
    final cep = _c['cep']!.text.replaceAll(RegExp(r'\D'), '');
    if (_consultandoCep || cep.length != 8 || cep == _ultimoCepConsultado) {
      return;
    }

    setState(() => _consultandoCep = true);
    try {
      final endereco = await _localidadeRepository.buscarEnderecoPorCep(cep);
      final estados = await _localidadeRepository.listarEstados();
      final estado = estados
          .where(
            (item) =>
                item.sgestado.trim().toUpperCase() == endereco.uf.toUpperCase(),
          )
          .firstOrNull;
      if (estado == null) {
        throw Exception('O estado retornado pelo CEP não foi encontrado.');
      }

      final cidades = await _localidadeRepository.listarCidadesPorEstado(
        estado.estadoId,
      );
      final cidade = cidades
          .where(
            (item) =>
                (endereco.codigoIbgeCidade != null &&
                    item.cdibgecid == endereco.codigoIbgeCidade) ||
                item.nmcidade.trim().toLowerCase() ==
                    endereco.cidade.trim().toLowerCase(),
          )
          .firstOrNull;
      if (cidade == null) {
        throw Exception('A cidade retornada pelo CEP não foi encontrada.');
      }

      if (!mounted) return;
      setState(() {
        _ultimoCepConsultado = cep;
        _c['cep']!.text = endereco.cep.replaceAll(RegExp(r'\D'), '');
        if (endereco.logradouro.isNotEmpty) {
          _c['endereco']!.text = endereco.logradouro;
        }
        if (endereco.bairro.isNotEmpty) {
          _c['bairro']!.text = endereco.bairro;
        }
        _estadoId = estado.estadoId;
        _cidadeId = cidade.cidadeId;
      });
      AppSnackBar.sucesso(context, 'Endereço carregado pelo CEP.');
    } catch (e) {
      if (!mounted) return;
      _ultimoCepConsultado = null;
      AppSnackBar.erro(
        context,
        e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
      );
    } finally {
      if (mounted) setState(() => _consultandoCep = false);
    }
  }

  Widget _campoCep() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _c['cep'],
      keyboardType: TextInputType.number,
      enabled: !_consultandoCep,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ],
      validator: (valor) {
        final cep = (valor ?? '').replaceAll(RegExp(r'\D'), '');
        if (cep.isEmpty) return 'Campo obrigatório.';
        return cep.length == 8 ? null : 'Informe um CEP válido.';
      },
      onChanged: (valor) {
        if (valor.replaceAll(RegExp(r'\D'), '').length == 8) {
          _buscarCep();
        } else {
          _ultimoCepConsultado = null;
        }
      },
      onFieldSubmitted: (_) => _buscarCep(),
      decoration: InputDecoration(
        labelText: 'CEP',
        filled: true,
        fillColor: Colors.white,
        suffixIcon: _consultandoCep
            ? const Padding(
                padding: EdgeInsets.all(13),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.location_searching_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
  Widget _campo(
    String nome,
    String label, {
    TextInputType? teclado,
    bool opcional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _c[nome],
      keyboardType: teclado,
      validator: opcional ? null : _obrigatorio,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  Widget _campoNascimento() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _c['nascimento'],
      readOnly: true,
      onTap: _selecionarNascimento,
      validator: _obrigatorio,
      decoration: InputDecoration(
        labelText: 'Data de nascimento',
        hintText: 'DD/MM/AAAA',
        filled: true,
        fillColor: Colors.white,
        suffixIcon: const Icon(Icons.calendar_month_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  Widget _campoFaturamento() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _c['faturamento'],
      keyboardType: TextInputType.number,
      inputFormatters: [_MoedaBrasileiraFormatter()],
      validator: _obrigatorio,
      decoration: InputDecoration(
        labelText: 'Faturamento mensal estimado',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  double _valorMoeda(String texto) {
    final normalizado = texto
        .replaceAll(RegExp(r'[^0-9,\-]'), '')
        .replaceAll(',', '.');
    return double.tryParse(normalizado) ?? 0;
  }

  Map<String, dynamic> _dados() => {
    'organizacao_id': _organizacaoId,
    'tipotitular': _tipo,
    'cpfcnpj': _c['cpfcnpj']!.text,
    'nmrazaosocial': _c['nome']!.text,
    'nmfantasia': _c['fantasia']!.text,
    'dtnascimento': _tipo == 'PF' ? _dataNascimentoIso() : null,
    'email': _c['email']!.text,
    'telefone': _c['telefone']!.text,
    'cep': _c['cep']!.text,
    'endereco': _c['endereco']!.text,
    'numero': _c['numero']!.text,
    'complemento': _c['complemento']!.text,
    'bairro': _c['bairro']!.text,
    'cidade_id': _cidadeId,
    'estado_id': _estadoId,
    'vrfaturamentomensal': _valorMoeda(_c['faturamento']!.text),
  };

  Future<void> _executar(
    Future<Map<String, dynamic>> Function() acao,
    String sucesso,
  ) async {
    if (_processando) return;
    setState(() => _processando = true);
    try {
      final d = await acao();
      if (!mounted) return;
      setState(() => _preencher(d));
      AppSnackBar.sucesso(context, sucesso);
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _salvar() async {
    if (!(_form.currentState?.validate() ?? false) ||
        _estadoId == null ||
        _cidadeId == null) {
      AppSnackBar.aviso(context, 'Preencha todos os dados obrigatórios.');
      return;
    }
    await _executar(
      () => _repo.salvar(_organizacaoId!, _dados()),
      'Dados financeiros salvos.',
    );
  }

  Color get _corStatus => _status == 'APROVADO'
      ? Colors.green
      : _status == 'REJEITADO'
      ? Colors.red
      : Colors.orange;

  Widget _integracao() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                size: 52,
                color: ClubbarColors.ambar,
              ),
              const SizedBox(height: 10),
              const Text(
                'Recebimentos pelo Asaas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Chip(
                label: Text(_status.replaceAll('_', ' ')),
                backgroundColor: _corStatus.withValues(alpha: .15),
                labelStyle: TextStyle(
                  color: _corStatus,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Documentos e selfie são enviados diretamente no ambiente seguro do Asaas. O Clubbar não armazena essas imagens.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: _processando
            ? null
            : () => _executar(
                () => _repo.ativar(_organizacaoId!),
                'Subconta criada. Continue o cadastro no Asaas.',
              ),
        icon: const Icon(Icons.account_balance_rounded),
        label: const Text('Ativar recebimentos'),
      ),
      const SizedBox(height: 12),
      if (_onboardingUrl.isNotEmpty)
        ElevatedButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(_onboardingUrl),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Enviar documentos e selfie'),
        ),
      if (_onboardingUrl.isNotEmpty) const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _processando
            ? null
            : () => _executar(
                () => _repo.verificar(_organizacaoId!),
                'Situação atualizada.',
              ),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Verificar situação no Asaas'),
      ),
      const SizedBox(height: 16),
      const Text(
        'As vendas só poderão ser publicadas quando a situação estiver APROVADO.',
        textAlign: TextAlign.center,
        style: TextStyle(color: ClubbarColors.textoSecundario),
      ),
    ],
  );

  Widget _cardSecao({
    required String titulo,
    required IconData icone,
    required List<Widget> children,
  }) => Card(
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: ClubbarColors.borda),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icone, color: ClubbarColors.info),
              const SizedBox(width: 9),
              Text(
                titulo,
                style: const TextStyle(
                  color: ClubbarColors.info,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );

  Widget _formulario() => Form(
    key: _form,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _cardSecao(
          titulo: 'Dados da empresa',
          icone: Icons.business_rounded,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _tipo,
              decoration: const InputDecoration(
                labelText: 'Tipo de titular',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'PF', child: Text('Pessoa física')),
                DropdownMenuItem(value: 'PJ', child: Text('Pessoa jurídica')),
              ],
              onChanged: (v) => setState(() => _tipo = v!),
            ),
            const SizedBox(height: 12),
            _campo(
              'cpfcnpj',
              _tipo == 'PF' ? 'CPF' : 'CNPJ',
              teclado: TextInputType.number,
            ),
            _campo('nome', _tipo == 'PF' ? 'Nome completo' : 'Razão social'),
            _campo('fantasia', 'Nome fantasia', opcional: true),
            if (_tipo == 'PF') _campoNascimento(),
            _campo('email', 'E-mail', teclado: TextInputType.emailAddress),
            _campo('telefone', 'Telefone', teclado: TextInputType.phone),
            _campoFaturamento(),
          ],
        ),
        const SizedBox(height: 16),
        _cardSecao(
          titulo: 'Endereço da empresa',
          icone: Icons.location_on_rounded,
          children: [
            _campoCep(),
            _campo('endereco', 'Endereço cadastral'),
            _campo('numero', 'Número'),
            _campo('complemento', 'Complemento', opcional: true),
            _campo('bairro', 'Bairro'),
            ClubbarLocalidadeField(
              estadoInicialId: _estadoId,
              cidadeInicialId: _cidadeId,
              onChanged: (e, c) {
                _estadoId = e?.estadoId;
                _cidadeId = c?.cidadeId;
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _processando ? null : _salvar,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Salvar dados financeiros'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: Column(
      children: [
        ClubbarPageHeader(
          titulo: widget.mostrarIntegracao
              ? 'Integração Asaas'
              : _nomeOrganizacao,
          subtitulo: widget.mostrarIntegracao
              ? 'Ative e acompanhe seus recebimentos'
              : 'Dados do titular dos recebimentos',
          tituloStyle: widget.mostrarIntegracao
              ? null
              : const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: ClubbarColors.info,
                ),
        ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : (_organizacaoId == null
                    ? const Center(child: Text('Empresa não encontrada.'))
                    : widget.mostrarIntegracao
                    ? _integracao()
                    : _formulario()),
        ),
      ],
    ),
  );
}

class _MoedaBrasileiraFormatter extends TextInputFormatter {
  final NumberFormat _formato = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) return const TextEditingValue(text: '');
    final valor = int.parse(digitos) / 100;
    final texto = _formato.format(valor);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
