import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uaiou/core/estatisticas/controlador_estatisticas.dart';
import 'package:uaiou/core/estatisticas/repositorio_estatisticas.dart';
import 'package:uaiou/core/pedidos/repositorio_pedidos.dart';
import 'package:uaiou/core/rede/cliente_api.dart';
import 'package:uaiou/core/sessao/cofre_sessao.dart';
import 'package:uaiou/core/sessao/controlador_sessao.dart';
import 'package:uaiou/core/sessao/repositorio_auth.dart';
import 'package:uaiou/others/entregador_service.dart';
import 'package:uaiou/screens/tela_atividade_entregador.dart';
import 'package:uaiou/screens/tela_detalhe_pedido.dart';

/// Respostas copiadas do servidor real (perfil dev), consultadas como o
/// entregador de teste que já finalizou o pedido 0004.
///
/// O ponto que estes testes guardam: **a listagem devolve só o bairro**
/// (`DestinationResponse.apenasBairro`), então `street` e `number` não
/// vêm no JSON. Escrever esses campos direto no card imprimia a palavra
/// "null" na tela de quem já entregou alguma coisa.
const _listaFinalizadas = {
  'data': [
    {
      'id': '01a045dd-4f8a-759c-86ad-62e88fd74659',
      'number': '0004',
      'status': 'finalized',
      'proposedFee': '7.00',
      'destination': {'district': 'teste'},
      'createdAt': '2026-08-28T01:20:00Z',
      '_links': {
        'self': {'href': '/api/v1/orders/01a045dd-4f8a-759c-86ad-62e88fd74659'},
      },
    },
  ],
  'meta': {'page': 1, 'perPage': 20, 'total': 1},
};

const _listaVazia = {
  'data': <Map<String, Object?>>[],
  'meta': {'page': 1, 'perPage': 20, 'total': 0},
};

/// Detalhe do MESMO pedido — aqui o endereço vem completo, que é o que
/// justifica o botão "Visualizar pedido" existir para uma entrega já
/// concluída.
const _detalhe = {
  'id': '01a045dd-4f8a-759c-86ad-62e88fd74659',
  'number': '0004',
  'status': 'finalized',
  'proposedFee': '7.00',
  'finalFee': '7.00',
  'createdAt': '2026-08-28T01:20:00Z',
  'destination': {
    'street': 'teste',
    'number': 'teste',
    'complement': 'teste',
    'district': 'teste',
    'lat': -22.256627,
    'lng': -45.695291,
  },
  'receiver': {'name': 'teste'},
  '_links': {
    'self': {'href': '/api/v1/orders/01a045dd-4f8a-759c-86ad-62e88fd74659'},
  },
};

class _ServidorFake implements HttpClientAdapter {
  final List<String> caminhos = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions opcoes,
    Stream<List<int>>? corpo,
    Future<void>? cancelamento,
  ) async {
    caminhos.add('${opcoes.path}?${opcoes.uri.query}');

    final status = opcoes.uri.queryParameters['status'];
    final Object resposta = switch (opcoes.uri.path) {
      final p when p.endsWith('/orders') && status == 'finalized' =>
        _listaFinalizadas,
      final p when p.endsWith('/orders') => _listaVazia,
      final p when p.contains('/orders/') => _detalhe,
      _ => const <String, Object?>{},
    };

    return ResponseBody.fromString(
      jsonEncode(resposta),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Widget _app(ClienteApi api) {
  final repositorio = RepositorioPedidos(api);
  final sessao = ControladorSessao(
    auth: RepositorioAuth(api),
    cofre: CofreSessaoEmMemoria(),
  );

  return MultiProvider(
    providers: [
      Provider<RepositorioPedidos>.value(value: repositorio),
      ChangeNotifierProvider(
        create: (_) =>
            EstadoEntregador(repositorio: repositorio, sessao: sessao),
      ),
      ChangeNotifierProvider(
        create: (_) => ControladorEstatisticas(
          repositorio: RepositorioEstatisticas(api),
        ),
      ),
    ],
    child: const MaterialApp(home: TelaAtividadesEntregador()),
  );
}

void main() {
  testWidgets(
    'entrega concluída não imprime "null" no endereço — a listagem só '
    'devolve o bairro',
    (tester) async {
      final api = ClienteApi(
        dio: Dio()..httpClientAdapter = _ServidorFake(),
        baseUrl: 'http://localhost/api/v1',
      );

      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      expect(find.textContaining('null'), findsNothing);
      expect(find.textContaining('Rua:'), findsNothing);
      // O bairro é o que o servidor mandou, e ele aparece.
      expect(find.textContaining('teste'), findsWidgets);
    },
  );

  testWidgets(
    'o botão "Visualizar pedido" abre o detalhe da entrega concluída',
    (tester) async {
      final api = ClienteApi(
        dio: Dio()..httpClientAdapter = _ServidorFake(),
        baseUrl: 'http://localhost/api/v1',
      );

      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      final botao = find.text('Visualizar pedido');
      expect(botao, findsOneWidget);

      await tester.tap(botao);
      await tester.pumpAndSettle();

      // Antes da correção o `onTap` era um TODO vazio: o toque acendia o
      // ripple e a tela continuava a mesma.
      expect(find.byType(TelaDetalhePedido), findsOneWidget);
    },
  );
}
