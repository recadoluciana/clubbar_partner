import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/loja_repository.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/loja.dart';

class ExtratoMercadoPagoPage extends StatefulWidget {
  const ExtratoMercadoPagoPage({super.key});

  @override
  State<ExtratoMercadoPagoPage> createState() => _ExtratoMercadoPagoPageState();
}

class _ExtratoMercadoPagoPageState extends State<ExtratoMercadoPagoPage> {
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
  final _data = DateFormat('dd/MM/yyyy HH:mm');
  List<Loja> _lojas = [];
  List<dynamic> _pagamentos = [];
  int? _lojaId;
  int? _organizacaoId;
  int _offset = 0;
  bool _mais = false;
  bool _carregando = true;
  bool _selecionandoLoja = false;
  String? _erro;
  late DateTime _inicio;
  late DateTime _fim;

  String _status(dynamic valor) => switch (valor?.toString()) {
    'approved' => 'Aprovado',
    'pending' => 'Pendente',
    'in_process' => 'Em processamento',
    'refunded' => 'Reembolsado',
    'charged_back' => 'Contestação',
    'cancelled' => 'Cancelado',
    'rejected' => 'Recusado',
    _ => 'Status: ${valor ?? 'indisponível'}',
  };

  String _descricaoLancamento(Map<String, dynamic> item) {
    final nomeCliente = item['nome_cliente']?.toString().trim() ?? '';
    if (nomeCliente.isNotEmpty) return nomeCliente;

    final descricao = item['descricao']?.toString() ?? 'Pagamento';
    return descricao.replaceFirst(
      RegExp(r'\s-\s\d{2}/\d{2}/\d{4}\s\d{2}:\d{2}$'),
      '',
    );
  }

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _inicio = DateTime(agora.year, agora.month, 1);
    _fim = agora;
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      _organizacaoId = await StorageService.getOrganizacaoId();
      if (_organizacaoId == null) throw Exception('Empresa não identificada.');
      _lojas = await LojaRepository().listar(_organizacaoId!);
      final salva = await StorageService.getLojaId();
      _lojaId = _lojas.any((loja) => loja.lojaId == salva)
          ? salva
          : _lojas.firstOrNull?.lojaId;
      if (_lojaId == null) {
        throw Exception('Nenhum estabelecimento disponível.');
      }
      if (_lojas.length > 1) {
        if (mounted) {
          setState(() {
            _selecionandoLoja = true;
            _carregando = false;
          });
        }
      } else {
        await _carregar();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString().replaceFirst('Exception: ', '');
          _carregando = false;
        });
      }
    }
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final data = DateFormat('yyyy-MM-dd');
      final uri = Uri(
        path:
            '/titular-financeiro/organizacao/$_organizacaoId/extrato-mercado-pago',
        queryParameters: {
          'loja_id': '$_lojaId',
          'data_inicio': data.format(_inicio),
          'data_fim': data.format(_fim),
          'offset': '$_offset',
        },
      );
      final resposta = await ApiService.get(uri.toString());
      final dados = jsonDecode(resposta.body) as Map<String, dynamic>;
      if (resposta.statusCode != 200) {
        throw Exception(
          dados['detail'] ?? 'Não foi possível consultar o Mercado Pago.',
        );
      }
      if (mounted) {
        setState(() {
          _pagamentos = dados['pagamentos'] as List? ?? [];
          _mais = dados['possui_mais'] == true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pagamentos = [];
          _mais = false;
          _erro = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _selecionarLoja(int lojaId) async {
    setState(() {
      _lojaId = lojaId;
      _offset = 0;
      _selecionandoLoja = false;
    });
    await _carregar();
  }

  Future<void> _periodo() async {
    final intervalo = await showDateRangePicker(
      context: context,
      firstDate: DateTime(
        DateTime.now().year - 1,
        DateTime.now().month,
        DateTime.now().day,
      ),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _inicio, end: _fim),
    );
    if (intervalo == null || !mounted) return;
    _inicio = intervalo.start;
    _fim = intervalo.end;
    _offset = 0;
    await _carregar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          ClubbarPageHeader(
            titulo: 'Extrato Mercado Pago',
            subtitulo: 'Pagamentos da conta conectada',
            trailing: IconButton(
              onPressed: _periodo,
              icon: const Icon(Icons.date_range),
              tooltip: 'Alterar período',
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _selecionandoLoja
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Selecione o estabelecimento',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Consulte o extrato de qualquer estabelecimento, ativo ou inativo.',
                      ),
                      const SizedBox(height: 16),
                      ..._lojas.map(
                        (loja) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.storefront),
                            title: Text(loja.nmloja),
                            subtitle: Text(
                              (loja.sitloja ?? '').toUpperCase() == 'ATIVA'
                                  ? 'Ativo'
                                  : 'Inativo',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _selecionarLoja(loja.lojaId),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      OutlinedButton.icon(
                        onPressed: _lojas.length > 1
                            ? () => setState(() => _selecionandoLoja = true)
                            : null,
                        icon: const Icon(Icons.storefront),
                        label: Text(
                          'Estabelecimento: ${_lojas.firstWhere((loja) => loja.lojaId == _lojaId).nmloja}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'São exibidos pagamentos dos últimos 12 meses da conta Mercado Pago vinculada, inclusive de outros estabelecimentos que usem essa conta. Este histórico não inclui todas as movimentações de saldo.',
                      ),
                      const SizedBox(height: 10),
                      if (_erro != null)
                        Text(_erro!, style: const TextStyle(color: Colors.red))
                      else if (_pagamentos.isEmpty)
                        const Text('Nenhum pagamento encontrado no período.')
                      else
                        ..._pagamentos.map((item) {
                          final data = DateTime.tryParse(
                            item['data']?.toString() ?? '',
                          );
                          final valor =
                              (item['valor'] as num?)?.toDouble() ?? 0;
                          final estornado =
                              (item['estornado'] as num?)?.toDouble() ?? 0;
                          return Card(
                            child: ListTile(
                              title: Text(_descricaoLancamento(item)),
                              subtitle: Text(
                                '${data == null ? 'Data indisponível' : _data.format(data.toLocal())} • ${_status(item['status'])}${estornado > 0 ? '\nReembolsado: ${_moeda.format(estornado)}' : ''}',
                              ),
                              trailing: Text(_moeda.format(valor)),
                            ),
                          );
                        }),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _offset == 0
                                ? null
                                : () {
                                    _offset = (_offset - 50).clamp(0, 10000);
                                    _carregar();
                                  },
                            child: const Text('Anterior'),
                          ),
                          TextButton(
                            onPressed: !_mais || _offset >= 10000
                                ? null
                                : () {
                                    _offset += 50;
                                    _carregar();
                                  },
                            child: const Text('Próxima'),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}
