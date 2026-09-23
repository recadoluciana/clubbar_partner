import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/api_config.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import 'dados_financeiros_page.dart';
import 'titular_financeiro_repository.dart';

class TitularesFinanceirosPage extends StatefulWidget {
  const TitularesFinanceirosPage({super.key});

  @override
  State<TitularesFinanceirosPage> createState() =>
      _TitularesFinanceirosPageState();
}

class _TitularesFinanceirosPageState extends State<TitularesFinanceirosPage> {
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

  Future<void> _alterarStatus(Map<String, dynamic> titular) async {
    final organizacaoId = _organizacaoId;
    final id = titular['titularfinanceiro_id'] as int?;
    if (organizacaoId == null || id == null || _processandoId != null) return;
    final possuiAsaas = _texto(titular['asaas_account_id']).isNotEmpty;
    if (possuiAsaas) {
      AppSnackBar.aviso(
        context,
        'Titulares com subconta Asaas não podem ser inativados.',
      );
      return;
    }
    final inativo = _texto(titular['sittitular']).toUpperCase() == 'INATIVO';
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
      if (mounted) {
        AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _processandoId = null);
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
              : () => _executarAsaas(
                  titular,
                  (organizacaoId, titularId) => _repo.ativar(
                    organizacaoId,
                    titularFinanceiroId: titularId,
                  ),
                  'Subconta Asaas criada. Verifique a situação para continuar.',
                ),
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
      return Container(
        width: double.infinity,
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
        if (ApiConfig.isDev ||
            ApiConfig.baseUrl.toLowerCase().contains('desenvolvimento'))
          TextButton.icon(
            onPressed: processando
                ? null
                : () => _executarAsaas(
                    titular,
                    (organizacaoId, titularId) => _repo.aprovarSandbox(
                      organizacaoId,
                      titularFinanceiroId: titularId,
                    ),
                    'Subconta aprovada no Sandbox.',
                  ),
            icon: const Icon(Icons.science_rounded),
            label: const Text('Aprovar no Sandbox'),
          ),
      ],
    );
  }

  Widget _card(Map<String, dynamic> titular) {
    final id = titular['titularfinanceiro_id'] as int?;
    final possuiAsaas = _texto(titular['asaas_account_id']).isNotEmpty;
    final inativo = _texto(titular['sittitular']).toUpperCase() == 'INATIVO';
    final asaasAprovado =
        _texto(titular['status_asaas']).toUpperCase() == 'APROVADO';
    final pessoaJuridica = _texto(titular['tipotitular']).toUpperCase() == 'PJ';
    final rotuloDocumento = pessoaJuridica ? 'CNPJ' : 'CPF';
    final statusCor = inativo
        ? ClubbarColors.textoSecundario
        : ClubbarColors.sucesso;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  color: ClubbarColors.info,
                ),
                const SizedBox(width: 10),
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
            const Divider(),
            Text(
              '$rotuloDocumento: ${_documento(_texto(titular['cpfcnpj']))}',
              style: const TextStyle(color: ClubbarColors.textoSecundario),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Situação do titular financeiro: ${inativo ? 'Inativo' : 'Ativo'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
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
              ],
            ),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 4),
            const Row(
              children: [
                Icon(Icons.account_balance_rounded, color: ClubbarColors.info),
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
                    possuiAsaas
                        ? Icons.verified_rounded
                        : Icons.account_balance_outlined,
                    size: 18,
                  ),
                  label: Text(
                    possuiAsaas
                        ? 'Subconta Asaas criada'
                        : 'Subconta Asaas não criada',
                  ),
                ),
                if (possuiAsaas)
                  Chip(
                    label: Text('Situação no Asaas: ${_statusAsaas(titular)}'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _acoesAsaas(titular, possuiAsaas: possuiAsaas, inativo: inativo),
            if (possuiAsaas)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  asaasAprovado
                      ? 'Subconta aprovada pelo Asaas. Este titular não pode ser inativado.\n\nAcesse a tela de Meus estabelecimentos e associe a cada estabelecimento um titular financeiro ativo e aprovado.'
                      : 'Subconta criada, mas os recebimentos serão liberados somente após a aprovação do Asaas. Este titular não pode ser inativado.',
                  style: const TextStyle(
                    color: ClubbarColors.textoSecundario,
                    fontSize: 12,
                  ),
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _processandoId == id
                      ? null
                      : () => _alterarStatus(titular),
                  icon: Icon(
                    inativo ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  ),
                  label: Text(inativo ? 'Reativar' : 'Inativar'),
                ),
              ),
          ],
        ),
      ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _carregando ? null : _adicionar,
        backgroundColor: ClubbarColors.info,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Adicionar titular financeiro'),
      ),
    );
  }
}
