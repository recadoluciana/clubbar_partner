import 'package:clubbar_partner/core/widgets/app_snackbar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('troca falha de fetch por mensagem amigável', () {
    expect(
      AppSnackBar.mensagemSegura(
        'ClientFailed to fetch, uri=https://api.clubbar.com.br/eventos-modelos',
      ),
      'Sem conexão com a internet ou servidor indisponível.',
    );
  });

  test('preserva mensagem de regra de negócio', () {
    expect(
      AppSnackBar.mensagemSegura('Este evento já foi encerrado.'),
      'Este evento já foi encerrado.',
    );
  });
}
