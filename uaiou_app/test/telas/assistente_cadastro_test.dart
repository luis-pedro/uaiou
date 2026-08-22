import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uaiou/core/cadastro/rascunho_cadastro.dart';
import 'package:uaiou/core/sessao/identidade.dart';
import 'package:uaiou/screens/tela_cadastro_entregador1.dart';
import 'package:uaiou/screens/tela_cadastro_entregador2.dart';

/// A verificação visual no navegador embutido é pouco confiável (o
/// painel entrega frames atrasados). Estes testes decidem o
/// comportamento de forma determinística.
Widget _app(RascunhoCadastro rascunho) {
  return ChangeNotifierProvider<RascunhoCadastro>.value(
    value: rascunho,
    child: MaterialApp(
      home: const CadastroEntregador1(),
      routes: {
        '/cadastro_entregador2': (_) => const CadastroEntregador2(),
      },
    ),
  );
}

void main() {
  testWidgets('passo 1 vazio NÃO avança e mostra os erros', (tester) async {
    final rascunho = RascunhoCadastro()..papel = Papel.entregador;
    await tester.pumpWidget(_app(rascunho));

    await tester.ensureVisible(find.text('Próximo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();

    // Continua no passo 1.
    expect(find.text('Placa do veículo'), findsNothing);
    expect(find.byType(CadastroEntregador1), findsOneWidget);

    // E explica o que falta (RF-A04.3).
    expect(find.text('Nome é obrigatório.'), findsOneWidget);
    expect(find.text('E-mail é obrigatório.'), findsOneWidget);
    expect(find.text('CPF é obrigatório.'), findsOneWidget);
  });

  testWidgets('CPF com dígito errado barra o avanço', (tester) async {
    final rascunho = RascunhoCadastro()
      ..nome = 'João'
      ..email = 'joao@teste.com'
      ..cpf = '39053344704';
    await tester.pumpWidget(_app(rascunho));

    await tester.ensureVisible(find.text('Próximo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();

    expect(find.byType(CadastroEntregador1), findsOneWidget);
    expect(find.text('CPF inválido.'), findsOneWidget);
  });

  testWidgets('passo 1 completo avança para o passo 2', (tester) async {
    final rascunho = RascunhoCadastro()
      ..nome = 'João Silva'
      ..email = 'joao@teste.com'
      ..cpf = '390.533.447-05';
    await tester.pumpWidget(_app(rascunho));

    await tester.ensureVisible(find.text('Próximo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();

    expect(find.byType(CadastroEntregador2), findsOneWidget);
  });

  testWidgets('o que é digitado sobe para o rascunho — RF-A04.1',
      (tester) async {
    final rascunho = RascunhoCadastro();
    await tester.pumpWidget(_app(rascunho));

    await tester.ensureVisible(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Maria');
    await tester.pump();

    expect(rascunho.nome, 'Maria');
  });

  testWidgets('voltar ao passo 1 preserva o preenchido — RF-A04.1',
      (tester) async {
    final rascunho = RascunhoCadastro()
      ..nome = 'João Silva'
      ..email = 'joao@teste.com'
      ..cpf = '390.533.447-05';
    await tester.pumpWidget(_app(rascunho));

    await tester.ensureVisible(find.text('Próximo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    expect(find.byType(CadastroEntregador2), findsOneWidget);

    // Volta pelo próprio link da tela (não há barra com seta).
    await tester.ensureVisible(find.text('Voltar a tela anterior'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar a tela anterior'));
    await tester.pumpAndSettle();

    // Os campos renascem com o valor do rascunho, não vazios: antes de
    // A-04 sair da tela perdia tudo.
    expect(find.text('João Silva'), findsOneWidget);
    expect(find.text('joao@teste.com'), findsOneWidget);
  });
}
