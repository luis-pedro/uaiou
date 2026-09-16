import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uaiou/core/pedidos/repositorio_pedidos.dart';
import 'package:uaiou/core/rede/cliente_api.dart';
import 'package:uaiou/screens/tela_publicar_pedido.dart';

/// Transporte que recusa qualquer chamada e registra o que passou por
/// ele — aqui o ponto é justamente provar que **nada** passa.
class _ServidorQueNuncaDeveriaSerChamado implements HttpClientAdapter {
  final List<RequestOptions> chamadas = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions opcoes,
    Stream<List<int>>? corpo,
    Future<void>? cancelamento,
  ) async {
    chamadas.add(opcoes);
    return ResponseBody.fromString('{}', 500);
  }
}

Widget _app(RepositorioPedidos repositorio) => Provider<RepositorioPedidos>.value(
  value: repositorio,
  child: const MaterialApp(home: TelaPublicarPedido()),
);

Future<void> _preencherTudoMenosOMapa(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Ex.: 6,00'), '6,00');
  await tester.enterText(find.widgetWithText(TextFormField, 'Rua'), 'Rua A');
  await tester.enterText(find.widgetWithText(TextFormField, 'Número'), '10');
  await tester.enterText(find.widgetWithText(TextFormField, 'Bairro'), 'Centro');
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nome de quem recebe'),
    'Marina',
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'sem ponto no mapa, publicar não manda POST e avisa no topo — RF-A10.3',
    (tester) async {
      final servidor = _ServidorQueNuncaDeveriaSerChamado();
      final dio = Dio()..httpClientAdapter = servidor;
      final repositorio = RepositorioPedidos(
        ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1'),
      );

      // Tela alta o bastante para que o `ListView` construa todos os
      // campos: o alvo do teste é o aviso, não a virtualização da lista.
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(repositorio));
      await _preencherTudoMenosOMapa(tester);

      await tester.ensureVisible(find.text('Publicar pedido'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publicar pedido'));
      await tester.pumpAndSettle();

      // A guarda de RF-A10.3 continua valendo: nenhuma requisição sai.
      expect(servidor.chamadas, isEmpty);

      // E o usuário é avisado por um canal que não depende de scroll —
      // era isto que faltava: o texto sob o mapa fica fora da tela no
      // momento do toque, e o botão parecia morto.
      //
      // O aviso saiu do `SnackBar` (rodapé, onde ficam o botão de publicar e a
      // barra de navegação) para o cartão do topo que o resto do app usa.
      // O mesmo texto aparece duas vezes de propósito: no cartão do topo e sob
      // o mapa. O que este teste garante é o canal que não depende de rolagem,
      // identificado pelo ícone de erro do cartão.
      expect(
        find.text('Marque o ponto de entrega no mapa antes de publicar.'),
        findsWidgets,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // O aviso se remove sozinho depois de 5s; sem avançar o relógio, o
      // temporizador fica pendente e o teste falha por isso, não pelo que mede.
      await tester.pump(const Duration(seconds: 6));
    },
  );
}
