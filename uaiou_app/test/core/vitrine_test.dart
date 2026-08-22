import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/estado/carregavel.dart';
import 'package:uaiou/core/modelos/dinheiro.dart';
import 'package:uaiou/core/pedidos/controlador_vitrine.dart';
import 'package:uaiou/core/pedidos/repositorio_pedidos.dart';
import 'package:uaiou/core/rede/cliente_api.dart';
import 'package:uaiou/others/pedido.dart';

/// Fake de transporte que enfileira respostas por rota e registra toda
/// requisição — inclusive cabeçalhos, para conferir `Idempotency-Key`
/// (RF-A07.3) sem depender de rede real.
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

Response<dynamic> _resp(int status, String corpo) =>
    Response<dynamic>(requestOptions: RequestOptions(), statusCode: status, data: corpo);

String _pedidoJson(
  String id, {
  String status = 'published',
  bool comLinks = true,
}) =>
    '{"id":"$id","number":"$id","status":"$status","proposedFee":"6.00",'
    '"distanceKm":5.0,'
    '"createdAt":"2026-08-09T12:00:00Z",'
    '"destination":{"district":"Centro"},'
    '"_links":${comLinks ? '{"self":{"href":"/api/v1/orders/$id"},"assignment":{"href":"/api/v1/orders/$id/assignment","method":"POST"},"counteroffers":{"href":"/api/v1/orders/$id/counteroffers","method":"POST"}}' : '{}'}}';

ControladorVitrine _montar(_Servidor servidor) {
  final dio = Dio()..httpClientAdapter = servidor;
  final api = ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1');
  return ControladorVitrine(RepositorioPedidos(api));
}

