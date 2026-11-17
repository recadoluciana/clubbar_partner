import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';
import 'download_csv.dart';

class RelatorioSplitPage extends StatefulWidget {
  const RelatorioSplitPage({super.key});

  @override
  State<RelatorioSplitPage> createState() => _RelatorioSplitPageState();
}

class _RelatorioSplitPageState extends State<RelatorioSplitPage> {
  final _formato = DateFormat('dd/MM/yyyy');
  final _apiData = DateFormat('yyyy-MM-dd');
  late DateTimeRange _periodo;
  String? _comprovante;
  String? _status;
  String? _erro;
  List<Map<String, dynamic>> _itens = [];
  bool _carregando = false;

  static const campos = <String, String>{
    'COLLECTOR': 'ID vendedor',
    'COLLECTOR_NICKNAME': 'Vendedor',
    'PAYMENT': 'Pagamento',
    'STATUS_DESCRIPTION': 'Status',
    'STATUS_DETAIL': 'Detalhe do status',
    'PURCHASE_ORDER': 'Pedido',
    'PAYMENT_METHOD_TYPE': 'Forma de pagamento',
    'TRANSACTION_AMOUNT': 'Valor da venda',
    'DATE_CREATED': 'Data de criação',
    'DATE_APPROVED': 'Data de aprovação',
    'MARKETPLACE_FEE_AMOUNT': 'Taxa Clubbar',
    'MERCADOPAGO_FEE_AMOUNT': 'Taxa Mercado Pago',
    'TOTAL_PAID_AMOUNT': 'Total pago',
    'NET_RECEIVED_AMOUNT': 'Valor líquido',
  };

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _periodo = DateTimeRange(
      start: DateTime(hoje.year, hoje.month, 1),
      end: hoje,
    );
    _restaurar();
  }

  Future<String?> _chave() async {
    final organizacao = await StorageService.getOrganizacaoId();
    return organizacao == null ? null : 'relatorio_split_$organizacao';
  }

  Future<void> _restaurar() async {
    final chave = await _chave();
    if (chave == null) return;
    final prefs = await SharedPreferences.getInstance();
    final salvo = prefs.getString(chave);
    if (salvo == null) return;
    try {
      final dados = jsonDecode(salvo) as Map<String, dynamic>;
      final criado = DateTime.parse(dados['criado'] as String);
      if (DateTime.now().difference(criado) >= const Duration(hours: 23)) {
        await prefs.remove(chave);
        return;
      }
      final periodo = DateTimeRange(
        start: DateTime.parse(dados['inicio'] as String),
        end: DateTime.parse(dados['fim'] as String),
      );
      if (!mounted || _comprovante != null || _carregando) return;
      setState(() {
        _periodo = periodo;
        _comprovante = dados['comprovante'] as String;
        _status = 'processing';
      });
    } catch (_) {
      await prefs.remove(chave);
    }
  }

  Future<void> _salvar() async {
    final chave = await _chave();
    if (chave == null || _comprovante == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      chave,
      jsonEncode({
        'comprovante': _comprovante,
        'inicio': _periodo.start.toIso8601String(),
        'fim': _periodo.end.toIso8601String(),
        'criado': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final resposta = await ApiService.post(endpoint, body);
    final dados = jsonDecode(resposta.body);
    if (resposta.statusCode != 200) {
      throw Exception(
        dados is Map
            ? dados['detail'] ?? 'Não foi possível consultar o relatório.'
            : 'Não foi possível consultar o relatório.',
      );
    }
    return Map<String, dynamic>.from(dados as Map);
  }

  Future<void> _selecionarPeriodo() async {
    final hoje = DateTime.now();
    final escolhido = await showDateRangePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      firstDate: DateTime(2020),
      lastDate: hoje,
      initialDateRange: _periodo,
      helpText: 'Selecione o período do relatório',
      confirmText: 'Aplicar',
      cancelText: 'Cancelar',
    );
    if (escolhido != null && mounted) {
      setState(() {
        _periodo = escolhido;
        _comprovante = null;
        _status = null;
        _itens = [];
        _erro = null;
      });
    }
  }

  Future<void> _gerar() async {
    setState(() {
      _carregando = true;
      _erro = null;
      _comprovante = null;
      _status = null;
      _itens = [];
    });
    try {
      final dados = await _post('/relatorio-split-mercado-pago', {
        'inicio': _apiData.format(_periodo.start),
        'fim': _apiData.format(_periodo.end),
      });
      if (!mounted) return;
      setState(() {
        _comprovante = dados['comprovante'] as String;
        _status = 'processing';
      });
      await _salvar();
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _consultar() async {
    if (_comprovante == null) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final dados = await _post('/relatorio-split-mercado-pago/consultar', {
        'comprovante': _comprovante,
      });
      if (!mounted) return;
      setState(() {
        _status = dados['status']?.toString();
        _itens = (dados['itens'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _csvCampo(Object? valor) {
    var texto = (valor ?? '').toString();
    if (RegExp(r'^\s*[=+@\-]').hasMatch(texto) &&
        !RegExp(r'^-\d+(?:[.,]\d+)?$').hasMatch(texto)) {
      texto = "'$texto";
    }
    return '"${texto.replaceAll('"', '""')}"';
  }

  void _baixar() {
    final buffer = StringBuffer()
      ..writeln(campos.values.map(_csvCampo).join(';'));
    for (final item in _itens) {
      buffer.writeln(
        campos.keys.map((chave) => _csvCampo(item[chave])).join(';'),
      );
    }
    if (!baixarArquivo(
      '\ufeff${buffer.toString()}',
      'relatorio_split_clubbar.csv',
      'text/csv',
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download disponível na versão web.')),
      );
    }
  }

  void _baixarJson() {
    final conteudo = const JsonEncoder.withIndent('  ').convert(_itens);
    if (!baixarArquivo(
      conteudo,
      'relatorio_split_clubbar.json',
      'application/json',
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download disponível na versão web.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: Column(
      children: [
        const ClubbarPageHeader(
          titulo: 'Relatório de vendas com split',
          subtitulo: 'Mercado Pago',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              OutlinedButton.icon(
                onPressed: _carregando ? null : _selecionarPeriodo,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  'Período: ${_formato.format(_periodo.start)} a ${_formato.format(_periodo.end)}',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'O relatório pode levar alguns minutos para ficar pronto. São exibidas apenas transações identificadas nas lojas da sua empresa.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _carregando ? null : _gerar,
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Gerar relatório'),
                  ),
                  if (_comprovante != null)
                    OutlinedButton.icon(
                      onPressed: _carregando ? null : _consultar,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Consultar resultado'),
                    ),
                  if (_status == 'available')
                    OutlinedButton.icon(
                      onPressed: _baixar,
                      icon: const Icon(Icons.download),
                      label: const Text('Baixar CSV'),
                    ),
                  if (_status == 'available')
                    OutlinedButton.icon(
                      onPressed: _baixarJson,
                      icon: const Icon(Icons.download),
                      label: const Text('Baixar JSON'),
                    ),
                ],
              ),
              if (_carregando)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_erro != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _erro!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_status != null && _status != 'available')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _status == 'processing' || _status == 'pending'
                        ? 'Relatório em processamento. Aguarde alguns minutos e consulte o resultado.'
                        : 'Situação informada pelo Mercado Pago: $_status',
                  ),
                ),
              if (_status == 'available') ...[
                const SizedBox(height: 12),
                Text('${_itens.length} transação(ões) identificada(s)'),
                ..._itens.map(
                  (item) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pagamento ${item['PAYMENT'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ...campos.entries
                              .where(
                                (e) =>
                                    e.key != 'PAYMENT' &&
                                    (item[e.key]
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ??
                                        false),
                              )
                              .map((e) => Text('${e.value}: ${item[e.key]}')),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
