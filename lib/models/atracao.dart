class Atracao {
  final int atracaoId;
  final int organizacaoId;
  final String nome;
  final String? estiloMusical;
  final String? banner;
  final String? descricao;
  final List<EstiloMusical> estilos;

  const Atracao({
    required this.atracaoId,
    required this.organizacaoId,
    required this.nome,
    this.estiloMusical,
    this.banner,
    this.descricao,
    this.estilos = const [],
  });
  factory Atracao.fromJson(Map<String, dynamic> j) {
    final estilos = (j['estilos'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => EstiloMusical.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return Atracao(
      atracaoId: int.tryParse('${j['atracao_id'] ?? 0}') ?? 0,
      organizacaoId: int.tryParse('${j['organizacao_id'] ?? 0}') ?? 0,
      nome: '${j['nmatracao'] ?? ''}',
      estiloMusical: estilos.isNotEmpty
          ? estilos.map((e) => e.nome).join(', ')
          : j['dsestilomusical']?.toString(),
      banner: j['urlbanneratracao']?.toString(),
      descricao: j['dsatracao']?.toString(),
      estilos: estilos,
    );
  }
}

class EstiloMusical {
  final int id;
  final String nome;
  final String situacao;
  final String origem;

  const EstiloMusical({
    required this.id,
    required this.nome,
    this.situacao = 'ATIVO',
    this.origem = 'PERSONALIZADO',
  });

  factory EstiloMusical.fromJson(Map<String, dynamic> json) => EstiloMusical(
    id: int.tryParse('${json['estilomusical_id'] ?? 0}') ?? 0,
    nome: '${json['nmestilomusical'] ?? ''}',
    situacao: '${json['sitestilomusical'] ?? 'ATIVO'}'.toUpperCase(),
    origem: '${json['origem'] ?? 'CATALOGO'}'.toUpperCase(),
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

class EventoModeloAtracao {
  final int id;
  final int modeloId;
  final int atracaoId;
  final int ordem;
  final int minutoInicio;
  final int minutoDuracao;
  final String nomeAtracao;

  const EventoModeloAtracao({
    required this.id,
    required this.modeloId,
    required this.atracaoId,
    required this.ordem,
    required this.minutoInicio,
    required this.minutoDuracao,
    required this.nomeAtracao,
  });

  factory EventoModeloAtracao.fromJson(Map<String, dynamic> j) =>
      EventoModeloAtracao(
        id: int.tryParse('${j['eventomodeloatracao_id'] ?? 0}') ?? 0,
        modeloId: int.tryParse('${j['eventomodelo_id'] ?? 0}') ?? 0,
        atracaoId: int.tryParse('${j['atracao_id'] ?? 0}') ?? 0,
        ordem: int.tryParse('${j['ordem'] ?? 1}') ?? 1,
        minutoInicio: int.tryParse('${j['nrminutoinicio'] ?? 0}') ?? 0,
        minutoDuracao: int.tryParse('${j['nrminutoduracao'] ?? 120}') ?? 120,
        nomeAtracao: '${(j['atracao'] as Map?)?['nmatracao'] ?? ''}',
      );
}

class AgendaEvento {
  final int eventoId;
  final String titulo;
  final DateTime inicio;
  final DateTime? fim;
  final String status;
  final List<EventoAtracao> atracoes;
  final String? bannerEvento;
  const AgendaEvento({
    required this.eventoId,
    required this.titulo,
    required this.inicio,
    this.fim,
    required this.status,
    required this.atracoes,
    this.bannerEvento,
  });
  factory AgendaEvento.fromJson(Map<String, dynamic> j) {
    final atracoes =
        (j['atracoes'] as List? ?? const [])
            .map(
              (e) =>
                  EventoAtracao.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList()
          ..sort((a, b) => a.inicio.compareTo(b.inicio));
    return AgendaEvento(
      eventoId: int.tryParse('${j['evento_id'] ?? 0}') ?? 0,
      titulo: '${j['nmtituloevento'] ?? ''}',
      inicio: DateTime.parse(j['dtinicioevento'].toString()),
      fim: j['dtfimevento'] == null
          ? null
          : DateTime.tryParse(j['dtfimevento'].toString()),
      status: '${j['statusevento'] ?? ''}',
      bannerEvento: j['urlbannerevento']?.toString(),
      atracoes: atracoes,
    );
  }
}
