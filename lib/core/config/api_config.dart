class ApiConfig {
  static const String baseUrl = 'https://api.clubbar.com.br';

  static const String nomeApp = 'Clubbar';

  static String buildUrl(String path) {
    final texto = path.trim();

    if (texto.isEmpty) return '';
    if (texto.startsWith('http')) return texto;

    return '$baseUrl${texto.startsWith('/') ? '' : '/'}$texto';
  }
}