void main() {
  group('Pedido._links — RF-A07.6', () {
    test('só oferece o botão quando o link correspondente existe', () {
      final comAcoes = Pedido.doJson(
        Map<String, dynamic>.from(
          {
            'id': 'a',
            'status': 'published',
            'createdAt': '2026-08-09T12:00:00Z',
            '_links': {
              'assignment': {'href': '/api/v1/orders/a/assignment'},
            },
          },
        ),
      );
      expect(comAcoes.links.permite('assignment'), isTrue);
      expect(comAcoes.links.permite('counteroffers'), isFalse);

      final semLinks = Pedido.doJson(
        Map<String, dynamic>.from({
          'id': 'b',
          'status': 'accepted',
          'createdAt': '2026-08-09T12:00:00Z',
          '_links': {},
        }),
      );
      expect(semLinks.links.permite('assignment'), isFalse);
      expect(semLinks.links.permite('counteroffers'), isFalse);
    });

    test('proposedFee e distanceKm chegam pelo tipo certo', () {
      final pedido = Pedido.doJson(
        Map<String, dynamic>.from({
          'id': 'a',
          'status': 'published',
          'proposedFee': '9.50',
          'distanceKm': 3.2,
          'createdAt': '2026-08-09T12:00:00Z',
          '_links': {},
        }),
      );
      expect(pedido.freteProposto, Dinheiro.deString('9.50'));
      expect(pedido.distanciaKm, 3.2);
    });
  });

  group('ControladorVitrine.aceitar — RF-A07.3', () {
    test('sucesso: envia corpo vazio com Idempotency-Key e remove da lista', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders'] = [
        _resp(200, '{"data":[${_pedidoJson("a")}],"meta":{"page":1,"perPage":20,"total":1}}'),
      ];
      servidor.respostas['/orders/a/assignment'] = [
        _resp(
          201,
          '{"orderId":"a","courierId":"c1","finalFee":"6.00",'
          '"assignedAt":"2026-08-09T12:05:00Z","_links":{}}',
        ),
      ];

      final vitrine = _montar(servidor);
      await vitrine.carregar();
      expect(vitrine.pedidos.itens.length, 1);

      final ok = await vitrine.aceitar('a');

      expect(ok, isTrue);
      expect(vitrine.pedidos.itens, isEmpty);

      final requisicao = servidor.chamadas.firstWhere(
        (r) => r.path.contains('assignment'),
      );
      expect(requisicao.method, 'POST');
      expect(requisicao.data, isNull);
      expect(requisicao.headers['Idempotency-Key'], isNotNull);
      expect((requisicao.headers['Idempotency-Key'] as String).isNotEmpty, isTrue);
    });

    test('duas chamadas simultâneas: só uma dispara requisição — RNF-A07.1', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/a/assignment'] = [
        _resp(
          201,
          '{"orderId":"a","courierId":"c1","finalFee":"6.00",'
          '"assignedAt":"2026-08-09T12:05:00Z","_links":{}}',
        ),
      ];
      final vitrine = _montar(servidor);

      final r1 = vitrine.aceitar('a');
      final r2 = vitrine.aceitar('b');
      final resultados = await Future.wait([r1, r2]);

      expect(resultados.where((r) => r).length, 1, reason: 'só uma deve ter concluído');
      expect(
        servidor.chamadas.where((r) => r.path.contains('assignment')).length,
        1,
        reason: 'a segunda foi barrada antes da rede',
      );
    });

    test('409 é tratado como caminho normal, não erro genérico — RF-A07.4', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders'] = [
        _resp(200, '{"data":[${_pedidoJson("a")}],"meta":{"page":1,"perPage":20,"total":1}}'),
        _resp(200, '{"data":[],"meta":{"page":1,"perPage":20,"total":0}}'),
      ];
      servidor.respostas['/orders/a/assignment'] = [
        _resp(
          409,
          '{"error":{"code":"ORDER_ALREADY_ASSIGNED",'
          '"message":"Esse pedido acabou de ser aceito por outra pessoa."}}',
        ),
      ];

      final vitrine = _montar(servidor);
      await vitrine.carregar();

      final ok = await vitrine.aceitar('a');

      expect(ok, isFalse);
      expect(vitrine.aviso, 'Esse pedido acabou de ser aceito por outra pessoa.');
      // a remoção local acontece antes mesmo do recarregamento
      // terminar — o pedido não deve reaparecer na tela.
      expect(vitrine.pedidos.itens.where((p) => p.id == 'a'), isEmpty);
    });

    test('depois do aceite (sucesso ou 409), a guarda libera para o próximo', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/a/assignment'] = [
        _resp(
          409,
          '{"error":{"code":"ORDER_ALREADY_ASSIGNED","message":"Já foi aceito."}}',
        ),
      ];
      servidor.respostas['/orders'] = [
        _resp(200, '{"data":[],"meta":{"page":1,"perPage":20,"total":0}}'),
      ];
      servidor.respostas['/orders/b/assignment'] = [
        _resp(
          201,
          '{"orderId":"b","courierId":"c1","finalFee":"6.00",'
          '"assignedAt":"2026-08-09T12:05:00Z","_links":{}}',
        ),
      ];

      final vitrine = _montar(servidor);
      await vitrine.aceitar('a');
      expect(vitrine.haAceiteEmVoo, isFalse);

      final ok = await vitrine.aceitar('b');
      expect(ok, isTrue);
    });
  });

  group('ControladorVitrine.contrapropor — RF-A07.5', () {
    test('sucesso: envia proposedFee e marca o pedido como pendente', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/a/counteroffers'] = [
        _resp(
          201,
          '{"id":"co1","orderId":"a","courierId":"c1","courierName":"Fulano",'
          '"proposedFee":"9.00","status":"pending","createdAt":"2026-08-09T12:00:00Z"}',
        ),
      ];

      final vitrine = _montar(servidor);
      final ok = await vitrine.contrapropor('a', Dinheiro.deString('9.00'));

      expect(ok, isTrue);
      expect(vitrine.temPropostaPendente('a'), isTrue);

      final requisicao = servidor.chamadas.firstWhere(
        (r) => r.path.contains('counteroffers'),
      );
      expect(requisicao.data, {'proposedFee': '9.00'});
    });

    test('409 (contraoferta duplicada) não marca como pendente', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/a/counteroffers'] = [
        _resp(
          409,
          '{"error":{"code":"COUNTEROFFER_ALREADY_PENDING",'
          '"message":"Já existe uma proposta sua pendente para este pedido."}}',
        ),
      ];

      final vitrine = _montar(servidor);
      final ok = await vitrine.contrapropor('a', Dinheiro.deString('9.00'));

      expect(ok, isFalse);
      expect(vitrine.temPropostaPendente('a'), isFalse);
      expect(vitrine.aviso, contains('pendente'));
    });
  });

  group('ControladorVitrine.limpar — RF-A03.9', () {
    test('descarta lista, avisos e estado de propostas no logout', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/a/counteroffers'] = [
        _resp(
          201,
          '{"id":"co1","orderId":"a","courierId":"c1","courierName":"Fulano",'
          '"proposedFee":"9.00","status":"pending","createdAt":"2026-08-09T12:00:00Z"}',
        ),
      ];
      final vitrine = _montar(servidor);
      await vitrine.contrapropor('a', Dinheiro.deString('9.00'));
      expect(vitrine.temPropostaPendente('a'), isTrue);

      vitrine.limpar();

      expect(vitrine.temPropostaPendente('a'), isFalse);
      expect(vitrine.pedidos.estado, isA<Carregando<List<Pedido>>>());
    });
  });
}
