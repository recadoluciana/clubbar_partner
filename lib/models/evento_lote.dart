class EventoLote {
  final int loteId;
  final int? organizacaoId;
  final int? lojaId;
  final int? eventoId;
  final String nmlote;
  final double vrprecolote;
  final int qttotallote;
  final int qtvendidalote;
  final String? dtiniciovenda;
  final String? dtfimvenda;
  final String? statuslote;

  EventoLote({
    required this.loteId,
    this.organizacaoId,
    this.lojaId,
    this.eventoId,
    required this.nmlote,
    required this.vrprecolote,
    required this.qttotallote,
    required this.qtvendidalote,
    this.dtiniciovenda,
    this.dtfimvenda,
    this.statuslote,
  });

  factory EventoLote.fromJson(Map<String, dynamic> json) {
    return EventoLote(
      loteId: json['lote_id'] ?? 0,
      organizacaoId: json['organizacao_id'],
      lojaId: json['loja_id'],
      eventoId: json['evento_id'],
      nmlote: (json['nmlote'] ?? '').toString(),
      vrprecolote: (json['vrprecolote'] as num?)?.toDouble() ?? 0,
      qttotallote: (json['qttotallote'] as num?)?.toInt() ?? 0,
      qtvendidalote: (json['qtvendidalote'] as num?)?.toInt() ?? 0,
      dtiniciovenda: json['dtiniciovenda']?.toString(),
      dtfimvenda: json['dtfimvenda']?.toString(),
      statuslote: json['statuslote']?.toString(),
    );
  }
}
