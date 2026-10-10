import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Padroniza o cabeçalho dos seletores de data do Partner.
class ClubbarCalendarDelegate extends GregorianCalendarDelegate {
  const ClubbarCalendarDelegate();

  static const _diasDaSemana = [
    'segunda',
    'terça',
    'quarta',
    'quinta',
    'sexta',
    'sábado',
    'domingo',
  ];

  @override
  String formatMediumDate(DateTime date, MaterialLocalizations localizations) {
    final diaDaSemana = _diasDaSemana[date.weekday - 1];
    final dia = date.day.toString().padLeft(2, '0');
    final mes = DateFormat('MMMM', 'pt_BR').format(date).toLowerCase();
    return '$diaDaSemana $dia de $mes';
  }
}
