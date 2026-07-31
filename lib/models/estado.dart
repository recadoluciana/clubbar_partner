class Estado {
  final int estadoId;
  final int paisId;
  final int? cdibgeest;
  final String sgestado;
  final String nmestado;
  final DateTime? dtcriacao;
  final DateTime? dtultatu;

  const Estado({
    required this.estadoId,
    required this.paisId,
    this.cdibgeest,
    required this.sgestado,
    required this.nmestado,
    this.dtcriacao,
    this.dtultatu,
  });

  factory Estado.fromJson(Map<String, dynamic> json) {
    return Estado(
      estadoId: _toInt(json['estado_id']),
      paisId: _toInt(json['pais_id']),
      cdibgeest: _toNullableInt(json['cdibgeest']),
      sgestado: json['sgestado']?.toString().trim() ?? '',
      nmestado: json['nmestado']?.toString().trim() ?? '',
      dtcriacao: _toNullableDateTime(json['dtcriacao']),
      dtultatu: _toNullableDateTime(json['dtultatu']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'estado_id': estadoId,
      'pais_id': paisId,
      'cdibgeest': cdibgeest,
      'sgestado': sgestado,
      'nmestado': nmestado,
      'dtcriacao': dtcriacao?.toIso8601String(),
      'dtultatu': dtultatu?.toIso8601String(),
    };
  }

  String get descricao {
    if (sgestado.trim().isEmpty) {
      return nmestado;
    }

    return '$nmestado - $sgestado';
  }

  Estado copyWith({
    int? estadoId,
    int? paisId,
    int? cdibgeest,
    String? sgestado,
    String? nmestado,
    DateTime? dtcriacao,
    DateTime? dtultatu,
  }) {
    return Estado(
      estadoId: estadoId ?? this.estadoId,
      paisId: paisId ?? this.paisId,
      cdibgeest: cdibgeest ?? this.cdibgeest,
      sgestado: sgestado ?? this.sgestado,
      nmestado: nmestado ?? this.nmestado,
      dtcriacao: dtcriacao ?? this.dtcriacao,
      dtultatu: dtultatu ?? this.dtultatu,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  @override
  String toString() => descricao;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Estado && other.estadoId == estadoId;
  }

  @override
  int get hashCode => estadoId.hashCode;
}
