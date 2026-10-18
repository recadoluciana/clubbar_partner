import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/reconciliacao_cancelamentos_repository.dart';
import '../../core/utils/horario_brasil.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';

class ReconciliacaoCancelamentosPage extends StatefulWidget {
  const ReconciliacaoCancelamentosPage({super.key});

  @override
  State<ReconciliacaoCancelamentosPage> createState() =>
      _ReconciliacaoCancelamentosPageState();
}

class _ReconciliacaoCancelamentosPageState
    extends State<ReconciliacaoCancelamentosPage> {
  final _repository = ReconciliacaoCancelamentosRepository();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _data = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  List<Map<String, dynamic>> _vendas = const [];
  final Map<int, Map<String, dynamic>> _consultas = {};
  bool _carregando = true;
  int? _processandoVenda;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final vendas = await _repository.listar();
      if (!mounted) return;
      setState(() {
        _vendas = vendas;
        _consultas.clear();
        _carregando = false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = erro.toString().replaceFirst('Exception: ', '');
        _carregando = false;
      });
    }
  }

  int _inteiro(dynamic valor) =>
      valor is int ? valor : int.tryParse('$valor') ?? 0;

  double _numero(dynamic valor) =>
      valor is num ? valor.toDouble() : double.tryParse('$valor') ?? 0;

  DateTime? _dataHora(dynamic valor) {
    if (valor == null) return null;
    return HorarioBrasil.deTextoBrasil(valor);
  }

  Future<void> _consultar(Map<String, dynamic> venda) async {
    final vendaId = _inteiro(venda['venda_id']);
    setState(() => _processandoVenda = vendaId);
    try {
      final consulta = await _repository.consultarAsaas(vendaId);
      if (!mounted) return;
      setState(() => _consultas[vendaId] = consulta);
      final localizado = consulta['estorno_localizado'] == true;
      AppSnackBar.sucesso(
        context,
        localizado
            ? 'Estorno integral localizado no Asaas.'
            : 'Nenhum estorno integral foi localizado no Asaas.',
      );
    } catch (erro) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _processandoVenda = null);
    }
  }

  Future<bool> _confirmar({
    required String titulo,
    required String mensagem,
    required String acao,
    required Color cor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(titulo),
            content: Text(mensagem),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Voltar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cor,
                  foregroundColor: Colors.white,
                ),
                child: Text(acao),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _resolver(
    Map<String, dynamic> venda, {
    required bool concluir,
  }) async {
    final vendaId = _inteiro(venda['venda_id']);
    final confirmou = await _confirmar(
      titulo: concluir ? 'Concluir cancelamento?' : 'Reativar itens?',
      mensagem: concluir
          ? 'O sistema consultará novamente o Asaas e só concluirá se o estorno integral estiver registrado.'
          : 'O sistema consultará novamente o Asaas e só reativará se não houver estorno registrado.',
      acao: concluir ? 'Concluir' : 'Reativar',
      cor: concluir ? ClubbarColors.primaria : ClubbarColors.erro,
    );
    if (!confirmou || !mounted) return;

    setState(() => _processandoVenda = vendaId);
    try {
      final mensagem = concluir
          ? await _repository.concluir(vendaId)
          : await _repository.reativar(vendaId);
      if (!mounted) return;
      AppSnackBar.sucesso(context, mensagem);
      await _carregar();
    } catch (erro) {
      if (mounted) {
        AppSnackBar.erro(
          context,
          erro.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _processandoVenda = null);
    }
  }

  Widget _estado() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(color: ClubbarColors.primaria),
      );
    }
    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 10),
              Text(_erro!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _carregar,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (_vendas.isEmpty) {
      return RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            SizedBox(height: 100),
            Icon(
              Icons.verified_outlined,
              size: 52,
              color: ClubbarColors.primaria,
            ),
            SizedBox(height: 12),
            Center(
              child: Text(
                'Nenhum cancelamento aguardando reconciliação.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Solicitações em processamento',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Confirme o estorno no Asaas antes de concluir o cancelamento ou reativar a compra.',
            style: TextStyle(color: ClubbarColors.textoSecundario),
          ),
          const SizedBox(height: 12),
          ..._vendas.map(_cardVenda),
        ],
      ),
    );
  }

  Widget _cardVenda(Map<String, dynamic> venda) {
    final vendaId = _inteiro(venda['venda_id']);
    final consulta = _consultas[vendaId];
    final estornoLocalizado = consulta?['estorno_localizado'] == true;
    final processando = _processandoVenda == vendaId;
    final data = _dataHora(venda['data_venda']);
    final tipos = (venda['tipos_itens'] as List? ?? const []).join(' e ');

    return ClubbarCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pending_actions_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Venda #$vendaId',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _moeda.format(_numero(venda['valor_esperado'])),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: ClubbarColors.erro,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(venda['loja']?.toString() ?? 'Estabelecimento'),
          Text(
            venda['cliente']?.toString() ?? 'Cliente não identificado',
            style: const TextStyle(color: ClubbarColors.textoSecundario),
          ),
          const SizedBox(height: 6),
          Text(
            '${_inteiro(venda['quantidade_itens'])} ${tipos.isEmpty ? 'itens' : tipos.toLowerCase()} • ${data == null ? 'Data indisponível' : _data.format(data)}',
            style: const TextStyle(
              fontSize: 12,
              color: ClubbarColors.textoSecundario,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color:
                  (consulta == null
                          ? Colors.orange
                          : estornoLocalizado
                          ? ClubbarColors.primaria
                          : ClubbarColors.erro)
                      .withValues(alpha: .10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              consulta == null
                  ? 'Aguardando consulta ao Asaas'
                  : estornoLocalizado
                  ? 'Estorno localizado: ${_moeda.format(_numero(consulta['valor_estornado']))}'
                  : 'Estorno integral ainda não localizado no Asaas',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: consulta == null
                    ? Colors.orange.shade800
                    : estornoLocalizado
                    ? ClubbarColors.primariaEscuro
                    : ClubbarColors.erro,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (processando)
            const Center(child: CircularProgressIndicator())
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _consultar(venda),
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Consultar Asaas'),
                ),
                if (consulta != null)
                  ElevatedButton.icon(
                    onPressed: () =>
                        _resolver(venda, concluir: estornoLocalizado),
                    icon: Icon(
                      estornoLocalizado
                          ? Icons.check_circle_outline_rounded
                          : Icons.undo_rounded,
                    ),
                    label: Text(
                      estornoLocalizado
                          ? 'Concluir cancelamento'
                          : 'Reativar itens',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: estornoLocalizado
                          ? ClubbarColors.primaria
                          : ClubbarColors.erro,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: SafeArea(
      child: Column(
        children: [
          ClubbarPageHeader(
            titulo: 'Cancelamentos em processamento',
            subtitulo: 'Reconcilie estornos do Asaas com segurança',
            trailing: IconButton(
              onPressed: _carregando ? null : _carregar,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Atualizar',
            ),
          ),
          Expanded(child: _estado()),
        ],
      ),
    ),
  );
}
