import 'package:clubbar_partner/core/widgets/app_snackbar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSnackBar.mensagemSegura', () {
    test('preserva mensagem clara de regra de negócio', () {
      expect(
        AppSnackBar.mensagemSegura('Este produto não está mais disponível.'),
        'Este produto não está mais disponível.',
      );
    });

    test('oculta detalhe técnico da infraestrutura', () {
      expect(
        AppSnackBar.mensagemSegura('MySQL server has gone away'),
        'Não foi possível concluir a operação agora. Tente novamente em instantes.',
      );
    });

    test('oculta respostas JSON brutas', () {
      expect(
        AppSnackBar.mensagemSegura('{"detail":"Internal Server Error"}'),
        'Não foi possível concluir a operação agora. Tente novamente em instantes.',
      );
    });

    test('traduz tempo limite de conexão', () {
      expect(
        AppSnackBar.mensagemSegura('TimeoutException: Tempo limite'),
        'O servidor demorou para responder. Tente novamente.',
      );
    });
  });
}
