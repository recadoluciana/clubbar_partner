import 'package:clubbar_partner/models/painel_gerencial.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'ordena por valor antes de limitar o ranking sem alterar a lista original',
    () {
      final produtos = List.generate(
        7,
        (i) => ItemRankingGerencial(
          id: i,
          nome: 'Produto $i',
          quantidade: 10 - i,
          valor: i == 6 ? 100 : 10,
        ),
      );
      final resultado = produtosOrdenadosPorValor(produtos);
      expect(resultado.take(5).first.id, 6);
      expect(resultado.skip(1).map((p) => p.id), [0, 1, 2, 3, 4, 5]);
      expect(produtos.first.id, 0);
    },
  );
}
