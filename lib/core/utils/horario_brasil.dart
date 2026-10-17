/// Datas e horas de referência do Clubbar no fuso de São Paulo (UTC-03:00).
///
/// O Partner também é usado pela web. Nesse caso, o fuso do navegador pode
/// não ser o mesmo do estabelecimento, por isso o relógio e os timestamps de
/// venda são normalizados antes de serem exibidos.
class HorarioBrasil {
  static const _deslocamentoUtc = Duration(hours: -3);

  /// Retorna o horário atual de Brasília, independentemente do fuso do aparelho.
  static DateTime agora() => _comoDataLocal(DateTime.now().toUtc());

  /// Converte um timestamp UTC em uma data civil do horário de Brasília.
  static DateTime deUtc(DateTime valor) => _comoDataLocal(valor.toUtc());

  /// Lê timestamps de venda da API. Valores sem sufixo de fuso são legados
  /// gravados em UTC no banco e, portanto, também são tratados como UTC.
  static DateTime? deTextoUtc(Object? valor) {
    final texto = valor?.toString().trim() ?? '';
    if (texto.isEmpty) return null;
    final possuiFuso = RegExp(
      r'(Z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(texto);
    final data = DateTime.tryParse(possuiFuso ? texto : '${texto}Z');
    return data == null ? null : deUtc(data);
  }

  static DateTime _comoDataLocal(DateTime utc) {
    final brasil = utc.add(_deslocamentoUtc);
    return DateTime(
      brasil.year,
      brasil.month,
      brasil.day,
      brasil.hour,
      brasil.minute,
      brasil.second,
      brasil.millisecond,
      brasil.microsecond,
    );
  }
}
