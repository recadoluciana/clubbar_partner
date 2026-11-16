import 'package:clubbar_partner/models/acompanhamento_vendas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mostra a compra UTC no dia e horário de Brasília', () {
    final compra = CompraProduto.fromJson({
      'itvenda_id': 1,
      'venda_id': 34,
      'quantidade': 1,
      'dtcompra': '2026-11-16T00:53:57Z',
    });
    expect(compra.dataCompra, DateTime(2026, 11, 15, 21, 53, 57));
  });
}
