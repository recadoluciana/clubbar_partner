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

  /// Lê valores devolvidos pela API. Datas sem sufixo representam o horário
  /// civil brasileiro; timestamps com `Z` ou offset são convertidos para ele.
  static DateTime? deTextoBrasil(Object? valor) {
    final texto = valor?.toString().trim() ?? '';
    if (texto.isEmpty) return null;
    final possuiFuso = RegExp(
      r'(Z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(texto);
    final data = DateTime.tryParse(texto);
    if (data == null) return null;
    return possuiFuso ? deUtc(data) : data;
  }

  /// Lê timestamps UTC legados que não vieram com o sufixo de fuso.
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
