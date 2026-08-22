import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/modelos/dinheiro.dart';
import 'package:uaiou/core/pagar/modelo_payables.dart';
import 'package:uaiou/core/pagar/repositorio_payables.dart';
import 'package:uaiou/core/pedidos/controlador_detalhe_pedido.dart';
import 'package:uaiou/core/pedidos/controlador_publicar_pedido.dart';
import 'package:uaiou/core/pedidos/repositorio_pedidos.dart';
import 'package:uaiou/core/rede/cliente_api.dart';

/// Fake de transporte que enfileira respostas por rota e registra toda
/// requisição — mesmo padrão de `entregas_test.dart`/`ganhos_test.dart`.
class _Servidor implements HttpClientAdapter {
  final Map<String, List<Response<dynamic>>> respostas = {};
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
    final chave = opcoes.path.split('?').first;
    final fila = respostas[chave];
    if (fila == null || fila.isEmpty) {
      return ResponseBody.fromString('{}', 404);
    }
    final r = fila.length == 1 ? fila.first : fila.removeAt(0);
    return ResponseBody.fromString(
      r.data as String,
      r.statusCode!,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Response<dynamic> _resp(int status, String corpo) => Response<dynamic>(
  requestOptions: RequestOptions(),
  statusCode: status,
  data: corpo,
);

RepositorioPedidos _repositorio(_Servidor servidor) {
  final dio = Dio()..httpClientAdapter = servidor;
  final api = ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1');
  return RepositorioPedidos(api);
}

void main() {
  group('publicar pedido — RF-A10.1/RF-A10.2/RNF-A10.1', () {
    test('corpo de POST /orders leva lat/lng do mapa e Idempotency-Key', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders'] = [
        _resp(201, '''
{
  "id": "p1", "number": "0011", "status": "published",
  "proposedFee": "6.00", "finalFee": null, "creditsConsumed": 1,
  "createdAt": "2026-08-10T18:30:00Z",
  "destination": {"street": "Rua A", "number": "10", "district": "Centro",
    "lat": -19.9251, "lng": -43.9417},
  "receiver": {"name": "Marina", "phone": null},
  "courier": null,
  "_links": {"self": {"href": "/api/v1/orders/p1"}}
}
'''),
      ];

      final controlador = ControladorPublicarPedido(_repositorio(servidor));

      final pedido = await controlador.publicar(
        valorProposto: Dinheiro.deString('6.00'),
        rua: 'Rua A',
        numero: '10',
        bairro: 'Centro',
        lat: -19.9251,
        lng: -43.9417,
        nomeRecebedor: 'Marina',
      );

      expect(pedido, isNotNull);
      expect(pedido!.id, 'p1');
      expect(controlador.erro, isNull);

      final chamada = servidor.chamadas.single;
      expect(chamada.headers['Idempotency-Key'], isNotNull);
      final corpo = chamada.data as Map;
      expect(corpo['proposedFee'], '6.00');
      expect((corpo['destination'] as Map)['lat'], -19.9251);
      expect((corpo['destination'] as Map)['lng'], -43.9417);
      expect((corpo['receiver'] as Map)['name'], 'Marina');
    });

    test('sem ponto marcado no mapa não publica (RF-A10.3) — nenhum POST sai', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders'] = [_resp(201, '{}')];
      final controlador = ControladorPublicarPedido(_repositorio(servidor));

      final pedido = await controlador.publicar(
        valorProposto: Dinheiro.deString('6.00'),
        rua: 'Rua A',
        numero: '10',
        bairro: 'Centro',
        lat: null,
        lng: null,
        nomeRecebedor: 'Marina',
      );

      expect(pedido, isNull);
      expect(controlador.enderecoInvalido, isTrue);
      expect(servidor.chamadas, isEmpty);
    });

    test('guarda de reentrância: duplo toque dispara UM só POST', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders'] = [
        _resp(201, '''
{
  "id": "p1", "number": "0011", "status": "published",
  "proposedFee": "6.00", "createdAt": "2026-08-10T18:30:00Z",
  "destination": {"district": "Centro", "lat": -19.9, "lng": -43.9},
  "receiver": {"name": "Marina"}, "_links": {}
}
'''),
      ];
      final controlador = ControladorPublicarPedido(_repositorio(servidor));

      final r1 = controlador.publicar(
        valorProposto: Dinheiro.deString('6.00'),
        rua: 'Rua A',
        numero: '10',
        bairro: 'Centro',
        lat: -19.9,
        lng: -43.9,
        nomeRecebedor: 'Marina',
      );
      final r2 = controlador.publicar(
        valorProposto: Dinheiro.deString('6.00'),
        rua: 'Rua A',
        numero: '10',
        bairro: 'Centro',
        lat: -19.9,
        lng: -43.9,
        nomeRecebedor: 'Marina',
      );

      final resultados = await Future.wait([r1, r2]);
      expect(resultados.where((p) => p != null).length, 1);
      expect(servidor.chamadas.length, 1);
    });

    test('422 INSUFFICIENT_CREDITS vira mensagem de negócio sem oferta de compra', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders'] = [
        _resp(422, '''
{"error": {"code": "INSUFFICIENT_CREDITS",
  "message": "Créditos insuficientes para publicar o pedido.", "rule": "RN-05.1"}}
'''),
      ];
      final controlador = ControladorPublicarPedido(_repositorio(servidor));

      final pedido = await controlador.publicar(
        valorProposto: Dinheiro.deString('6.00'),
        rua: 'Rua A',
        numero: '10',
        bairro: 'Centro',
        lat: -19.9,
        lng: -43.9,
        nomeRecebedor: 'Marina',
      );

      expect(pedido, isNull);
      expect(controlador.semCredito, isTrue);
      expect(controlador.enderecoInvalido, isFalse);
      expect(controlador.erro, contains('Créditos insuficientes'));
    });

    test('422 UNGEOCODABLE_ADDRESS aponta pro campo de endereço', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders'] = [
        _resp(422, '''
{"error": {"code": "UNGEOCODABLE_ADDRESS",
  "message": "As coordenadas enviadas não correspondem a um endereço real.",
  "rule": "RN-08.1"}}
'''),
      ];
      final controlador = ControladorPublicarPedido(_repositorio(servidor));

      final pedido = await controlador.publicar(
        valorProposto: Dinheiro.deString('6.00'),
        rua: 'Rua A',
        numero: '10',
        bairro: 'Centro',
        lat: 0,
        lng: 0,
        nomeRecebedor: 'Marina',
      );

      expect(pedido, isNull);
      expect(controlador.enderecoInvalido, isTrue);
      expect(controlador.semCredito, isFalse);
    });
  });

  group('decisão de contraoferta — RF-A10.6', () {
    test('aceitar chama PUT /counteroffers/{id}/decision com outcome accepted', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/p1'] = [
        _resp(200, '''
{"id": "p1", "number": "0011", "status": "in_negotiation",
  "proposedFee": "6.00", "createdAt": "2026-08-10T18:30:00Z",
  "destination": {"district": "Centro"}, "receiver": {"name": "Marina"},
  "_links": {}}
'''),
        _resp(200, '''
{"id": "p1", "number": "0011", "status": "accepted",
  "proposedFee": "6.00", "finalFee": "9.00", "createdAt": "2026-08-10T18:30:00Z",
  "destination": {"district": "Centro"}, "receiver": {"name": "Marina"},
  "courier": {"id": "c1", "name": "João"}, "_links": {}}
'''),
      ];
      servidor.respostas['/orders/p1/counteroffers'] = [
        _resp(200, '''
[{"id": "co1", "orderId": "p1", "courierId": "c1", "courierName": "João",
  "courierScore": null, "proposedFee": "9.00", "status": "pending",
  "createdAt": "2026-08-10T18:31:00Z", "respondedAt": null}]
'''),
        _resp(200, '[]'),
      ];
      servidor.respostas['/counteroffers/co1/decision'] = [
        _resp(200, '''
{"id": "co1", "status": "accepted", "proposedFee": "9.00",
  "order": {"id": "p1", "status": "accepted", "finalFee": "9.00"}, "_links": {}}
'''),
      ];

      final controlador = ControladorDetalhePedido(
        _repositorio(servidor),
        pedidoId: 'p1',
      );
      await controlador.carregar();
      expect(controlador.contraofertasPendentes, hasLength(1));

      final ok = await controlador.decidir('co1', aceitar: true);

      expect(ok, isTrue);
      final chamadaDecisao = servidor.chamadas.firstWhere(
        (c) => c.path.contains('/counteroffers/co1/decision'),
      );
      expect(chamadaDecisao.method, 'PUT');
      expect((chamadaDecisao.data as Map)['outcome'], 'accepted');
      expect(controlador.pedido?.freteFinal, Dinheiro.deString('9.00'));
    });
  });

  group('código de entrega — RF-A10.7', () {
    test('parseia CodigoDeEntrega de GET /orders/{id}/delivery/code', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/p1'] = [
        _resp(200, '''
{"id": "p1", "number": "0011", "status": "accepted",
  "proposedFee": "6.00", "createdAt": "2026-08-10T18:30:00Z",
  "destination": {"district": "Centro"}, "receiver": {"name": "Marina"},
  "courier": {"id": "c1", "name": "João"}, "_links": {}}
'''),
      ];
      servidor.respostas['/orders/p1/delivery/code'] = [
        _resp(200, '''
{"orderId": "p1", "code": "4821", "status": "issued",
  "expiresAt": "2026-08-10T20:30:00Z", "audit": {"readCount": 1, "lastReadAt": null},
  "_links": {}}
'''),
      ];

      final controlador = ControladorDetalhePedido(
        _repositorio(servidor),
        pedidoId: 'p1',
      );
      await controlador.carregar();
      await controlador.carregarCodigo();

      expect(controlador.codigo?.codigo, '4821');
      expect(controlador.erroCodigo, isNull);
    });
  });

  group('PayablesResponse — RF-A10.9', () {
    test('parseia total, agrupamento por entregador e lançamentos', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/payables'] = [
        _resp(200, '''
{
  "total": "15.00",
  "byCourier": [
    {"courierId": "c1", "courierName": "João", "total": "15.00",
      "entries": [
        {"id": "l1", "orderId": "p1", "orderNumber": "0011", "amount": "6.00",
          "status": "receivable", "createdAt": "2026-08-10T18:00:00Z"},
        {"id": "l2", "orderId": "p2", "orderNumber": "0012", "amount": "9.00",
          "status": "settled", "createdAt": "2026-08-09T18:00:00Z"}
      ]}
  ]
}
'''),
      ];

      final dio = Dio()..httpClientAdapter = servidor;
      final api = ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1');
      final payables = await RepositorioPayables(api).obter();

      expect(payables.total, Dinheiro.deString('15.00'));
      expect(payables.porEntregador, hasLength(1));
      final joao = payables.porEntregador.single;
      expect(joao.courierName, 'João');
      expect(joao.total, Dinheiro.deString('15.00'));
      expect(joao.lancamentos, hasLength(2));
      expect(joao.lancamentos.first.amount, Dinheiro.deString('6.00'));
    });

    test('resposta vazia não quebra — Payables.vazio', () {
      final payables = Payables.doJson(null);
      expect(payables.total, Dinheiro.zero);
      expect(payables.porEntregador, isEmpty);
    });
  });
}
