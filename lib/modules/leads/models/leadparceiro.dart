class LeadParceiro {
  final int leadparceiroId;
  final String nmresponsavel;
  final String nmestabelecimento;
  final String tipo;
  final String telefone;
  final String email;
  final int estadoId;
  final int cidadeId;
  final String nmestado;
  final String sgestado;
  final String nmcidade;
  final String? mensagem;
  final String status;
  final DateTime dtcriacao;
  final DateTime? dtultatu;
  final int diasEspera;

  const LeadParceiro({
    required this.leadparceiroId,
    required this.nmresponsavel,
    required this.nmestabelecimento,
    required this.tipo,
    required this.telefone,
    required this.email,
    required this.estadoId,
    required this.cidadeId,
    required this.nmestado,
    required this.sgestado,
    required this.nmcidade,
    required this.mensagem,
    required this.status,
    required this.dtcriacao,
    required this.dtultatu,
    required this.diasEspera,
  });

  factory LeadParceiro.fromJson(Map<String, dynamic> json) {
    return LeadParceiro(
      leadparceiroId: _toInt(json['leadparceiro_id']),
      nmresponsavel: json['nmresponsavel']?.toString() ?? '',
      nmestabelecimento: json['nmestabelecimento']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? '',
      telefone: json['telefone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      estadoId: _toInt(json['estado_id']),
      cidadeId: _toInt(json['cidade_id']),
      nmestado: json['nmestado']?.toString() ?? '',
      sgestado: json['sgestado']?.toString() ?? '',
      nmcidade: json['nmcidade']?.toString() ?? '',
      mensagem: json['mensagem']?.toString(),
      status: json['status']?.toString() ?? 'NOVO',
      dtcriacao: _toDateTime(json['dtcriacao']),
      dtultatu: _toNullableDateTime(json['dtultatu']),
      diasEspera: _toInt(json['dias_espera']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _toDateTime(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
