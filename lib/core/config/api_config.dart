import 'package:flutter/services.dart';

class ApiConfig {
  static const String _apiDesenvolvimento =
      'https://apiclubbar-desenvolvimento.up.railway.app';

  static const String _apiProducao = 'https://api.clubbar.com.br';

  static String get ambiente {
    switch (appFlavor) {
      case 'dev':
        return 'DESENVOLVIMENTO';

      case 'prod':
        return 'PRODUÇÃO';

      default:
        return 'NÃO DEFINIDO';
    }
  }

  static bool get isDev => appFlavor == 'dev';

  static bool get isProd => appFlavor == 'prod';

  static String get baseUrl {
    /*
     * Permite sobrescrever a URL manualmente, caso seja necessário.
     *
     * Exemplo:
     * --dart-define=API_BASE_URL=https://outra-api.com.br
     */
    const urlInformada = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );

    if (urlInformada.trim().isNotEmpty) {
      return _removerBarraFinal(urlInformada.trim());
    }

    switch (appFlavor) {
      case 'dev':
        return _apiDesenvolvimento;

      case 'prod':
        return _apiProducao;

      default:
        /*
         * Esse fallback ajuda quando você roda o Flutter Web,
         * pois o flavor Android pode não estar definido.
         */
        return _apiProducao;
    }
  }

  static String get nomeApp {
    switch (appFlavor) {
      case 'dev':
        return 'Clubbar Parceiro Dev';

      case 'prod':
        return 'Clubbar Parceiro';

      default:
        return 'Clubbar Parceiro';
    }
  }

  static String buildUrl(String path) {
    final texto = path.trim();

    if (texto.isEmpty) {
      return '';
    }

    if (texto.startsWith('http://') || texto.startsWith('https://')) {
      return texto;
    }

    final caminho = texto.startsWith('/') ? texto : '/$texto';

    return '$baseUrl$caminho';
  }

  static String _removerBarraFinal(String valor) {
    var resultado = valor;

    while (resultado.endsWith('/')) {
      resultado = resultado.substring(0, resultado.length - 1);
    }

    return resultado;
  }
}
