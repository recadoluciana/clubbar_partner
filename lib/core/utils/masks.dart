// lib/core/utils/masks.dart

import 'package:flutter/services.dart';

class DecimalInputFormatter extends TextInputFormatter {
  final int casasDecimais;

  const DecimalInputFormatter({this.casasDecimais = 2});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var texto = newValue.text
        .replaceAll('.', ',')
        .replaceAll(RegExp(r'[^0-9,]'), '');

    final primeiraVirgula = texto.indexOf(',');
    if (primeiraVirgula >= 0) {
      final inteiro = texto.substring(0, primeiraVirgula);
      final decimal = texto.substring(primeiraVirgula + 1).replaceAll(',', '');
      texto =
          '$inteiro,${decimal.substring(0, decimal.length.clamp(0, casasDecimais))}';
    }

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var numeros = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.length > 11) {
      numeros = numeros.substring(0, 11);
    }

    String texto;

    if (numeros.isEmpty) {
      texto = '';
    } else if (numeros.length <= 2) {
      texto = '($numeros';
    } else if (numeros.length <= 6) {
      texto = '(${numeros.substring(0, 2)}) ${numeros.substring(2)}';
    } else if (numeros.length <= 10) {
      texto =
          '(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 6)}-'
          '${numeros.substring(6)}';
    } else {
      texto =
          '(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 7)}-'
          '${numeros.substring(7)}';
    }

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

class CnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var numeros = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.length > 14) {
      numeros = numeros.substring(0, 14);
    }

    final buffer = StringBuffer();

    for (var i = 0; i < numeros.length; i++) {
      if (i == 2 || i == 5) {
        buffer.write('.');
      }

      if (i == 8) {
        buffer.write('/');
      }

      if (i == 12) {
        buffer.write('-');
      }

      buffer.write(numeros[i]);
    }

    final texto = buffer.toString();

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

class CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var numeros = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.length > 8) {
      numeros = numeros.substring(0, 8);
    }

    final texto = numeros.length <= 5
        ? numeros
        : '${numeros.substring(0, 5)}-${numeros.substring(5)}';

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Máscara de CPF (000.000.000-00)
class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var numeros = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.length > 11) {
      numeros = numeros.substring(0, 11);
    }

    final buffer = StringBuffer();

    for (var i = 0; i < numeros.length; i++) {
      if (i == 3 || i == 6) {
        buffer.write('.');
      }

      if (i == 9) {
        buffer.write('-');
      }

      buffer.write(numeros[i]);
    }

    final texto = buffer.toString();

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
