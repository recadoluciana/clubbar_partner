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
  final List<EventoLotePreco> precos;
  final int cotaLegal;
  final int quantidadeVendidaCotaLegal;
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
    this.precos = const [],
    this.cotaLegal = 0,
    this.quantidadeVendidaCotaLegal = 0,
    required this.qttotallote,
    required this.qtvendidalote,
    this.dtiniciovenda,
    this.dtfimvenda,
    this.statuslote,
  });

  factory EventoLote.fromJson(Map<String, dynamic> json) {
    final precos = (json['precos'] as List? ?? const [])
        .map((e) => EventoLotePreco.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final inteira = precos.where((e) => e.tipo == 'INTEIRA').firstOrNull;
    return EventoLote(
      loteId: json['lote_id'] ?? 0,
      organizacaoId: json['organizacao_id'],
      lojaId: json['loja_id'],
      eventoId: json['evento_id'],
      nmlote: (json['nmlote'] ?? '').toString(),
      eventoSetorId: (json['eventosetor_id'] as num?)?.toInt(),
      nomeSetor: json['nmsetor']?.toString(),
      numeroLote: (json['nrlote'] as num?)?.toInt() ?? 1,
      tipoIngresso: 'COMPARTILHADO',
      vrprecolote: inteira?.valor ?? (precos.isEmpty ? 0 : precos.first.valor),
      precos: precos,
      cotaLegal: (json['cotalegal'] as num?)?.toInt() ?? 0,
      quantidadeVendidaCotaLegal:
          (json['qtvendidacotalegal'] as num?)?.toInt() ?? 0,
      qttotallote: (json['qttotallote'] as num?)?.toInt() ?? 0,
      qtvendidalote: (json['qtvendidalote'] as num?)?.toInt() ?? 0,
      dtiniciovenda: json['dtiniciovenda']?.toString(),
      dtfimvenda: json['dtfimvenda']?.toString(),
      statuslote: json['statuslote']?.toString(),
    );
  }
}

class EventoLotePreco {
  final int id;
  final String nome;
  final String tipo;
  final double valor;
  final bool aplicaCotaLegal;
  final bool exigeComprovante;
  const EventoLotePreco({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.valor,
    required this.aplicaCotaLegal,
    required this.exigeComprovante,
  });
  factory EventoLotePreco.fromJson(Map<String, dynamic> j) => EventoLotePreco(
    id: (j['lotepreco_id'] as num?)?.toInt() ?? 0,
    nome: '${j['nmpreco'] ?? ''}',
    tipo: '${j['tipopreco'] ?? ''}',
    valor: (j['vrpreco'] as num?)?.toDouble() ?? 0,
    aplicaCotaLegal: j['aplicacotalegal'] == true,
    exigeComprovante: j['exigecomprovante'] == true,
  );
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
