// Testes de fumaça do app.
//
// Substitui o template padrão do contador gerado pelo `flutter create`,
// que nunca rodou neste projeto: ele testava um contador inexistente e
// tinha um import com caminho absoluto de outra máquina.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/main.dart';
import 'package:uaiou/screens/principal_login.dart';
import 'package:uaiou/screens/tela_principal_entregador.dart';
import 'package:uaiou/screens/tela_principal_estabelecimento.dart';

void main() {
  testWidgets('o app monta na tela inicial', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  // Regressão: o primeiro APK desta branch abriu nas telas do produto, porque
  // o modo feira era decidido por consulta ao backend e caía no produto quando
  // a resposta não vinha. Nesta branch o app É o da feira, decidido em tempo
  // de compilação — e nenhuma tela de entrada do produto pode aparecer.
  //
  // A asserção é pela ausência das telas do produto, não pela presença da
  // tela da feira: no primeiro quadro a raiz ainda mostra o splash enquanto
  // o cofre da sessão é lido, e esperar a sessão assentar num teste de widget
  // exigiria simular o armazenamento seguro — ruído para o que se quer travar.
  testWidgets('nesta branch o app nunca abre no fluxo do produto', (
    tester,
  ) async {
    expect(feiraNestaBranch, isTrue);

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(PrincipalLogin), findsNothing);
    expect(find.byType(TelaPrincipalEntregador), findsNothing);
    expect(find.byType(TelaPrincipalEstabelecimento), findsNothing);
  });
}
