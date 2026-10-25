import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uaiou/core/cadastro/rascunho_cadastro.dart';
import 'package:uaiou/core/sessao/identidade.dart';
import 'package:uaiou/screens/tela_cadastro_dados.dart';
import 'package:uaiou/screens/tela_cadastro_entregador2.dart';

/// A verificação visual no navegador embutido é pouco confiável (o
/// painel entrega frames atrasados). Estes testes decidem o
/// comportamento de forma determinística.
///
/// No fluxo novo o passo 1 é o mesmo para entregador e estabelecimento
/// ([TelaCadastroDados]); o tipo de conta já vem escolhido no rascunho.
Widget _app(RascunhoCadastro rascunho) {
  return ChangeNotifierProvider<RascunhoCadastro>.value(
    value: rascunho,
    child: MaterialApp(
      home: const TelaCadastroDados(),
      routes: {'/cadastro_entregador2': (_) => const CadastroEntregador2()},
    ),
  );
}

/// A lista do formulário — a tela tem outras áreas roláveis (campos de texto).
final _formulario = find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

Future<void> _continuar(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Continuar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}

RascunhoCadastro _preenchido() => RascunhoCadastro()
  ..papel = Papel.entregador
  ..nome = 'João Silva'
  ..email = 'joao@teste.com'
  ..cpf = '390.533.447-05';

void main() {
  testWidgets('passo 1 vazio NÃO avança e mostra os erros', (tester) async {
    final rascunho = RascunhoCadastro()..papel = Papel.entregador;
    await tester.pumpWidget(_app(rascunho));

    await _continuar(tester);

    // Continua no passo 1.
    expect(find.text('Placa do veículo'), findsNothing);
    expect(find.byType(TelaCadastroDados), findsOneWidget);

    // E explica o que falta (RF-A04.3).
    expect(find.text('Nome é obrigatório.'), findsOneWidget);
    expect(find.text('E-mail é obrigatório.'), findsOneWidget);
    // O CPF fica abaixo da dobra e a lista só monta o que está na tela.
    await tester.scrollUntilVisible(
      find.text('CPF é obrigatório.'),
      200,
      scrollable: _formulario,
    );
    expect(find.text('CPF é obrigatório.'), findsOneWidget);
  });

  testWidgets('CPF com dígito errado barra o avanço', (tester) async {
    final rascunho = _preenchido()..cpf = '39053344704';
    await tester.pumpWidget(_app(rascunho));

    await _continuar(tester);

    expect(find.byType(TelaCadastroDados), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('CPF inválido.'),
      200,
      scrollable: _formulario,
    );
    expect(find.text('CPF inválido.'), findsOneWidget);
  });

  testWidgets('passo 1 completo avança para o passo 2 do entregador', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_preenchido()));

    await _continuar(tester);

    expect(find.byType(CadastroEntregador2), findsOneWidget);
  });

  testWidgets('o que é digitado sobe para o rascunho — RF-A04.1', (
    tester,
  ) async {
    final rascunho = RascunhoCadastro()..papel = Papel.entregador;
    await tester.pumpWidget(_app(rascunho));

    await tester.ensureVisible(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Maria');
    await tester.pump();

    expect(rascunho.nome, 'Maria');
  });

  testWidgets('voltar ao passo 1 preserva o preenchido — RF-A04.1', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_preenchido()));

    await _continuar(tester);
    expect(find.byType(CadastroEntregador2), findsOneWidget);

    // O link "Voltar" saiu do fluxo novo: quem volta é a seta do topo.
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Os campos renascem com o valor do rascunho, não vazios: antes de
    // A-04 sair da tela perdia tudo.
    expect(find.byType(TelaCadastroDados), findsOneWidget);
    expect(find.text('João Silva'), findsOneWidget);
    expect(find.text('joao@teste.com'), findsOneWidget);
  });
}
