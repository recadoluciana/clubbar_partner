class Atracao {
  final int atracaoId;
  final int organizacaoId;
  final String nome;
  final String? estiloMusical;
  final String? banner;
  final String? descricao;

  const Atracao({
    required this.atracaoId,
    required this.organizacaoId,
    required this.nome,
    this.estiloMusical,
    this.banner,
    this.descricao,
  });
  factory Atracao.fromJson(Map<String, dynamic> j) => Atracao(
    atracaoId: int.tryParse('${j['atracao_id'] ?? 0}') ?? 0,
    organizacaoId: int.tryParse('${j['organizacao_id'] ?? 0}') ?? 0,
    nome: '${j['nmatracao'] ?? ''}',
    estiloMusical: j['dsestilomusical']?.toString(),
    banner: j['urlbanneratracao']?.toString(),
    descricao: j['dsatracao']?.toString(),
  );
}

class EventoAtracao {
  final int programacaoId;
  final int eventoId;
  final DateTime inicio;
  final DateTime fim;
  final Atracao atracao;
  const EventoAtracao({
    required this.programacaoId,
    required this.eventoId,
    required this.inicio,
    required this.fim,
    required this.atracao,
  });
  factory EventoAtracao.fromJson(Map<String, dynamic> j) => EventoAtracao(
    programacaoId: int.tryParse('${j['eventoatracao_id'] ?? 0}') ?? 0,
    eventoId: int.tryParse('${j['evento_id'] ?? 0}') ?? 0,
    inicio: DateTime.parse(j['dtinicioatracao'].toString()),
    fim: DateTime.parse(j['dtfimatracao'].toString()),
    atracao: Atracao.fromJson(Map<String, dynamic>.from(j['atracao'] as Map)),
  );
}

class AgendaEvento {
  final int eventoId;
  final String titulo;
  final DateTime inicio;
  final DateTime? fim;
  final String status;
  final List<EventoAtracao> atracoes;
  const AgendaEvento({
    required this.eventoId,
    required this.titulo,
    required this.inicio,
    this.fim,
    required this.status,
    required this.atracoes,
  });
  factory AgendaEvento.fromJson(Map<String, dynamic> j) => AgendaEvento(
    eventoId: int.tryParse('${j['evento_id'] ?? 0}') ?? 0,
    titulo: '${j['nmtituloevento'] ?? ''}',
    inicio: DateTime.parse(j['dtinicioevento'].toString()),
    fim: j['dtfimevento'] == null
        ? null
        : DateTime.tryParse(j['dtfimevento'].toString()),
    status: '${j['statusevento'] ?? ''}',
    atracoes: (j['atracoes'] as List? ?? const [])
        .map((e) => EventoAtracao.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}
