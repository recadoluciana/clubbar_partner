import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import 'extrato_asaas_repository.dart';

class ExtratoAsaasPage extends StatefulWidget {
  const ExtratoAsaasPage({super.key});

  @override
  State<ExtratoAsaasPage> createState() => _ExtratoAsaasPageState();
}

class _ExtratoAsaasPageState extends State<ExtratoAsaasPage> {
  final _repo = ExtratoAsaasRepository();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _data = DateFormat('dd/MM/yyyy');
  DateTime _inicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _fim = DateTime.now();
  Map<String, dynamic> _dados = {};
  String _empresa = 'Empresa';
  bool _carregando = true;

  @override
  void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final id = await StorageService.getOrganizacaoId();
      if (id == null) throw Exception('Organização não identificada.');
      final resultado = await _repo.consultar(id, inicio: _inicio, fim: _fim);
      final empresa = (await StorageService.getNomeOrganizacao() ?? '').trim();
      if (mounted) setState(() { _dados = resultado; _empresa = empresa.isEmpty ? 'Empresa' : empresa; });
    } catch (e) {
      if (mounted) AppSnackBar.erro(context, e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => _carregando = false); }
  }

  Future<void> _selecionarPeriodo() async {
    final intervalo = await showDateRangePicker(
      context: context, firstDate: DateTime(2020), lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _inicio, end: _fim),
      locale: const Locale('pt', 'BR'),
    );
    if (intervalo != null) { _inicio = intervalo.start; _fim = intervalo.end; await _carregar(); }
  }

  double _numero(Object? valor) => valor is num ? valor.toDouble() : double.tryParse('$valor') ?? 0;

  @override
  Widget build(BuildContext context) {
    final itens = (_dados['transacoes'] as List? ?? const []).cast<Map>();
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: Column(children: [
        ClubbarPageHeader(
          titulo: _empresa,
          subtitulo: 'Extrato de transações Asaas',
          tituloStyle: const TextStyle(color: ClubbarColors.info, fontSize: 19, fontWeight: FontWeight.w900),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(tooltip: 'Alterar período', onPressed: _selecionarPeriodo, icon: const Icon(Icons.date_range_rounded)),
            IconButton(tooltip: 'Atualizar', onPressed: _carregar, icon: const Icon(Icons.refresh_rounded)),
          ]),
        ),
        Expanded(child: _carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _carregar, child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(color: ClubbarColors.infoClaro, child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const CircleAvatar(backgroundColor: ClubbarColors.info, child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Saldo disponível no Asaas'),
                      Text(_moeda.format(_numero(_dados['saldo'])), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: ClubbarColors.info)),
                      Text('${_data.format(_inicio)} a ${_data.format(_fim)}', style: const TextStyle(color: ClubbarColors.textoSecundario)),
                    ])),
                  ]),
                )),
                const SizedBox(height: 10),
                if (itens.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Nenhuma transação no período.')))),
                ...itens.map((item) {
                  final valor = _numero(item['valor']);
                  final positivo = valor >= 0;
                  final data = DateTime.tryParse(item['data']?.toString() ?? '');
                  return Card(child: ListTile(
                    leading: CircleAvatar(backgroundColor: (positivo ? Colors.green : Colors.red).withValues(alpha: .12), child: Icon(positivo ? Icons.south_west_rounded : Icons.north_east_rounded, color: positivo ? Colors.green : Colors.red)),
                    title: Text(item['descricao']?.toString().trim().isNotEmpty == true ? item['descricao'].toString() : item['tipo']?.toString() ?? 'Transação', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(data == null ? 'Data não informada' : _data.format(data)),
                    trailing: Text(_moeda.format(valor), style: TextStyle(fontWeight: FontWeight.w900, color: positivo ? Colors.green.shade700 : Colors.red.shade700)),
                  ));
                }),
              ],
            )),
        ),
      ]),
    );
  }
}
