class AuditoriaItem {
  final int id;
  final int? organizacaoId;
  final int? lojaId;
  final String tabela;
  final String registroId;
  final String acao;
  final String atorTipo;
  final String atorNome;
  final String? atorEmail;
  final Map<String, dynamic>? dadosAnteriores;
  final Map<String, dynamic>? dadosNovos;
  final String? metodoHttp;
  final String? rota;
  final DateTime dataCriacao;

  const AuditoriaItem({
    required this.id,
    this.organizacaoId,
    this.lojaId,
    required this.tabela,
    required this.registroId,
    required this.acao,
    required this.atorTipo,
    required this.atorNome,
    this.atorEmail,
    this.dadosAnteriores,
    this.dadosNovos,
    this.metodoHttp,
    this.rota,
    required this.dataCriacao,
  });

  factory AuditoriaItem.fromJson(Map<String, dynamic> json) => AuditoriaItem(
    id: int.tryParse('${json['auditoria_id'] ?? 0}') ?? 0,
    organizacaoId: int.tryParse('${json['organizacao_id'] ?? ''}'),
    lojaId: int.tryParse('${json['loja_id'] ?? ''}'),
    tabela: '${json['tabela'] ?? ''}',
    registroId: '${json['registro_id'] ?? ''}',
    acao: '${json['acao'] ?? ''}',
    atorTipo: '${json['ator_tipo'] ?? ''}',
    atorNome: '${json['ator_nome'] ?? ''}',
    atorEmail: json['ator_email']?.toString(),
    dadosAnteriores: json['dados_anteriores'] is Map
        ? Map<String, dynamic>.from(json['dados_anteriores'] as Map)
        : null,
    dadosNovos: json['dados_novos'] is Map
        ? Map<String, dynamic>.from(json['dados_novos'] as Map)
        : null,
    metodoHttp: json['metodo_http']?.toString(),
    rota: json['rota']?.toString(),
    dataCriacao:
        DateTime.tryParse('${json['dtcriacao'] ?? ''}') ?? DateTime.now(),
  );
}
