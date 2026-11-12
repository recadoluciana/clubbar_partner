import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/utils/horario_brasil.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_action_bar.dart';
import '../../core/widgets/clubbar_calendar_delegate.dart';
import '../../core/widgets/clubbar_page_header.dart';
import 'dados_financeiros_page.dart';
import 'titular_estabelecimentos_secao.dart';
import 'titular_financeiro_repository.dart';
import 'titular_mercado_pago_secao.dart';

class TitularesFinanceirosPage extends StatefulWidget {
  const TitularesFinanceirosPage({super.key});

  @override
  State<TitularesFinanceirosPage> createState() =>
      _TitularesFinanceirosPageState();
}

class _TitularesFinanceirosPageState extends State<TitularesFinanceirosPage> {
  static const bool _mostrarAsaas = false;
  final _repo = TitularFinanceiroRepository();
  List<Map<String, dynamic>> _titulares = const [];
  int? _organizacaoId;
  String _nomeOrganizacao = 'Organização';
  bool _carregando = true;
  int? _processandoId;
  String? _erroCarregamento;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  String _texto(dynamic valor) => valor?.toString() ?? '';

  double _valorMonetario(dynamic valor) {
    if (valor is num) return valor.toDouble();
    final texto = _texto(valor).trim();
    if (texto.isEmpty) return 0;
    final normalizado = texto.contains(',')
        ? texto.replaceAll('.', '').replaceAll(',', '.')
        : texto;
    return double.tryParse(normalizado.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  }

  String _formatarData(dynamic valor) {
    final data = DateTime.tryParse(_texto(valor));
    return data == null ? '' : DateFormat('dd/MM/yyyy').format(data);
  }

  String _documento(String valor) {
    final d = valor.replaceAll(RegExp(r'\D'), '');
    if (d.length == 11) {
      return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
    }
    if (d.length == 14) {
      return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12)}';
    }
    return valor;
  }

  Future<void> _carregar() async {
    if (mounted) {
      setState(() {
        _carregando = true;
        _erroCarregamento = null;
      });
    }
    try {
      final id = await StorageService.getOrganizacaoId();
      if (id == null) throw Exception('Empresa não identificada.');
      final resultados = await Future.wait([
        _repo.listar(id),
        StorageService.getNomeOrganizacao(),
      ]);
      final titulares = resultados[0] as List<Map<String, dynamic>>;
      final nomeOrganizacao = resultados[1]?.toString().trim();
      if (!mounted) return;
      setState(() {
        _organizacaoId = id;
        _titulares = titulares;
        _nomeOrganizacao = nomeOrganizacao?.isNotEmpty == true
            ? nomeOrganizacao!
            : 'Organização';
        _carregando = false;
        _erroCarregamento = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erroCarregamento = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _editar(Map<String, dynamic> titular) async {
    final id = titular['titularfinanceiro_id'] as int?;
    if (id == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DadosFinanceirosPage(titularFinanceiroInicialId: id),
      ),
    );
    if (mounted) {
      setState(() => _carregando = true);
      await _carregar();
    }
  }

  // Mantido para preservar o fluxo existente; a alteração de status agora é feita pelo badge.
  // ignore: unused_element
  Future<void> _alterarStatus(Map<String, dynamic> titular) async {
    final organizacaoId = _organizacaoId;
    final id = titular['titularfinanceiro_id'] as int?;
    if (organizacaoId == null || id == null || _processandoId != null) return;
    final possuiAsaas = _texto(titular['asaas_account_id']).isNotEmpty;
    final inativo = _texto(titular['sittitular']).toUpperCase() == 'INATIVO';
    if (possuiAsaas && !inativo) {
      AppSnackBar.aviso(
        context,
        'Titulares com subconta Asaas não podem ser inativados.',
      );
      return;
    }
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(inativo ? 'Reativar titular?' : 'Inativar titular?'),
        content: Text(
          inativo
              ? 'Este titular poderá voltar a ser escolhido nas lojas.'
              : 'Ele deixará de aparecer como opção para novas lojas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(inativo ? 'Reativar' : 'Inativar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _processandoId = id);
    try {
      final atualizado = inativo
          ? await _repo.reativar(organizacaoId, titularFinanceiroId: id)
          : await _repo.inativar(organizacaoId, titularFinanceiroId: id);
      setState(() {
        _titulares = _titulares
            .map(
              (item) => item['titularfinanceiro_id'] == id ? atualizado : item,
            )
            .toList(growable: false);
      });
      if (mounted) {
        AppSnackBar.sucesso(
          context,
          inativo ? 'Titular reativado.' : 'Titular inativado.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _processandoId = null);
    }
  }

  Future<void> _executarAsaas(
    Map<String, dynamic> titular,
    Future<Map<String, dynamic>> Function(int organizacaoId, int titularId)
    acao,
    String mensagem,
  ) async {
    final organizacaoId = _organizacaoId;
    final id = titular['titularfinanceiro_id'] as int?;
    if (organizacaoId == null || id == null || _processandoId != null) return;
    setState(() => _processandoId = id);
    try {
      final atualizado = await acao(organizacaoId, id);
      if (!mounted) return;
      setState(() {
        _titulares = _titulares
            .map(
              (item) => item['titularfinanceiro_id'] == id ? atualizado : item,
            )
            .toList(growable: false);
      });
      AppSnackBar.sucesso(context, mensagem);
    } catch (e) {
      await _mostrarErroAtivacaoAsaas(e);
    } finally {
      if (mounted) setState(() => _processandoId = null);
    }
  }

  Future<void> _mostrarErroAtivacaoAsaas(Object erro) async {
    if (!mounted) return;
    final mensagem = erro.toString().replaceFirst('Exception: ', '').trim();
    final mensagemNormalizada = mensagem.toLowerCase();
    final falhaAoVincularSubconta =
        mensagemNormalizada.contains('subconta já existe no asaas') &&
        mensagemNormalizada.contains('chave');

    if (!falhaAoVincularSubconta) {
      AppSnackBar.erro(
        context,
        mensagem,
        duration: const Duration(seconds: 15),
        mostrarFechar: true,
      );
      return;
    }

    final detalhe = mensagem.contains('Detalhe do Asaas:')
        ? mensagem.split('Detalhe do Asaas:').last.trim()
        : '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key_off_rounded, color: ClubbarColors.erro),
            SizedBox(width: 10),
            Expanded(child: Text('Não foi possível vincular a subconta')),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A subconta já existe no Asaas, mas o Asaas bloqueou a criação da chave de acesso que permite ao Clubbar vinculá-la.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Para resolver no Asaas:',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  '1. Acesse as configurações da conta principal no Asaas.',
                ),
                const Text(
                  '2. Habilite o gerenciamento de chaves de API das contas filhas/subcontas.',
                ),
                const Text(
                  '3. Se houver restrição de IP, libere temporariamente o acesso da API Clubbar.',
                ),
                const Text(
                  '4. Volte ao Clubbar e clique novamente em “Ativar subconta Asaas”.',
                ),
                if (detalhe.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Detalhe informado pelo Asaas:',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(detalhe),
                ],
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _ativarSubcontaAsaas(Map<String, dynamic> titular) async {
    final pessoaFisica = _texto(titular['tipotitular']).toUpperCase() == 'PF';
    final nascimentoInformado = _texto(
      titular['dtnascimento'],
    ).trim().isNotEmpty;
    final rendaInformada = _valorMonetario(titular['vrfaturamentomensal']) > 0;
    if ((pessoaFisica && !nascimentoInformado) || !rendaInformada) {
      final dados = await _solicitarDadosAtivacaoAsaas(
        titular,
        pessoaFisica: pessoaFisica,
      );
      if (dados == null || !mounted) return;
      final organizacaoId = _organizacaoId;
      final titularId = titular['titularfinanceiro_id'] as int?;
      if (organizacaoId == null || titularId == null) return;
      try {
        final atualizado = await _repo.salvarDadosAtivacaoAsaas(
          organizacaoId,
          titularFinanceiroId: titularId,
          dataNascimento: dados.dataNascimento,
          faturamentoMensal: dados.rendaMensal,
        );
        if (mounted) {
          AppSnackBar.info(
            context,
            'Dados salvos. Ativando a subconta Asaas...',
          );
        }
        await _executarAsaasComTitular(atualizado);
      } catch (e) {
        await _mostrarErroAtivacaoAsaas(e);
      } finally {
        if (mounted) setState(() => _processandoId = null);
      }
      return;
    }
    await _executarAsaasComTitular(titular);
  }

  Future<void> _executarAsaasComTitular(Map<String, dynamic> titular) =>
      _executarAsaas(
        titular,
        (organizacaoId, titularId) =>
            _repo.ativar(organizacaoId, titularFinanceiroId: titularId),
        'Subconta Asaas criada. Verifique a situação para continuar.',
      );

  Future<_DadosAtivacaoAsaas?> _solicitarDadosAtivacaoAsaas(
    Map<String, dynamic> titular, {
    required bool pessoaFisica,
  }) async {
    DateTime? nascimento = DateTime.tryParse(_texto(titular['dtnascimento']));
    final nascimentoController = TextEditingController(
      text: _formatarData(titular['dtnascimento']),
    );
    final renda = TextEditingController(
      text: _valorMonetario(titular['vrfaturamentomensal']) > 0
          ? _valorMonetario(titular['vrfaturamentomensal']).toStringAsFixed(2)
          : '',
    );
    final formulario = GlobalKey<FormState>();
    try {
      return await showDialog<_DadosAtivacaoAsaas>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, atualizarDialogo) => AlertDialog(
            title: const Text('Dados necessários para ativar a subconta'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formulario,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pessoaFisica
                          ? 'Como este titular financeiro é uma pessoa física, informe a data de nascimento e a renda mensal estimada antes de ativar a subconta Asaas.'
                          : 'Informe o faturamento mensal estimado antes de ativar a subconta Asaas.',
                    ),
                    const SizedBox(height: 16),
                    if (pessoaFisica) ...[
                      TextFormField(
                        readOnly: true,
                        controller: nascimentoController,
                        onTap: () async {
                          final selecionada = await showDatePicker(
                            context: dialogContext,
                            initialDate: nascimento ?? DateTime(1990, 1, 1),
                            firstDate: DateTime(1900),
                            lastDate: HorarioBrasil.agora(),
                            calendarDelegate: const ClubbarCalendarDelegate(),
                            helpText: 'Data de nascimento',
                            cancelText: 'Cancelar',
                            confirmText: 'Confirmar',
                          );
                          if (selecionada != null) {
                            atualizarDialogo(() {
                              nascimento = selecionada;
                              nascimentoController.text = DateFormat(
                                'dd/MM/yyyy',
                              ).format(selecionada);
                            });
                          }
                        },
                        validator: (_) => nascimento == null
                            ? 'Informe a data de nascimento.'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Data de nascimento',
                          hintText: 'DD/MM/AAAA',
                          suffixIcon: Icon(Icons.calendar_month_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: renda,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (valor) => _valorMonetario(valor) <= 0
                          ? 'Informe uma renda mensal estimada maior que R\$ 0,00.'
                          : null,
                      decoration: InputDecoration(
                        labelText: pessoaFisica
                            ? 'Renda mensal estimada'
                            : 'Faturamento mensal estimado',
                        prefixText: 'R\$ ',
                        helperText: 'Informe uma estimativa real do titular.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  if (!(formulario.currentState?.validate() ?? false)) return;
                  Navigator.pop(
                    dialogContext,
                    _DadosAtivacaoAsaas(
                      dataNascimento: pessoaFisica
                          ? DateFormat('yyyy-MM-dd').format(nascimento!)
                          : null,
                      rendaMensal: _valorMonetario(renda.text),
                    ),
                  );
                },
                child: const Text('Salvar e ativar'),
              ),
            ],
          ),
        ),
      );
    } finally {
      renda.dispose();
      nascimentoController.dispose();
    }
  }

  Future<void> _abrirOnboarding(Map<String, dynamic> titular) async {
    final url = _texto(titular['onboarding_url']).trim();
    if (url.isEmpty) return;
    final abriu = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!abriu && mounted) {
      AppSnackBar.erro(context, 'Não foi possível abrir o ambiente do Asaas.');
    }
  }

  String _statusAsaas(Map<String, dynamic> titular) {
    final status = _texto(titular['status_asaas']).trim().toUpperCase();
    return const {
          'APROVADO': 'Aprovado',
          'EM_ONBOARDING': 'Cadastro iniciado',
          'EM_ANALISE': 'Em análise',
          'PENDENTE_DOCUMENTOS': 'Documentos pendentes',
          'REJEITADO': 'Rejeitado',
          'NAO_INICIADO': 'Não iniciado',
        }[status] ??
        (status.isEmpty ? 'Não iniciado' : status.replaceAll('_', ' '));
  }

  Widget _acoesAsaas(
    Map<String, dynamic> titular, {
    required bool possuiAsaas,
    required bool inativo,
  }) {
    final id = titular['titularfinanceiro_id'] as int?;
    final processando = _processandoId == id;
    final status = _texto(titular['status_asaas']).toUpperCase();
    final aprovado = status == 'APROVADO';
    final onboardingUrl = _texto(titular['onboarding_url']).trim();

    if (!possuiAsaas) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: processando || inativo
              ? null
              : () => _ativarSubcontaAsaas(titular),
          icon: const Icon(Icons.account_balance_rounded),
          label: Text(
            inativo
                ? 'Reative o titular para ativar a subconta Asaas'
                : 'Ativar subconta Asaas',
          ),
        ),
      );
    }

    if (aprovado) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: ClubbarColors.sucessoClaro,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ClubbarColors.sucesso),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_rounded, color: ClubbarColors.sucesso),
                SizedBox(width: 8),
                Text(
                  'Subconta pronta para receber pagamentos',
                  style: TextStyle(
                    color: ClubbarColors.sucesso,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (onboardingUrl.isNotEmpty)
          ElevatedButton.icon(
            onPressed: processando ? null : () => _abrirOnboarding(titular),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Enviar documentos'),
          ),
        OutlinedButton.icon(
          onPressed: processando
              ? null
              : () => _executarAsaas(
                  titular,
                  (organizacaoId, titularId) => _repo.verificar(
                    organizacaoId,
                    titularFinanceiroId: titularId,
                  ),
                  'Situação atualizada com o Asaas.',
                ),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Verificar situação'),
        ),
      ],
    );
  }

  Widget _card(Map<String, dynamic> titular) {
    final id = titular['titularfinanceiro_id'] as int?;
    final inativo = _texto(titular['sittitular']).toUpperCase() == 'INATIVO';
    final pessoaJuridica = _texto(titular['tipotitular']).toUpperCase() == 'PJ';
    final rotuloDocumento = pessoaJuridica ? 'CNPJ' : 'CPF';
    final statusCor = inativo
        ? ClubbarColors.textoSecundario
        : ClubbarColors.sucesso;
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: ClubbarColors.info.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: ClubbarColors.info,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nome do titular financeiro',
                        style: TextStyle(
                          fontSize: 12,
                          color: ClubbarColors.textoSecundario,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _texto(titular['nmrazaosocial']),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$rotuloDocumento: ${_documento(_texto(titular['cpfcnpj']))}',
                        style: const TextStyle(
                          color: ClubbarColors.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar titular financeiro',
                  onPressed: _processandoId == id
                      ? null
                      : () => _editar(titular),
                  color: ClubbarColors.info,
                  icon: const Icon(Icons.edit_rounded),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Chip(
                avatar: Icon(
                  inativo
                      ? Icons.pause_circle_outline
                      : Icons.check_circle_outline,
                  size: 18,
                  color: statusCor,
                ),
                label: Text(inativo ? 'Inativo' : 'Ativo'),
                labelStyle: TextStyle(
                  color: statusCor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (_mostrarAsaas) ...[
              const Divider(),
              const SizedBox(height: 4),
              const Row(
                children: [
                  Icon(
                    Icons.account_balance_rounded,
                    color: ClubbarColors.info,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Subconta Asaas',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: Icon(
                      _texto(titular['asaas_account_id']).isNotEmpty
                          ? Icons.verified_rounded
                          : Icons.account_balance_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _texto(titular['asaas_account_id']).isNotEmpty
                          ? 'Subconta Asaas criada'
                          : 'Subconta Asaas não criada',
                    ),
                  ),
                  if (_texto(titular['asaas_account_id']).isNotEmpty)
                    Chip(
                      label: Text(
                        'Situação no Asaas: ${_statusAsaas(titular)}',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _acoesAsaas(
                titular,
                possuiAsaas: _texto(titular['asaas_account_id']).isNotEmpty,
                inativo: inativo,
              ),
            ],
            if (id != null && _organizacaoId != null) ...[
              const SizedBox(height: 12),
              _bloco(
                cor: const Color(0xFFEAF3FF),
                child: TitularMercadoPagoSecao(
                  key: ValueKey(id),
                  organizacaoId: _organizacaoId!,
                  titularId: id,
                  nome: _texto(titular['nmrazaosocial']),
                  habilitado: !inativo,
                ),
              ),
              const SizedBox(height: 12),
              _bloco(
                cor: const Color(0xFFEDF9F0),
                child: TitularEstabelecimentosSecao(
                  key: ValueKey('estabelecimentos-$id'),
                  organizacaoId: _organizacaoId!,
                  titularId: id,
                  habilitado: !inativo,
                  onAlterado: _carregar,
                ),
              ),
            ],
            if (_mostrarAsaas && _texto(titular['asaas_account_id']).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _texto(titular['status_asaas']).toUpperCase() == 'APROVADO'
                      ? 'Subconta aprovada pelo Asaas. Este titular não pode ser inativado.'
                      : 'Subconta criada, mas os recebimentos serão liberados somente após a aprovação do Asaas. Este titular não pode ser inativado.',
                  style: const TextStyle(
                    color: ClubbarColors.textoSecundario,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bloco({required Color cor, required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withValues(alpha: .9), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Future<void> _adicionar() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const DadosFinanceirosPage(novoTitular: true),
      ),
    );
    if (mounted) {
      setState(() => _carregando = true);
      await _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: _nomeOrganizacao,
            tituloStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.blue,
            ),
            subtitulo: _erroCarregamento == null
                ? '${_titulares.length} titular(es) financeiro(s) da organização'
                : 'Consulta indisponível no momento',
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _erroCarregamento != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 42,
                            color: ClubbarColors.aviso,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Não foi possível carregar os titulares financeiros.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _erroCarregamento!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ClubbarColors.textoSecundario,
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _carregar,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _titulares.isEmpty
                ? const Center(
                    child: Text('Nenhum titular financeiro cadastrado.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _titulares.length,
                    itemBuilder: (_, index) => _card(_titulares[index]),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: ClubbarActionBar(
        actions: [
          ClubbarAddButton(
            onPressed: _carregando ? null : _adicionar,
            label: 'Adicionar titular financeiro',
          ),
        ],
      ),
    );
  }
}

class _DadosAtivacaoAsaas {
  final String? dataNascimento;
  final double rendaMensal;

  const _DadosAtivacaoAsaas({
    required this.dataNascimento,
    required this.rendaMensal,
  });
}
