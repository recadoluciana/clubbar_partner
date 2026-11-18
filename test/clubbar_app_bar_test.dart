import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clubbar_partner/core/widgets/clubbar_app_bar.dart';

void main() {
  testWidgets('mostra título e aciona atualização sem exibir a marca', (
    tester,
  ) async {
    var atualizacoes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: ClubbarAppBar(
            mostrarVoltar: true,
            titulo: 'Ingressos vendidos',
            actions: [
              IconButton(
                tooltip: 'Atualizar',
                onPressed: () => atualizacoes++,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Ingressos vendidos'), findsOneWidget);
    expect(find.text('Clubbar Partner'), findsNothing);
    await tester.tap(find.byTooltip('Atualizar'));
    expect(atualizacoes, 1);
  });
}
