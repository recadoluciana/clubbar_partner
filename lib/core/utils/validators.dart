// lib/core/utils/validators.dart

class Validators {
  Validators._();

  static String somenteNumeros(String valor) {
    return valor.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static bool cnpjValido(String valor) {
    final cnpj = somenteNumeros(valor);

    if (cnpj.length != 14) return false;

    if (RegExp(r'^(\d)\1{13}$').hasMatch(cnpj)) {
      return false;
    }

    int calcularDigito(String base, List<int> pesos) {
      var soma = 0;

      for (var i = 0; i < pesos.length; i++) {
        soma += int.parse(base[i]) * pesos[i];
      }

      final resto = soma % 11;

      return resto < 2 ? 0 : 11 - resto;
    }

    final primeiro = calcularDigito(cnpj.substring(0, 12), const [
      5,
      4,
      3,
      2,
      9,
      8,
      7,
      6,
      5,
      4,
      3,
      2,
    ]);

    final segundo = calcularDigito('${cnpj.substring(0, 12)}$primeiro', const [
      6,
      5,
      4,
      3,
      2,
      9,
      8,
      7,
      6,
      5,
      4,
      3,
      2,
    ]);

    return cnpj.endsWith('$primeiro$segundo');
  }

  static bool cpfValido(String valor) {
    final cpf = somenteNumeros(valor);

    if (cpf.length != 11) return false;

    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) {
      return false;
    }

    int calcularDigito(String base, int pesoInicial) {
      var soma = 0;
      var peso = pesoInicial;

      for (var i = 0; i < base.length; i++) {
        soma += int.parse(base[i]) * peso--;
      }

      final resto = soma % 11;

      return resto < 2 ? 0 : 11 - resto;
    }

    final primeiro = calcularDigito(cpf.substring(0, 9), 10);

    final segundo = calcularDigito('${cpf.substring(0, 9)}$primeiro', 11);

    return cpf.endsWith('$primeiro$segundo');
  }

  static bool emailValido(String email) {
    return RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(email.trim());
  }

  static bool telefoneValido(String telefone) {
    final numeros = somenteNumeros(telefone);

    return numeros.length == 10 || numeros.length == 11;
  }

  static bool cepValido(String cep) {
    return somenteNumeros(cep).length == 8;
  }
}
