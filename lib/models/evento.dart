class Evento {
  final int eventoId;
  final int organizacaoId;
  final int lojaId;
  final String nmtituloevento;

  final String? dsdescevento;
  final String? dspoliticacancelamento;
  final String? dspoliticareembolso;
  final String? dspoliticacashback;
  final String? dtinicioevento;
  final String? dtfimevento;
  final String? statusevento;

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
    this.dspoliticareembolso,
    this.dspoliticacashback,
    this.dtinicioevento,
    this.dtfimevento,
    this.statusevento,
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
      dspoliticareembolso: json['dspoliticareembolso']?.toString(),
      dspoliticacashback: json['dspoliticacashback']?.toString(),
      dtinicioevento: json['dtinicioevento']?.toString(),
      dtfimevento: json['dtfimevento']?.toString(),
      statusevento: json['statusevento']?.toString(),

      urlbannerevento: json['urlbannerevento']?.toString(),
      nmlocalevento: json['nmlocalevento']?.toString(),
      dsendlocevento: json['dsendlocevento']?.toString(),
    );
  }
}
