class EventoLote {
  final int loteId;
  final int? loteGlobalId;
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
  final double percentualCotaLegal;
  final int quantidadeCotaLegalLote;
  final int quantidadeVendidaCotaLegal;
  final int quantidadeReservadaCotaLegal;
  final int? qttotallote;
  final int qtvendidalote;
  final int qtReservadaLote;
  final int? qtCapacidadeSetor;
  final int? qtCapacidadeRestante;
  final String? dtiniciovenda;
  final String? dtfimvenda;
  final String? statuslote;
  final String? gatilhoVirada;

  EventoLote({
    required this.loteId,
    this.loteGlobalId,
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
    this.percentualCotaLegal = 40,
    this.quantidadeCotaLegalLote = 0,
    this.quantidadeVendidaCotaLegal = 0,
    this.quantidadeReservadaCotaLegal = 0,
    required this.qttotallote,
    required this.qtvendidalote,
    this.qtReservadaLote = 0,
    this.qtCapacidadeSetor,
    this.qtCapacidadeRestante,
    this.dtiniciovenda,
    this.dtfimvenda,
    this.statuslote,
    this.gatilhoVirada,
  });

  factory EventoLote.fromJson(Map<String, dynamic> json) {
    final precos = (json['precos'] as List? ?? const [])
        .map((e) => EventoLotePreco.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final inteira = precos.where((e) => e.tipo == 'INTEIRA').firstOrNull;
    return EventoLote(
      loteId: json['lote_id'] ?? 0,
      loteGlobalId: (json['loteglobal_id'] as num?)?.toInt(),
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
      percentualCotaLegal:
          (json['percentualcotalegal'] as num?)?.toDouble() ?? 40,
      quantidadeCotaLegalLote:
          (json['qtlimitecotalegal'] as num?)?.toInt() ?? 0,
      quantidadeVendidaCotaLegal:
          (json['qtvendidacotalegal'] as num?)?.toInt() ?? 0,
      quantidadeReservadaCotaLegal:
          (json['qtreservadacotalegal'] as num?)?.toInt() ?? 0,
      qttotallote: (json['qttotallote'] as num?)?.toInt(),
      qtvendidalote: (json['qtvendidalote'] as num?)?.toInt() ?? 0,
      qtReservadaLote: (json['qtreservadalote'] as num?)?.toInt() ?? 0,
      qtCapacidadeSetor: (json['qtcapacidade_setor'] as num?)?.toInt(),
      qtCapacidadeRestante: (json['qtcapacidaderestante'] as num?)?.toInt(),
      dtiniciovenda: json['dtiniciovenda']?.toString(),
      dtfimvenda: json['dtfimvenda']?.toString(),
      statuslote: json['statuslote']?.toString(),
      gatilhoVirada: json['gatilhovirada']?.toString(),
    );
  }
}

class EventoLoteGlobal {
  final int id;
  final int numero;
  final String nome;
  final String? inicioVendas;
  final String? fimVendas;
  final String gatilhoVirada;
  final String situacao;
  final bool disponivelGlobalmente;
  final List<EventoLote> setores;

  const EventoLoteGlobal({
    required this.id,
    required this.numero,
    required this.nome,
    required this.inicioVendas,
    required this.fimVendas,
    required this.gatilhoVirada,
    required this.situacao,
    required this.disponivelGlobalmente,
    required this.setores,
  });

  factory EventoLoteGlobal.fromJson(Map<String, dynamic> json) =>
      EventoLoteGlobal(
        id: (json['loteglobal_id'] as num?)?.toInt() ?? 0,
        numero: (json['nrlote'] as num?)?.toInt() ?? 1,
        nome: '${json['nmlote'] ?? ''}',
        inicioVendas: json['dtiniciovenda']?.toString(),
        fimVendas: json['dtfimvenda']?.toString(),
        gatilhoVirada: '${json['gatilhovirada'] ?? 'HIBRIDO'}',
        situacao: '${json['situacao'] ?? 'ATIVO'}',
        disponivelGlobalmente: json['disponivel_globalmente'] == true,
        setores: (json['setores'] as List? ?? const [])
            .map((item) => EventoLote.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
}

class EventoLotePreco {
  final int id;
  final int modalidadeId;
  final String nome;
  final String tipo;
  final double valor;
  final bool aplicaCotaLegal;
  final bool exigeComprovante;
  final String situacao;
  final int ordem;
  const EventoLotePreco({
    required this.id,
    required this.modalidadeId,
    required this.nome,
    required this.tipo,
    required this.valor,
    required this.aplicaCotaLegal,
    required this.exigeComprovante,
    this.situacao = 'ATIVO',
    this.ordem = 0,
  });
  factory EventoLotePreco.fromJson(Map<String, dynamic> j) => EventoLotePreco(
    id: (j['lotepreco_id'] as num?)?.toInt() ?? 0,
    modalidadeId: (j['modalidade_id'] as num?)?.toInt() ?? 0,
    nome: '${j['nmpreco'] ?? ''}',
    tipo: '${j['tipopreco'] ?? ''}',
    valor: (j['vrpreco'] as num?)?.toDouble() ?? 0,
    aplicaCotaLegal: j['aplicacotalegal'] == true,
    exigeComprovante: j['exigecomprovante'] == true,
    situacao: '${j['situacao'] ?? 'ATIVO'}',
    ordem: (j['nrordem'] as num?)?.toInt() ?? 0,
  );
}

class ModalidadeIngressoCatalogo {
  final int id;
  final String codigo;
  final String nome;
  final String tipo;
  final bool aplicaCotaLegal;
  final bool exigeBeneficio;
  final bool exigeComprovante;
  final bool permitePersonalizarNome;
  final int ordem;

  const ModalidadeIngressoCatalogo({
    required this.id,
    required this.codigo,
    required this.nome,
    required this.tipo,
    required this.aplicaCotaLegal,
    required this.exigeBeneficio,
    required this.exigeComprovante,
    required this.permitePersonalizarNome,
    required this.ordem,
  });

  factory ModalidadeIngressoCatalogo.fromJson(Map<String, dynamic> json) =>
      ModalidadeIngressoCatalogo(
        id: (json['modalidade_id'] as num?)?.toInt() ?? 0,
        codigo: '${json['cdmodalidade'] ?? ''}',
        nome: '${json['nmmodalidade'] ?? ''}',
        tipo: '${json['tipomodalidade'] ?? 'COMERCIAL'}',
        aplicaCotaLegal: json['aplicacotalegal'] == true,
        exigeBeneficio: json['exigebeneficio'] == true,
        exigeComprovante: json['exigecomprovante'] == true,
        permitePersonalizarNome: json['permitepersonalizarnome'] == true,
        ordem: (json['nrordem'] as num?)?.toInt() ?? 0,
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

class CapacidadeEvento {
  final int? capacidadeTotal;
  final int capacidadeSetores;
  final int? capacidadeNaoDistribuida;

  const CapacidadeEvento({
    required this.capacidadeTotal,
    required this.capacidadeSetores,
    required this.capacidadeNaoDistribuida,
  });

  factory CapacidadeEvento.fromJson(Map<String, dynamic> json) =>
      CapacidadeEvento(
        capacidadeTotal: (json['qtcapacidadeevento'] as num?)?.toInt(),
        capacidadeSetores: (json['qtcapacidade_setores'] as num?)?.toInt() ?? 0,
        capacidadeNaoDistribuida: (json['qtcapacidade_nao_distribuida'] as num?)
            ?.toInt(),
      );
}
