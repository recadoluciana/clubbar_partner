import '../../core/utils/validators.dart';

class Formatters {
  Formatters._();

  static String cnpj(String valor) {
    final numeros = Validators.somenteNumeros(valor);

    if (numeros.length != 14) return valor;

    return '${numeros.substring(0, 2)}.'
        '${numeros.substring(2, 5)}.'
        '${numeros.substring(5, 8)}/'
        '${numeros.substring(8, 12)}-'
        '${numeros.substring(12)}';
  }

  static String telefone(String valor) {
    final numeros = Validators.somenteNumeros(valor);

    if (numeros.length == 11) {
      return '(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 7)}-'
          '${numeros.substring(7)}';
    }

    if (numeros.length == 10) {
      return '(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 6)}-'
          '${numeros.substring(6)}';
    }

    return valor;
  }

  static String cep(String valor) {
    final numeros = Validators.somenteNumeros(valor);

    if (numeros.length != 8) return valor;

    return '${numeros.substring(0, 5)}-'
        '${numeros.substring(5)}';
  }

  static String cpf(String valor) {
    final numeros = Validators.somenteNumeros(valor);

    if (numeros.length != 11) return valor;

    return '${numeros.substring(0, 3)}.'
        '${numeros.substring(3, 6)}.'
        '${numeros.substring(6, 9)}-'
        '${numeros.substring(9)}';
  }
}
