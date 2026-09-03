class Organizacao {
  final int organizacaoId;
  final String nmorganizacao;
  final String? rzsocialorganizacao;
  final String? cnpjorganizacao;
  final String? emailorganizacao;
  final String? telorganizacao;
  final String? ceporganizacao;
  final String? endorganizacao;
  final String? nrendorganizacao;
  final String? complorganizacao;
  final int? cidadeId;
  final String? nmbairro;
  final int? leadparceiroId;
  final String? nmresponsavelprincipal;
  final String? tipooperacao;
  final String? nmleadorigem;
  final String sitorganizacao;
  final DateTime? dtcriacao;
  final DateTime? dtultatu;
  final String? nmcidade;
  final int? estadoId;
  final String? sgestado;

  const Organizacao({
    required this.organizacaoId,
    required this.nmorganizacao,
    this.rzsocialorganizacao,
    this.cnpjorganizacao,
    this.emailorganizacao,
    this.telorganizacao,
    this.ceporganizacao,
    this.endorganizacao,
    this.nrendorganizacao,
    this.complorganizacao,
    this.cidadeId,
    this.nmbairro,
    this.leadparceiroId,
    this.nmresponsavelprincipal,
    this.tipooperacao,
    this.nmleadorigem,
    this.sitorganizacao = 'ATIVA',
    this.dtcriacao,
    this.dtultatu,
    this.nmcidade,
    this.estadoId,
    this.sgestado,
  });

  factory Organizacao.fromJson(Map<String, dynamic> json) {
    return Organizacao(
      organizacaoId: _toInt(json['organizacao_id']),
      nmorganizacao: json['nmorganizacao']?.toString() ?? '',
      rzsocialorganizacao: json['rzsocialorganizacao']?.toString(),
      cnpjorganizacao: json['cnpjorganizacao']?.toString(),
      emailorganizacao: json['emailorganizacao']?.toString(),
      telorganizacao: json['telorganizacao']?.toString(),
      ceporganizacao: json['ceporganizacao']?.toString(),
      endorganizacao: json['endorganizacao']?.toString(),
      nrendorganizacao: json['nrendorganizacao']?.toString(),
      complorganizacao: json['complorganizacao']?.toString(),
      cidadeId: _toNullableInt(json['cidade_id']),
      nmbairro: json['nmbairro']?.toString(),
      leadparceiroId: _toNullableInt(json['leadparceiro_id']),
      nmresponsavelprincipal: json['nmresponsavelprincipal']?.toString(),
      tipooperacao: json['tipooperacao']?.toString(),
      nmleadorigem: json['nmleadorigem']?.toString(),
      sitorganizacao: json['sitorganizacao']?.toString() ?? 'ATIVA',
      dtcriacao: _toNullableDateTime(json['dtcriacao']),
      dtultatu: _toNullableDateTime(json['dtultatu']),
      nmcidade: json['nmcidade']?.toString(),
      estadoId: _toNullableInt(json['estado_id']),
      sgestado: json['sgestado']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'organizacao_id': organizacaoId,
      'nmorganizacao': nmorganizacao,
      'rzsocialorganizacao': rzsocialorganizacao,
      'cnpjorganizacao': cnpjorganizacao,
      'emailorganizacao': emailorganizacao,
      'telorganizacao': telorganizacao,
      'ceporganizacao': ceporganizacao,
      'endorganizacao': endorganizacao,
      'nrendorganizacao': nrendorganizacao,
      'complorganizacao': complorganizacao,
      'cidade_id': cidadeId,
      'nmbairro': nmbairro,
      'leadparceiro_id': leadparceiroId,
      'nmresponsavelprincipal': nmresponsavelprincipal,
      'tipooperacao': tipooperacao,
      'nmleadorigem': nmleadorigem,
      'sitorganizacao': sitorganizacao,
      'dtcriacao': dtcriacao?.toIso8601String(),
      'dtultatu': dtultatu?.toIso8601String(),
      'nmcidade': nmcidade,
      'estado_id': estadoId,
      'sgestado': sgestado,
    };
  }

  Organizacao copyWith({
    int? organizacaoId,
    String? nmorganizacao,
    String? rzsocialorganizacao,
    String? cnpjorganizacao,
    String? emailorganizacao,
    String? telorganizacao,
    String? ceporganizacao,
    String? endorganizacao,
    String? nrendorganizacao,
    String? complorganizacao,
    int? cidadeId,
    String? nmbairro,
    int? leadparceiroId,
    String? sitorganizacao,
    DateTime? dtcriacao,
    DateTime? dtultatu,
    String? nmcidade,
    int? estadoId,
    String? sgestado,
  }) {
    return Organizacao(
      organizacaoId: organizacaoId ?? this.organizacaoId,
      nmorganizacao: nmorganizacao ?? this.nmorganizacao,
      rzsocialorganizacao: rzsocialorganizacao ?? this.rzsocialorganizacao,
      cnpjorganizacao: cnpjorganizacao ?? this.cnpjorganizacao,
      emailorganizacao: emailorganizacao ?? this.emailorganizacao,
      telorganizacao: telorganizacao ?? this.telorganizacao,
      ceporganizacao: ceporganizacao ?? this.ceporganizacao,
      endorganizacao: endorganizacao ?? this.endorganizacao,
      nrendorganizacao: nrendorganizacao ?? this.nrendorganizacao,
      complorganizacao: complorganizacao ?? this.complorganizacao,
      cidadeId: cidadeId ?? this.cidadeId,
      nmbairro: nmbairro ?? this.nmbairro,
      leadparceiroId: leadparceiroId ?? this.leadparceiroId,
      sitorganizacao: sitorganizacao ?? this.sitorganizacao,
      dtcriacao: dtcriacao ?? this.dtcriacao,
      dtultatu: dtultatu ?? this.dtultatu,
      nmcidade: nmcidade ?? this.nmcidade,
      estadoId: estadoId ?? this.estadoId,
      sgestado: sgestado ?? this.sgestado,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
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

    if (value is num) {
      return value.toInt();
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
  String toString() {
    return 'Organizacao('
        'organizacaoId: $organizacaoId, '
        'nmorganizacao: $nmorganizacao, '
        'cnpjorganizacao: $cnpjorganizacao, '
        'sitorganizacao: $sitorganizacao'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Organizacao &&
        other.organizacaoId == organizacaoId &&
        other.nmorganizacao == nmorganizacao &&
        other.rzsocialorganizacao == rzsocialorganizacao &&
        other.cnpjorganizacao == cnpjorganizacao &&
        other.emailorganizacao == emailorganizacao &&
        other.telorganizacao == telorganizacao &&
        other.ceporganizacao == ceporganizacao &&
        other.endorganizacao == endorganizacao &&
        other.nrendorganizacao == nrendorganizacao &&
        other.complorganizacao == complorganizacao &&
        other.cidadeId == cidadeId &&
        other.nmbairro == nmbairro &&
        other.leadparceiroId == leadparceiroId &&
        other.sitorganizacao == sitorganizacao &&
        other.dtcriacao == dtcriacao &&
        other.dtultatu == dtultatu &&
        other.nmcidade == nmcidade &&
        other.estadoId == estadoId &&
        other.sgestado == sgestado;
  }

  @override
  int get hashCode {
    return Object.hash(
      organizacaoId,
      nmorganizacao,
      rzsocialorganizacao,
      cnpjorganizacao,
      emailorganizacao,
      telorganizacao,
      ceporganizacao,
      endorganizacao,
      nrendorganizacao,
      complorganizacao,
      cidadeId,
      nmbairro,
      leadparceiroId,
      sitorganizacao,
      dtcriacao,
      dtultatu,
      nmcidade,
      estadoId,
      sgestado,
    );
  }
}
