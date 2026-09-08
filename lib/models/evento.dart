class Evento {
  final int eventoId;
  final int organizacaoId;
  final int lojaId;
  final String nmtituloevento;

  final String? dsdescevento;
  final String? dspoliticacancelamento;
  final String tipoLocalEvento;
  final String? nrCepLocalEvento;
  final String? dtinicioevento;
  final String? dtfimevento;
  final String? statusevento;
  final double vrPrecoPadrao;
  final int? qtIngressosPadrao;

  final String? urlbannerevento;
  final String? nmlocalevento;
  final String? dsendlocevento;

  Evento({
    required this.eventoId,
    required this.organizacaoId,
    required this.lojaId,
    required this.nmtituloevento,
    this.dsdescevento,
    this.dspoliticacancelamento,
    this.tipoLocalEvento = 'ESTABELECIMENTO',
    this.nrCepLocalEvento,
    this.dtinicioevento,
    this.dtfimevento,
    this.statusevento,
    this.vrPrecoPadrao = 0,
    this.qtIngressosPadrao,
    this.urlbannerevento,
    this.nmlocalevento,
    this.dsendlocevento,
  });

  factory Evento.fromJson(Map<String, dynamic> json) {
    return Evento(
      eventoId: json['evento_id'] ?? 0,
      organizacaoId: json['organizacao_id'] ?? 0,
      lojaId: json['loja_id'] ?? 0,
      nmtituloevento: (json['nmtituloevento'] ?? '').toString(),

      dsdescevento: json['dsdescevento']?.toString(),
      dspoliticacancelamento: json['dspoliticacancelamento']?.toString(),
      tipoLocalEvento: json['tipolocalevento']?.toString() ?? 'ESTABELECIMENTO',
      nrCepLocalEvento: json['nrceplocalevento']?.toString(),
      dtinicioevento: json['dtinicioevento']?.toString(),
      dtfimevento: json['dtfimevento']?.toString(),
      statusevento: json['statusevento']?.toString(),
      vrPrecoPadrao: double.tryParse('${json['vrprecolote'] ?? 0}') ?? 0,
      qtIngressosPadrao: int.tryParse('${json['qttotallote'] ?? ''}'),

      urlbannerevento: json['urlbannerevento']?.toString(),
      nmlocalevento: json['nmlocalevento']?.toString(),
      dsendlocevento: json['dsendlocevento']?.toString(),
    );
  }
}
