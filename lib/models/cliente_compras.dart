class ClienteComCompras {
  final Map<String, dynamic> cadastro;
  final Map<String, dynamic> resumo;
  final List<CompraCliente> compras;

  const ClienteComCompras({
    required this.cadastro,
    required this.resumo,
    required this.compras,
  });

  String get nome => cadastro['nmcliente']?.toString() ?? 'Cliente';
  String get email => cadastro['emailcliente']?.toString() ?? '';

  factory ClienteComCompras.fromJson(Map<String, dynamic> json) {
    return ClienteComCompras(
      cadastro: Map<String, dynamic>.from(json['cliente'] as Map? ?? const {}),
      resumo: Map<String, dynamic>.from(json['resumo'] as Map? ?? const {}),
      compras: ((json['compras'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => CompraCliente.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }
}

class CompraCliente {
  final Map<String, dynamic> dados;
  final List<Map<String, dynamic>> itens;
  final List<Map<String, dynamic>> pagamentos;

  const CompraCliente({
    required this.dados,
    required this.itens,
    required this.pagamentos,
  });

  factory CompraCliente.fromJson(Map<String, dynamic> json) {
    final dados = Map<String, dynamic>.from(json)
      ..remove('itens')
      ..remove('pagamentos');
    return CompraCliente(
      dados: dados,
      itens: ((json['itens'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
      pagamentos: ((json['pagamentos'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
    );
  }
}
