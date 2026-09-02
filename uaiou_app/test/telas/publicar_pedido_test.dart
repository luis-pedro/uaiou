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
    'sem ponto no mapa, publicar não manda POST e avisa em SnackBar — RF-A10.3',
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
      expect(
        find.widgetWithText(
          SnackBar,
          'Marque o ponto de entrega no mapa antes de publicar.',
        ),
        findsOneWidget,
      );
    },
  );
}
