class Loja {
  final int lojaId;
  final int organizacaoId;
  final int? cidadeId;
  final String nmloja;
  final String? dsbairroloja;
  final String? nrtelloja;
  final String? dshorarioloja;
  final int? nrdiavalidade;
  final String? sitloja;
  final String? urllogoloja;

  final String? endloja;
  final String? dsinstaloja;

  final double vrtaxaprod;
  final double vrtaxaing;
  final String? dsestiloloja;

  Loja({
    required this.lojaId,
    required this.organizacaoId,
    this.cidadeId,
    required this.nmloja,
    this.dsbairroloja,
    this.nrtelloja,
    this.dshorarioloja,
    this.nrdiavalidade,
    this.sitloja,
    this.urllogoloja,
    this.endloja,
    this.dsinstaloja,
    this.vrtaxaprod = 3.0,
    this.vrtaxaing = 10.0,
    this.dsestiloloja,
  });

  factory Loja.fromJson(Map<String, dynamic> json) {
    return Loja(
      lojaId: json['loja_id'] ?? 0,
      organizacaoId: json['organizacao_id'] ?? 0,
      cidadeId: json['cidade_id'],
      nmloja: (json['nmloja'] ?? '').toString(),
      dsbairroloja: json['dsbairroloja']?.toString(),
      nrtelloja: json['nrtelloja']?.toString(),
      dshorarioloja: json['dshorarioloja']?.toString(),
      nrdiavalidade: json['nrdiavalidade'],
      sitloja: json['sitloja']?.toString(),
      urllogoloja: json['urllogoloja']?.toString(),
      endloja: json['endloja']?.toString(),
      dsinstaloja: json['dsinstaloja']?.toString(),
      vrtaxaprod: (json['vrtaxaprod'] ?? 3).toDouble(),
      vrtaxaing: (json['vrtaxaing'] ?? 10).toDouble(),
      dsestiloloja: json['dsestiloloja']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'loja_id': lojaId,
      'organizacao_id': organizacaoId,
      'cidade_id': cidadeId,
      'nmloja': nmloja,
      'dsbairroloja': dsbairroloja,
      'nrtelloja': nrtelloja,
      'dshorarioloja': dshorarioloja,
      'nrdiavalidade': nrdiavalidade,
      'sitloja': sitloja,
      'urllogoloja': urllogoloja,
      'endloja': endloja,
      'dsinstaloja': dsinstaloja,
      'vrtaxaprod': vrtaxaprod,
      'vrtaxaing': vrtaxaing,
      'dsestiloloja': dsestiloloja,
    };
  }
}
