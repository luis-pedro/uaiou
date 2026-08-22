// Testes de fumaça do app.
//
// Substitui o template padrão do contador gerado pelo `flutter create`,
// que nunca rodou neste projeto: ele testava um contador inexistente e
// tinha um import com caminho absoluto de outra máquina.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/main.dart';

void main() {
  testWidgets('o app monta na tela inicial de login', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
