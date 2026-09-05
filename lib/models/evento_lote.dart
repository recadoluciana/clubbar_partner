class EventoLote {
  final int loteId;
  final int? organizacaoId;
  final int? lojaId;
  final int? eventoId;
  final String nmlote;
  final int? eventoSetorId;
  final String? nomeSetor;
  final int numeroLote;
  final String tipoIngresso;
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
    this.eventoSetorId,
    this.nomeSetor,
    this.numeroLote = 1,
    this.tipoIngresso = 'UNICO',
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
      eventoSetorId: (json['eventosetor_id'] as num?)?.toInt(),
      nomeSetor: json['nmsetor']?.toString(),
      numeroLote: (json['nrlote'] as num?)?.toInt() ?? 1,
      tipoIngresso: (json['tipoingresso'] ?? 'UNICO').toString(),
      vrprecolote: (json['vrprecolote'] as num?)?.toDouble() ?? 0,
      qttotallote: (json['qttotallote'] as num?)?.toInt() ?? 0,
      qtvendidalote: (json['qtvendidalote'] as num?)?.toInt() ?? 0,
      dtiniciovenda: json['dtiniciovenda']?.toString(),
      dtfimvenda: json['dtfimvenda']?.toString(),
      statuslote: json['statuslote']?.toString(),
    );
  }
}

class EventoSetor {
  final int id;
  final String nome;
  final String descricao;
  final int capacidade;
  final int ordem;
  final String situacao;

  const EventoSetor({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.capacidade,
    required this.ordem,
    required this.situacao,
  });
  factory EventoSetor.fromJson(Map<String, dynamic> json) => EventoSetor(
    id: (json['eventosetor_id'] as num?)?.toInt() ?? 0,
    nome: '${json['nmsetor'] ?? ''}',
    descricao: '${json['dssetor'] ?? ''}',
    capacidade: (json['qtcapacidade'] as num?)?.toInt() ?? 0,
    ordem: (json['nrordem'] as num?)?.toInt() ?? 1,
    situacao: '${json['sitsetor'] ?? 'ATIVO'}',
  );
}
