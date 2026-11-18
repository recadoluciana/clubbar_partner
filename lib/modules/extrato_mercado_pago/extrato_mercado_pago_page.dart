import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/loja_repository.dart';
import '../../core/config/api_config.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/horario_brasil.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../core/widgets/clubbar_app_bar.dart';
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
  List<dynamic> _contas = [];
  int? _contaId;
  int? _lojaId;
  int? _organizacaoId;
  int _offset = 0;
  bool _mais = false;
  bool _carregando = true;
  bool _selecionandoLoja = false;
  String? _erro;
  String? _nomeTitularConta;
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

  Widget _badgeStatus(dynamic status) {
    final cor = switch (status?.toString()) {
      'approved' => Colors.green.shade700,
      'cancelled' => Colors.red.shade700,
      'refunded' => Colors.blue.shade700,
      _ => Colors.grey.shade700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _status(status),
        style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _nomeTarifa(String tipo) => switch (tipo.toLowerCase()) {
    'mercadopago_fee' => 'Taxa Mercado Pago',
    'application_fee' || 'marketplace_fee' => 'Comissão do marketplace',
    'financing_fee' => 'Taxa de financiamento',
    'shipping_fee' => 'Taxa de envio',
    'coupon_fee' => 'Taxa de cupom',
    _ => 'Outra tarifa ($tipo)',
  };

  String _nomePagamento(dynamic tipo, dynamic metodo) {
    final nome = switch (tipo?.toString()) {
      'credit_card' => 'Cartão de crédito',
      'debit_card' => 'Cartão de débito',
      'bank_transfer' => 'Transferência',
      'account_money' => 'Saldo Mercado Pago',
      'ticket' => 'Boleto',
      _ => null,
    };
    final codigo = metodo?.toString().trim() ?? '';
    if (codigo.toLowerCase() == 'pix') return 'Pix';
    if (nome != null && codigo.isNotEmpty) return '$nome ($codigo)';
    return nome ?? (codigo.isNotEmpty ? codigo : 'Não informado');
  }

  Widget _detalhesFinanceiros(Map item) {
    final liquido = item['liquido_recebido'];
    final totalPago = item['total_pago'];
    final valorIngressos = item['valor_ingressos'];
    final diferencaRepasse = item['diferenca_repasse'];
    final taxas = item['taxas'] is List ? item['taxas'] as List : const [];
    final liberacao = HorarioBrasil.deTextoBrasil(item['data_liberacao']);
    final situacaoLiberacao = switch (item['situacao_liberacao']?.toString()) {
      'released' => 'Liberado',
      'pending' => 'Pendente',
      'in_process' => 'Em processamento',
      _ => null,
    };
    Widget linha(String titulo, String valor) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(titulo)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return ExpansionTile(
      title: const Text(
        'Detalhes financeiros',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        linha(
          'Pagamento',
          _nomePagamento(item['tipo_pagamento'], item['metodo']),
        ),
        if (item['parcelas'] is int) linha('Parcelas', '${item['parcelas']}'),
        linha(
          'Total pago pelo cliente',
          totalPago is num ? _moeda.format(totalPago) : 'Não informado',
        ),
        linha(
          'Valor líquido informado',
          liquido is num ? _moeda.format(liquido) : 'Não informado',
        ),
        if (valorIngressos is num && diferencaRepasse is num) ...[
          linha('Valor dos ingressos', _moeda.format(valorIngressos)),
          linha('Diferença para conciliação', _moeda.format(diferencaRepasse)),
          if (diferencaRepasse.abs() >= 0.005)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'O líquido informado difere do valor dos ingressos. Confira a operação e concilie a diferença.',
                style: TextStyle(color: Colors.deepOrange, fontSize: 12),
              ),
            ),
        ] else if (item['tipo_venda'] == 'INGRESSO')
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'A comparação fica disponível para pagamentos aprovados e liberados, sem reembolso, quando houver dados suficientes.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        if (taxas.isEmpty)
          linha('Tarifas', 'Não informadas')
        else
          ...taxas.whereType<Map>().map((taxa) {
            final valor = taxa['valor'];
            final responsavel = switch (taxa['responsavel']?.toString()) {
              'collector' => 'vendedor',
              'payer' => 'comprador',
              _ => null,
            };
            final nome = _nomeTarifa(taxa['tipo']?.toString() ?? 'outra');
            return linha(
              responsavel == null ? nome : '$nome ($responsavel)',
              valor is num ? _moeda.format(valor) : 'Não informado',
            );
          }),
        if (situacaoLiberacao != null)
          linha('Situação da liberação', situacaoLiberacao),
        if (liberacao != null)
          linha('Data de liberação informada', _data.format(liberacao)),
        if (item['id']?.toString().isNotEmpty == true)
          linha('ID do pagamento', item['id'].toString()),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Valores informados pelo Mercado Pago; o valor líquido pode mudar em caso de reembolso ou contestação.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

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
        await _carregarContas();
        if (!mounted) return;
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

  Future<void> _carregarContas() async {
    final uri = Uri(
      path:
          '/titular-financeiro/organizacao/$_organizacaoId/contas-extrato-mercado-pago',
      queryParameters: {'loja_id': '$_lojaId'},
    );
    final resposta = await ApiService.get(uri.toString());
    if (resposta.statusCode != 200) {
      throw Exception('Não foi possível carregar as contas Mercado Pago.');
    }
    final contas = jsonDecode(resposta.body) as List;
    _contas = contas;
    final atual = contas.where((c) => c['status'] == 'ATIVA').firstOrNull;
    _contaId = (atual ?? contas.firstOrNull)?['id'] as int?;
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
      _nomeTitularConta = null;
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
          if (_contaId != null) 'conta_id': '$_contaId',
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
          _nomeTitularConta = dados['nome_titular_conta']?.toString();
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
      _carregando = true;
      _erro = null;
      _contas = [];
      _contaId = null;
      _pagamentos = [];
    });
    try {
      await _carregarContas();
      if (!mounted) return;
      await _carregar();
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString().replaceFirst('Exception: ', '');
          _carregando = false;
        });
      }
    }
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
      locale: const Locale('pt', 'BR'),
      helpText: 'Selecione o período do extrato',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (intervalo == null || !mounted) return;
    setState(() {
      _inicio = intervalo.start;
      _fim = intervalo.end;
      _offset = 0;
    });
    if (!_selecionandoLoja && _lojaId != null) await _carregar();
  }

  Widget _logoLoja(Loja loja) {
    final url = ApiConfig.buildUrl(loja.urllogoloja ?? '');
    const fallback = Icon(Icons.storefront_outlined);
    if (url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ClubbarAppBar(
      mostrarVoltar: true,
      onVoltar: () {
        if (!_selecionandoLoja && _lojas.length > 1) {
          setState(() => _selecionandoLoja = true);
        } else {
          Navigator.maybePop(context);
        }
      },
    ),
    body: SafeArea(
      child: Column(
        children: [
          ClubbarPageHeader(
            mostrarVoltar: false,
            titulo: 'Extrato Mercado Pago',
            trailing: _selecionandoLoja
                ? null
                : IconButton(
                    tooltip: 'Atualizar extrato',
                    onPressed: _carregando || _lojaId == null
                        ? null
                        : _carregar,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
            subtitulo: _selecionandoLoja
                ? 'Pagamentos da conta conectada'
                : _lojas
                          .where((loja) => loja.lojaId == _lojaId)
                          .firstOrNull
                          ?.nmloja ??
                      'Pagamentos da conta conectada',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _carregando ? null : _periodo,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(
                  'Período: ${DateFormat('dd/MM/yyyy').format(_inicio)} a ${DateFormat('dd/MM/yyyy').format(_fim)}',
                ),
              ),
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _lojas.isEmpty
                ? Center(
                    child: Text(_erro ?? 'Nenhum estabelecimento disponível.'),
                  )
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
                            leading: _logoLoja(loja),
                            title: Text(loja.nmloja),
                            subtitle: Text(
                              (loja.sitloja ?? '').toUpperCase() == 'ATIVA'
                                  ? 'Ativo'
                                  : 'Inativo',
                              style: TextStyle(
                                color:
                                    (loja.sitloja ?? '').toUpperCase() ==
                                        'ATIVA'
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
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
                      if (_contas.isNotEmpty) ...[
                        DropdownButtonFormField<int>(
                          initialValue: _contaId,
                          decoration: const InputDecoration(
                            labelText: 'Conta Mercado Pago',
                            border: OutlineInputBorder(),
                          ),
                          items: _contas
                              .map(
                                (conta) => DropdownMenuItem<int>(
                                  value: conta['id'] as int,
                                  child: Text(
                                    '${conta['nome'] ?? conta['conta']} • ${conta['status'] == 'ATIVA' ? 'Atual' : 'Anterior'}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (valor) {
                            setState(() {
                              _contaId = valor;
                              _offset = 0;
                            });
                            _carregar();
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Titular da conta: ${_nomeTitularConta?.trim().isNotEmpty == true ? _nomeTitularConta : 'Não disponível'}',
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Text(
                        'São exibidos pagamentos identificados pelo Clubbar para este estabelecimento. Pagamentos sem vínculo identificado não aparecem neste extrato.',
                      ),
                      const SizedBox(height: 10),
                      if (_erro != null)
                        Text(_erro!, style: const TextStyle(color: Colors.red))
                      else if (_pagamentos.isEmpty)
                        const Text('Nenhum pagamento encontrado no período.')
                      else
                        ..._pagamentos.map((item) {
                          final data = HorarioBrasil.deTextoBrasil(
                            item['data'],
                          );
                          final valor =
                              (item['valor'] as num?)?.toDouble() ?? 0;
                          final estornado =
                              (item['estornado'] as num?)?.toDouble() ?? 0;
                          final tipo = switch (item['tipo_venda']) {
                            'INGRESSO' => 'Ingresso',
                            'PRODUTO' => 'Produto',
                            _ => 'Tipo não identificado',
                          };
                          final itens = (item['itens'] as List? ?? [])
                              .whereType<Map>()
                              .map((i) => '${i['quantidade']} × ${i['nome']}')
                              .join(', ');
                          return Card(
                            child: Column(
                              children: [
                                ListTile(
                                  title: Text(_descricaoLancamento(item)),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            '$tipo • ${data == null ? 'Data indisponível' : _data.format(data)}',
                                          ),
                                          _badgeStatus(item['status']),
                                        ],
                                      ),
                                      Text(
                                        itens.isEmpty
                                            ? 'Detalhes não disponíveis'
                                            : itens,
                                      ),
                                      if (estornado > 0)
                                        Text(
                                          'Reembolsado: ${_moeda.format(estornado)}',
                                        ),
                                      if (item['diferenca_repasse'] is num &&
                                          (item['diferenca_repasse'] as num)
                                                  .abs() >=
                                              0.005)
                                        const Text(
                                          'Diferença para conciliar',
                                          style: TextStyle(
                                            color: Colors.deepOrange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Text(_moeda.format(valor)),
                                ),
                                _detalhesFinanceiros(item as Map),
                              ],
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
