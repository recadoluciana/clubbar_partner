class Loja {
  final int lojaId;
  final int organizacaoId;
  final int? estadoId;
  final int? cidadeId;
  final String? nmestado;
  final String? sgestado;
  final String? nmcidade;
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
    this.estadoId,
    this.cidadeId,
    this.nmestado,
    this.sgestado,
    this.nmcidade,
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
      lojaId: _toInt(json['loja_id']),
      organizacaoId: _toInt(json['organizacao_id']),
      estadoId: _toNullableInt(json['estado_id']),
      cidadeId: _toNullableInt(json['cidade_id']),
      nmestado: json['nmestado']?.toString(),
      sgestado: json['sgestado']?.toString(),
      nmcidade: json['nmcidade']?.toString(),
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
      'estado_id': estadoId,
      'cidade_id': cidadeId,
      'nmestado': nmestado,
      'sgestado': sgestado,
      'nmcidade': nmcidade,
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

  Loja copyWith({
    int? lojaId,
    int? organizacaoId,
    int? estadoId,
    int? cidadeId,
    String? nmestado,
    String? sgestado,
    String? nmcidade,
    String? nmloja,
    String? dsbairroloja,
    String? nrtelloja,
    String? dshorarioloja,
    int? nrdiavalidade,
    String? sitloja,
    String? urllogoloja,
    String? endloja,
    String? dsinstaloja,
    double? vrtaxaprod,
    double? vrtaxaing,
    String? dsestiloloja,
  }) {
    return Loja(
      lojaId: lojaId ?? this.lojaId,
      organizacaoId: organizacaoId ?? this.organizacaoId,
      estadoId: estadoId ?? this.estadoId,
      cidadeId: cidadeId ?? this.cidadeId,
      nmestado: nmestado ?? this.nmestado,
      sgestado: sgestado ?? this.sgestado,
      nmcidade: nmcidade ?? this.nmcidade,
      nmloja: nmloja ?? this.nmloja,
      dsbairroloja: dsbairroloja ?? this.dsbairroloja,
      nrtelloja: nrtelloja ?? this.nrtelloja,
      dshorarioloja: dshorarioloja ?? this.dshorarioloja,
      nrdiavalidade: nrdiavalidade ?? this.nrdiavalidade,
      sitloja: sitloja ?? this.sitloja,
      urllogoloja: urllogoloja ?? this.urllogoloja,
      endloja: endloja ?? this.endloja,
      dsinstaloja: dsinstaloja ?? this.dsinstaloja,
      vrtaxaprod: vrtaxaprod ?? this.vrtaxaprod,
      vrtaxaing: vrtaxaing ?? this.vrtaxaing,
      dsestiloloja: dsestiloloja ?? this.dsestiloloja,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Loja &&
            other.lojaId == lojaId &&
            other.organizacaoId == organizacaoId &&
            other.estadoId == estadoId &&
            other.cidadeId == cidadeId &&
            other.nmestado == nmestado &&
            other.sgestado == sgestado &&
            other.nmcidade == nmcidade &&
            other.nmloja == nmloja &&
            other.dsbairroloja == dsbairroloja &&
            other.nrtelloja == nrtelloja &&
            other.dshorarioloja == dshorarioloja &&
            other.nrdiavalidade == nrdiavalidade &&
            other.sitloja == sitloja &&
            other.urllogoloja == urllogoloja &&
            other.endloja == endloja &&
            other.dsinstaloja == dsinstaloja &&
            other.vrtaxaprod == vrtaxaprod &&
            other.vrtaxaing == vrtaxaing &&
            other.dsestiloloja == dsestiloloja;
  }

  @override
  int get hashCode => Object.hashAll([
    lojaId,
    organizacaoId,
    estadoId,
    cidadeId,
    nmestado,
    sgestado,
    nmcidade,
    nmloja,
    dsbairroloja,
    nrtelloja,
    dshorarioloja,
    nrdiavalidade,
    sitloja,
    urllogoloja,
    endloja,
    dsinstaloja,
    vrtaxaprod,
    vrtaxaing,
    dsestiloloja,
  ]);
}
