import 'package:flutter/material.dart';

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
  bool _carregando = true;
  int? _processandoId;

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
    try {
      final id = await StorageService.getOrganizacaoId();
      if (id == null) throw Exception('Empresa não identificada.');
      final titulares = await _repo.listar(id);
      if (!mounted) return;
      setState(() {
        _organizacaoId = id;
        _titulares = titulares;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
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

  Widget _card(Map<String, dynamic> titular) {
    final id = titular['titularfinanceiro_id'] as int?;
    final possuiAsaas = _texto(titular['asaas_account_id']).isNotEmpty;
    final inativo = _texto(titular['sittitular']).toUpperCase() == 'INATIVO';
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
                  Icons.account_balance_wallet_rounded,
                  color: ClubbarColors.info,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _texto(titular['nmrazaosocial']),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
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
              '${_texto(titular['tipotitular'])} • ${_documento(_texto(titular['cpfcnpj']))}',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
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
                        : 'Sem subconta Asaas',
                  ),
                ),
              ],
            ),
            if (possuiAsaas)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'A subconta Asaas já foi criada; este titular não pode ser inativado.',
                  style: TextStyle(
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
            titulo: 'Titulares financeiros',
            subtitulo: '${_titulares.length} titular(es) da organização',
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
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
