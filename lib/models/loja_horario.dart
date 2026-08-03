import 'package:flutter/material.dart';

class LojaHorario {
  final int? lojaHorarioId;
  final int lojaId;
  final int diaSemana;
  final bool fechado;
  final TimeOfDay? horaAbertura;
  final TimeOfDay? horaFechamento;
  final bool fechaDiaSeguinte;
  final bool fechamentoMeiaNoite;

  const LojaHorario({
    this.lojaHorarioId,
    required this.lojaId,
    required this.diaSemana,
    required this.fechado,
    this.horaAbertura,
    this.horaFechamento,
    this.fechaDiaSeguinte = false,
    this.fechamentoMeiaNoite = false,
  });

  factory LojaHorario.fromJson(Map<String, dynamic> json) {
    return LojaHorario(
      lojaHorarioId: _toNullableInt(
        json['lojahorario_id'] ?? json['loja_horario_id'],
      ),
      lojaId: _toInt(json['loja_id']),
      diaSemana: _toInt(json['diasemana'] ?? json['dia_semana']),
      fechado: _toBool(json['fechado']),
      horaAbertura: _toTimeOfDay(json['horaabertura'] ?? json['hora_abertura']),
      horaFechamento: _toTimeOfDay(
        json['horafechamento'] ??
            json['horafuncionamento'] ??
            json['hora_fechamento'],
      ),
      fechamentoMeiaNoite: _isMeiaNoite24(
        json['horafechamento'] ??
            json['horafuncionamento'] ??
            json['hora_fechamento'],
      ),
      fechaDiaSeguinte: _toBool(
        json['fechadiaseguinte'] ??
            json['fechamento_dia_seguinte'] ??
            json['fecha_dia_seguinte'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (lojaHorarioId != null) 'lojahorario_id': lojaHorarioId,
      'loja_id': lojaId,
      'diasemana': diaSemana,
      'fechado': fechado,
      'horaabertura': fechado ? null : _formatarHora(horaAbertura),
      'horafechamento': fechado
          ? null
          : fechamentoMeiaNoite
          ? '24:00'
          : _formatarHora(horaFechamento),
      'fechadiaseguinte': fechado ? false : fechaDiaSeguinte,
    };
  }

  String get nomeDiaSemana {
    const nomes = <int, String>{
      1: 'Segunda-feira',
      2: 'Terça-feira',
      3: 'Quarta-feira',
      4: 'Quinta-feira',
      5: 'Sexta-feira',
      6: 'Sábado',
      7: 'Domingo',
    };

    return nomes[diaSemana] ?? 'Dia inválido';
  }

  LojaHorario copyWith({
    int? lojaHorarioId,
    int? lojaId,
    int? diaSemana,
    bool? fechado,
    TimeOfDay? horaAbertura,
    TimeOfDay? horaFechamento,
    bool? fechaDiaSeguinte,
    bool? fechamentoMeiaNoite,
    bool limparHorarios = false,
  }) {
    return LojaHorario(
      lojaHorarioId: lojaHorarioId ?? this.lojaHorarioId,
      lojaId: lojaId ?? this.lojaId,
      diaSemana: diaSemana ?? this.diaSemana,
      fechado: fechado ?? this.fechado,
      horaAbertura: limparHorarios ? null : horaAbertura ?? this.horaAbertura,
      horaFechamento: limparHorarios
          ? null
          : horaFechamento ?? this.horaFechamento,
      fechaDiaSeguinte: limparHorarios
          ? false
          : fechaDiaSeguinte ?? this.fechaDiaSeguinte,
      fechamentoMeiaNoite: limparHorarios
          ? false
          : fechamentoMeiaNoite ?? this.fechamentoMeiaNoite,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    switch (value?.toString().trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'sim':
      case 'yes':
        return true;
      default:
        return false;
    }
  }

  static TimeOfDay? _toTimeOfDay(dynamic value) {
    final texto = value?.toString().trim() ?? '';
    if (texto.isEmpty) return null;

    final partes = texto.split(':');
    if (partes.length < 2) return null;

    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);
    if (hora == null ||
        minuto == null ||
        hora < 0 ||
        hora > 24 ||
        minuto < 0 ||
        minuto > 59 ||
        (hora == 24 && minuto != 0)) {
      return null;
    }

    return TimeOfDay(hour: hora == 24 ? 0 : hora, minute: minuto);
  }

  static bool _isMeiaNoite24(dynamic value) {
    final partes = value?.toString().trim().split(':') ?? const <String>[];
    if (partes.length < 2) return false;
    return int.tryParse(partes[0]) == 24 && int.tryParse(partes[1]) == 0;
  }

  static String? _formatarHora(TimeOfDay? value) {
    if (value == null) return null;
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}
