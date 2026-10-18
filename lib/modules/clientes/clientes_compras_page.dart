import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/repositories/acompanhamento_vendas_repository.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/utils/horario_brasil.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_card.dart';
import '../../core/widgets/clubbar_page_header.dart';
import '../../models/cliente_compras.dart';

class ClientesComprasPage extends StatefulWidget {
  const ClientesComprasPage({super.key});

  @override
  State<ClientesComprasPage> createState() => _ClientesComprasPageState();
}

class _ClientesComprasPageState extends State<ClientesComprasPage> {
  final _repository = AcompanhamentoVendasRepository();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _dataHora = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  final _busca = TextEditingController();

  List<ClienteComCompras> _clientes = const [];
  bool _carregando = true;
  String? _erro;

  static const _rotulos = <String, String>{
    'cliente_id': 'ID do cliente',
    'nmcliente': 'Nome',
    'emailcliente': 'E-mail',
    'sitcliente': 'Situação do cliente',
    'emailconf': 'E-mail confirmado',
    'dtcriacao': 'Cadastro em',
    'cliente_padrao': 'Cliente padrão',
    'dtultatu': 'Atualizado em',
    'nrtelcliente': 'Telefone',
    'nrcpfcliente': 'CPF',
    'idclienteasaas': 'ID do cliente no Asaas',
    'endcliente': 'Endereço',
    'nrendcliente': 'Número',
    'complcliente': 'Complemento',
    'bairrocliente': 'Bairro',
    'cepcliente': 'CEP',
    'cidadecliente': 'Cidade',
    'ufcliente': 'UF',
    'idcidadeibge': 'Código IBGE da cidade',
    'venda_id': 'ID da venda',
    'organizacao_id': 'ID da organização',
    'loja_id': 'ID do estabelecimento',
    'nmloja': 'Estabelecimento',
    'carrinho_id': 'ID do carrinho',
    'reserva_ingresso_id': 'ID da reserva de ingresso',
    'usuario_id': 'ID do usuário',
    'tipovenda': 'Tipo de venda',
    'dsplataforma': 'Plataforma',
    'sitvenda': 'Situação da venda',
    'totalvenda': 'Total da venda',
    'itvenda_id': 'ID do item de venda',
    'tipoitem': 'Tipo do item',
    'produto_id': 'ID do produto',
    'nmproduto': 'Produto',
    'cardapioitem_id': 'ID do item do cardápio',
    'qtitvenda': 'Quantidade',
    'vrunititvenda': 'Valor unitário',
    'identregaitvenda': 'Retirado',
    'dtentregaitvenda': 'Retirado em',
    'idcontrolebar': 'Controle do bar',
    'nrmesa': 'Mesa',
    'userentregaitvenda': 'ID do usuário da retirada',
    'nmuserentregaitvenda': 'Responsável pela retirada',
    'dsobsitvenda': 'Observação',
    'dtexpiraitvenda': 'Validade',
    'nmparticipante': 'Participante',
    'cpfparticipante': 'CPF do participante',
    'lote_id': 'ID do lote',
    'lotepreco_id': 'ID do preço do lote',
    'modalidade_id': 'ID da modalidade',
    'beneficio_id': 'ID do benefício',
    'tipobeneficio': 'Tipo do benefício',
    'nmmodalidadesnapshot': 'Modalidade registrada',
    'nmbeneficiosnapshot': 'Benefício registrado',
    'pctaxaitvenda': 'Percentual da taxa',
    'vrtaxaitvenda': 'Valor da taxa',
    'sititvenda': 'Situação do item',
    'dtcancelamento': 'Cancelado em',
    'vrreembolso': 'Valor do reembolso',
    'idreembolso': 'ID do reembolso',
    'pagvenda_id': 'ID do pagamento',
    'dsmetodopag': 'Método de pagamento',
    'vrpagvenda': 'Valor pago',
    'sitpagvenda': 'Situação do pagamento',
    'idtransacaopagvenda': 'ID da transação',
    'dtconftranspagvenda': 'Pagamento confirmado em',
    'provedor': 'Provedor',
    'reference_id': 'Referência do pagamento',
    'checkout_id': 'ID do checkout',
  };

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final clientes = await _repository.clientesComCompras(busca: _busca.text);
      if (!mounted) return;
      setState(() {
        _clientes = clientes;
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

  String _rotulo(String chave) => _rotulos[chave] ?? chave.replaceAll('_', ' ');

  String _valor(String chave, dynamic valor) {
    if (valor == null || valor.toString().trim().isEmpty) return '—';
    if (chave.startsWith('dt')) {
      final data = HorarioBrasil.deTextoBrasil(valor);
      if (data != null) return _dataHora.format(data);
    }
    if (chave.startsWith('vr') || chave == 'totalvenda') {
      final numero = valor is num
          ? valor.toDouble()
          : double.tryParse('$valor');
      if (numero != null) return _moeda.format(numero);
    }
    return '$valor';
  }

  Widget _campo(String chave, dynamic valor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: ClubbarColors.fundo,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: ClubbarColors.borda),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _rotulo(chave),
          style: const TextStyle(
            fontSize: 10,
            color: ClubbarColors.textoSecundario,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(
          _valor(chave, valor),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _campos(Map<String, dynamic> dados) => LayoutBuilder(
    builder: (context, constraints) {
      final largura = constraints.maxWidth >= 720
          ? (constraints.maxWidth - 24) / 3
          : constraints.maxWidth >= 460
          ? (constraints.maxWidth - 12) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 12,
        runSpacing: 10,
        children: dados.entries
            .map(
              (campo) => SizedBox(
                width: largura,
                child: _campo(campo.key, campo.value),
              ),
            )
            .toList(growable: false),
      );
    },
  );

  Widget _compra(CompraCliente compra) {
    final vendaId = compra.dados['venda_id'];
    final loja = compra.dados['nmloja']?.toString() ?? '';
    final total = _valor('totalvenda', compra.dados['totalvenda']);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ClubbarColors.borda),
      ),
      child: ExpansionTile(
        title: Text(
          'Venda #$vendaId · $total',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '$loja · ${_valor('dtcriacao', compra.dados['dtcriacao'])}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Dados da venda',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 8),
          _campos(compra.dados),
          const SizedBox(height: 14),
          Text(
            'Itens (${compra.itens.length})',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          for (var indice = 0; indice < compra.itens.length; indice++) ...[
            const SizedBox(height: 8),
            _campos(compra.itens[indice]),
          ],
          const SizedBox(height: 14),
          Text(
            'Pagamentos (${compra.pagamentos.length})',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          if (compra.pagamentos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Nenhum pagamento registrado.'),
            ),
          for (final pagamento in compra.pagamentos) ...[
            const SizedBox(height: 8),
            _campos(pagamento),
          ],
        ],
      ),
    );
  }

  Widget _cliente(ClienteComCompras cliente) => ClubbarCard(
    margin: const EdgeInsets.only(bottom: 12),
    padding: EdgeInsets.zero,
    child: ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: ClubbarColors.infoClaro,
        foregroundColor: ClubbarColors.info,
        child: const Icon(Icons.person_rounded),
      ),
      title: Text(
        cliente.nome,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '${cliente.email}\n${cliente.resumo['quantidade_compras'] ?? 0} compra(s) · ${_valor('totalvenda', cliente.resumo['valor_total_compras'])}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Dados cadastrais',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 8),
        _campos(cliente.cadastro),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Compras (${cliente.compras.length})',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        if (cliente.compras.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Nenhuma compra localizada.'),
          ),
        for (final compra in cliente.compras) _compra(compra),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: SafeArea(
        child: Column(
          children: [
            ClubbarPageHeader(
              titulo: 'Clientes e compras',
              subtitulo:
                  'Cadastros e histórico completo de vendas da organização',
              trailing: IconButton(
                onPressed: _carregando ? null : _carregar,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            Expanded(
              child: _carregando
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: ClubbarColors.primaria,
                      ),
                    )
                  : _erro != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 48),
                            const SizedBox(height: 10),
                            Text(_erro!, textAlign: TextAlign.center),
                            TextButton.icon(
                              onPressed: _carregar,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _carregar,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          TextField(
                            controller: _busca,
                            onSubmitted: (_) => _carregar(),
                            decoration: InputDecoration(
                              hintText: 'Buscar nome, e-mail, telefone ou CPF',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: IconButton(
                                onPressed: _carregar,
                                icon: const Icon(Icons.search_rounded),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: ClubbarColors.borda,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_clientes.length} cliente${_clientes.length == 1 ? '' : 's'} encontrado${_clientes.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: ClubbarColors.textoSecundario,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Campos de autenticação, QR Codes e links de pagamento não são exibidos por segurança.',
                            style: TextStyle(
                              fontSize: 11,
                              color: ClubbarColors.textoSecundario,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_clientes.isEmpty)
                            const ClubbarCard(
                              child: Text(
                                'Nenhum cliente com compras foi encontrado.',
                              ),
                            ),
                          ..._clientes.map(_cliente),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
