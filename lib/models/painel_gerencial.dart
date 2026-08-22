class PainelGerencial {
  final DateTime? periodoInicio;
  final DateTime? periodoFim;
  final double totalHoje;
  final double totalMes;
  final double totalProdutosMes;
  final double totalIngressosMes;
  final int pedidosMes;
  final int ingressosVendidosMes;
  final List<ParticipacaoLoja> participacaoLojas;
  final List<ItemRankingGerencial> produtosMaisVendidos;
  final List<ItemRankingGerencial> ingressosMaisVendidos;

  const PainelGerencial({
    this.periodoInicio,
    this.periodoFim,
    required this.totalHoje,
    required this.totalMes,
    required this.totalProdutosMes,
    required this.totalIngressosMes,
    required this.pedidosMes,
    required this.ingressosVendidosMes,
    required this.participacaoLojas,
    required this.produtosMaisVendidos,
    required this.ingressosMaisVendidos,
  });

  factory PainelGerencial.fromJson(Map<String, dynamic> json) {
    final periodo = json['periodo'];
    return PainelGerencial(
      periodoInicio: _data(periodo is Map ? periodo['inicio'] : null),
      periodoFim: _data(periodo is Map ? periodo['fim'] : null),
      totalHoje: _double(json['total_hoje']),
      totalMes: _double(json['total_mes']),
      totalProdutosMes: _double(json['total_produtos_mes']),
      totalIngressosMes: _double(json['total_ingressos_mes']),
      pedidosMes: _int(json['pedidos_mes']),
      ingressosVendidosMes: _int(json['ingressos_vendidos_mes']),
      participacaoLojas: _lista(
        json['participacao_lojas'],
      ).map(ParticipacaoLoja.fromJson).toList(),
      produtosMaisVendidos: _lista(
        json['produtos_mais_vendidos'],
      ).map(ItemRankingGerencial.fromJson).toList(),
      ingressosMaisVendidos: _lista(
        json['ingressos_mais_vendidos'],
      ).map(ItemRankingGerencial.fromJson).toList(),
    );
  }

  static List<Map<String, dynamic>> _lista(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static DateTime? _data(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '');
  static int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  static double _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class ParticipacaoLoja {
  final int lojaId;
  final String nomeLoja;
  final double valor;
  final double percentual;

  const ParticipacaoLoja({
    required this.lojaId,
    required this.nomeLoja,
    required this.valor,
    required this.percentual,
  });

  factory ParticipacaoLoja.fromJson(Map<String, dynamic> json) {
    return ParticipacaoLoja(
      lojaId: PainelGerencial._int(json['loja_id']),
      nomeLoja: json['nmloja']?.toString() ?? '',
      valor: PainelGerencial._double(json['valor']),
      percentual: PainelGerencial._double(json['percentual']),
    );
  }
}

class ItemRankingGerencial {
  final int id;
  final String nome;
  final int quantidade;
  final double valor;

  const ItemRankingGerencial({
    required this.id,
    required this.nome,
    required this.quantidade,
    required this.valor,
  });

  factory ItemRankingGerencial.fromJson(Map<String, dynamic> json) {
    return ItemRankingGerencial(
      id: PainelGerencial._int(json['produto_id'] ?? json['lote_id']),
      nome: json['nome']?.toString() ?? '',
      quantidade: PainelGerencial._int(json['quantidade']),
      valor: PainelGerencial._double(json['valor']),
    );
  }
}
