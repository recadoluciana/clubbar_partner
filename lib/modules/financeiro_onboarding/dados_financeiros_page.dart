import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _carregando = true, _processando = false;

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
  }

  Future<void> _carregar() async {
    try {
      final id = await StorageService.getOrganizacaoId();
      if (id == null) throw Exception('Organização não identificada.');
      final dados = await _repo.consultar(id);
      if (!mounted) return;
      setState(() {
        _organizacaoId = id;
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

  Map<String, dynamic> _dados() => {
    'organizacao_id': _organizacaoId,
    'tipotitular': _tipo,
    'cpfcnpj': _c['cpfcnpj']!.text,
    'nmrazaosocial': _c['nome']!.text,
    'nmfantasia': _c['fantasia']!.text,
    'dtnascimento': _tipo == 'PF' ? _c['nascimento']!.text : null,
    'email': _c['email']!.text,
    'telefone': _c['telefone']!.text,
    'cep': _c['cep']!.text,
    'endereco': _c['endereco']!.text,
    'numero': _c['numero']!.text,
    'complemento': _c['complemento']!.text,
    'bairro': _c['bairro']!.text,
    'cidade_id': _cidadeId,
    'estado_id': _estadoId,
    'vrfaturamentomensal':
        double.tryParse(
          _c['faturamento']!.text.replaceAll('.', '').replaceAll(',', '.'),
        ) ??
        0,
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

  Widget _formulario() => Form(
    key: _form,
    child: ListView(
      padding: const EdgeInsets.all(16),
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
        if (_tipo == 'PF')
          _campo(
            'nascimento',
            'Data de nascimento (AAAA-MM-DD)',
            teclado: TextInputType.datetime,
          ),
        _campo('email', 'E-mail', teclado: TextInputType.emailAddress),
        _campo('telefone', 'Telefone', teclado: TextInputType.phone),
        _campo(
          'faturamento',
          'Faturamento mensal estimado',
          teclado: const TextInputType.numberWithOptions(decimal: true),
        ),
        _campo('cep', 'CEP', teclado: TextInputType.number),
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
              : 'Dados financeiros',
          subtitulo: widget.mostrarIntegracao
              ? 'Ative e acompanhe seus recebimentos'
              : 'Dados do titular dos recebimentos',
        ),
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : (_organizacaoId == null
                    ? const Center(child: Text('Organização não encontrada.'))
                    : widget.mostrarIntegracao
                    ? _integracao()
                    : _formulario()),
        ),
      ],
    ),
  );
}
