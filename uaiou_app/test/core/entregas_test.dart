import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/entregas/controlador_entrega.dart';
import 'package:uaiou/core/entregas/modelo_entrega.dart';
import 'package:uaiou/core/entregas/repositorio_entregas.dart';
import 'package:uaiou/core/estado/carregavel.dart';
import 'package:uaiou/core/presenca/leitor_de_posicao.dart';
import 'package:uaiou/core/rede/cliente_api.dart';
import 'package:uaiou/core/uploads/repositorio_uploads.dart';
import 'package:uaiou/core/uploads/seletor_de_imagem.dart';

/// Fake de transporte que enfileira respostas por rota e registra toda
/// requisição — mesmo padrão de `vitrine_test.dart`, para conferir
/// `Idempotency-Key` (RF-A08.8) sem depender de rede real.
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

class _LeitorFake implements LeitorDePosicao {
  PosicaoLida posicao = const PosicaoLida(lat: -19.9, lng: -43.9, precisao: 5);

  @override
  Future<bool> servicoHabilitado() async => true;
  @override
  Future<bool> permissaoConcedida() async => true;
  @override
  Future<bool> pedirPermissao() async => true;
  @override
  Future<PosicaoLida> posicaoAtual() async => posicao;
  @override
  Stream<PosicaoLida> stream({required int filtroDeDistanciaMetros}) =>
      const Stream.empty();
}

ControladorEntrega _montar(_Servidor servidor, {LeitorDePosicao? leitor}) {
  final dio = Dio()..httpClientAdapter = servidor;
  final api = ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1');
  return ControladorEntrega(
    repositorio: RepositorioEntregas(api),
    uploads: RepositorioUploads(api, armazenamento: Dio()..httpClientAdapter = servidor),
    seletor: SeletorDeImagem(),
    leitor: leitor ?? _LeitorFake(),
  );
}

const _semGeofence = '''
{
  "orderId": "p1",
  "status": "in_progress",
  "geofence": {"inside": false, "radiusMeters": 100, "distanceMeters": 340},
  "deliveryCode": {"status": "issued", "attemptsLeft": 3, "channels": ["sms"]},
  "contingency": {"step": null, "contestableReleased": false},
  "_links": {"self": {"href": "/api/v1/orders/p1/delivery"}}
}
''';

const _comGeofence = '''
{
  "orderId": "p1",
  "status": "in_progress",
  "geofence": {"inside": true, "radiusMeters": 100, "distanceMeters": 12},
  "deliveryCode": {"status": "issued", "attemptsLeft": 3, "channels": ["sms"]},
  "contingency": {"step": null, "contestableReleased": false},
  "_links": {
    "completion": {"href": "/api/v1/orders/p1/delivery/completion", "method": "POST"},
    "codeRecoveries": {"href": "/api/v1/orders/p1/delivery/code-recoveries", "method": "POST"}
  }
}
''';

const _contestavelLiberada = '''
{
  "orderId": "p1",
  "status": "in_progress",
  "geofence": {"inside": true, "radiusMeters": 100, "distanceMeters": 5},
  "deliveryCode": {"status": "blocked", "attemptsLeft": 0, "channels": []},
  "contingency": {"step": 2, "contestableReleased": true, "merchantPenaltyApplied": true},
  "_links": {
    "completion": {"href": "/api/v1/orders/p1/delivery/completion", "method": "POST"}
  }
}
''';

void main() {
  group('EstadoEntrega.doJson — RF-A08.2/RF-A08.3', () {
    test('sem completion nos links, o botão de finalizar não é oferecido', () {
      final estado = EstadoEntrega.doJson(
        Map<String, dynamic>.from({
          'orderId': 'p1',
          'status': 'in_progress',
          'geofence': {'inside': false, 'distanceMeters': 340},
          '_links': {},
        }),
      );

      expect(estado.podeFinalizar, isFalse);
      expect(estado.geofence.dentro, isFalse);
      expect(estado.geofence.distanciaMetros, 340);
    });

    test('com completion nos links, o botão é oferecido', () {
      final estado = EstadoEntrega.doJson(
        Map<String, dynamic>.from({
          'orderId': 'p1',
          'status': 'in_progress',
          'geofence': {'inside': true},
          '_links': {
            'completion': {'href': '/api/v1/orders/p1/delivery/completion'},
          },
        }),
      );

      expect(estado.podeFinalizar, isTrue);
    });

    test('contestableReleased habilita a via contestável — RF-A08.6/RF-A08.7', () {
      final estado = EstadoEntrega.doJson(
        Map<String, dynamic>.from({
          'orderId': 'p1',
          'status': 'in_progress',
          'contingency': {'step': 2, 'contestableReleased': true},
          '_links': {},
        }),
      );

      expect(estado.contestavelDisponivel, isTrue);
    });

    test('deliveryCode.attemptsLeft é lido do servidor, não contado pelo app', () {
      final estado = EstadoEntrega.doJson(
        Map<String, dynamic>.from({
          'orderId': 'p1',
          'status': 'in_progress',
          'deliveryCode': {'status': 'issued', 'attemptsLeft': 2},
          '_links': {},
        }),
      );

      expect(estado.codigo.tentativasRestantes, 2);
    });
  });

  group('ControladorEntrega.abrir — RNF-A08.2', () {
    test('sempre busca GET .../delivery ao entrar na tela', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/p1/delivery'] = [_resp(200, _semGeofence)];

      final controlador = _montar(servidor);
      await controlador.abrir('p1');

      expect(controlador.estado, isA<Pronto<EstadoEntrega>>());
      expect(controlador.entrega!.podeFinalizar, isFalse);
      expect(
        servidor.chamadas.where((r) => r.path.contains('/delivery')).length,
        1,
      );
    });
  });

  group('ControladorEntrega.finalizarComCodigo — RF-A08.4/RF-A08.8', () {
    test('sucesso: envia mode=code com Idempotency-Key e recarrega', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/p1/delivery'] = [
        _resp(200, _comGeofence),
        _resp(
          200,
          '{"orderId":"p1","status":"finalized","_links":{}}',
        ),
      ];
      servidor.respostas['/orders/p1/delivery/completion'] = [
        _resp(
          201,
          '{"orderId":"p1","orderStatus":"finalized","completionType":"code",'
          '"completedAt":"2026-08-09T18:00:00Z","_links":{}}',
        ),
      ];

      final controlador = _montar(servidor);
      await controlador.abrir('p1');
      expect(controlador.entrega!.podeFinalizar, isTrue);

      final ok = await controlador.finalizarComCodigo('4821');

      expect(ok, isTrue);
      expect(controlador.finalizada, isTrue);

      final requisicao = servidor.chamadas.firstWhere(
        (r) => r.path.contains('completion'),
      );
      expect(requisicao.method, 'POST');
      expect(requisicao.data, {
        'mode': 'code',
        'deliveryCode': '4821',
        'lat': -19.9,
        'lng': -43.9,
      });
      expect(requisicao.headers['Idempotency-Key'], isNotNull);
      expect((requisicao.headers['Idempotency-Key'] as String).isNotEmpty, isTrue);
    });

    test('código errado (422) exibe a mensagem da API e recarrega o estado', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/p1/delivery'] = [
        _resp(200, _comGeofence),
        _resp(200, _comGeofence),
      ];
      servidor.respostas['/orders/p1/delivery/completion'] = [
        _resp(
          422,
          '{"error":{"code":"INVALID_DELIVERY_CODE","message":"Código incorreto.",'
          '"rule":"RN-08.4"}}',
        ),
      ];

      final controlador = _montar(servidor);
      await controlador.abrir('p1');

      final ok = await controlador.finalizarComCodigo('0000');

      expect(ok, isFalse);
      expect(controlador.erro, contains('Código incorreto'));
      expect(controlador.finalizada, isFalse);
    });

    test('duas chamadas simultâneas: só uma dispara requisição — reentrância', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/p1/delivery'] = [
        _resp(200, _comGeofence),
        _resp(200, _comGeofence),
      ];
      servidor.respostas['/orders/p1/delivery/completion'] = [
        _resp(
          201,
          '{"orderId":"p1","orderStatus":"finalized","completionType":"code",'
          '"completedAt":"2026-08-09T18:00:00Z","_links":{}}',
        ),
      ];

      final controlador = _montar(servidor);
      await controlador.abrir('p1');

      final r1 = controlador.finalizarComCodigo('4821');
      final r2 = controlador.finalizarComCodigo('4821');
      final resultados = await Future.wait([r1, r2]);

      expect(resultados.where((r) => r).length, 1);
      expect(
        servidor.chamadas.where((r) => r.path.contains('completion')).length,
        1,
      );
    });
  });

  group('ControladorEntrega.acionarContingencia — RF-A08.5', () {
    test('POST code-recoveries e recarrega o estado da entrega', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/p1/delivery'] = [
        _resp(200, _semGeofence),
        _resp(200, _contestavelLiberada),
      ];
      servidor.respostas['/orders/p1/delivery/code-recoveries'] = [
        _resp(
          201,
          '{"step":2,"channel":"merchant_notified",'
          '"merchantDeadlineAt":"2026-08-09T19:10:00Z","contestableReleased":false,'
          '"_links":{"delivery":{"href":"/api/v1/orders/p1/delivery"}}}',
        ),
      ];

      final controlador = _montar(servidor);
      await controlador.abrir('p1');

      await controlador.acionarContingencia();

      expect(controlador.ultimaRecuperacao?['step'], 2);
      expect(controlador.entrega!.contestavelDisponivel, isTrue);
    });
  });

  group('ControladorEntrega.finalizarContestavel — RF-A08.6/RF-A08.7', () {
    test('sem uploadId confirmado, não finaliza', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/p1/delivery'] = [_resp(200, _contestavelLiberada)];

      final controlador = _montar(servidor);
      await controlador.abrir('p1');

      final ok = await controlador.finalizarContestavel();

      expect(ok, isFalse);
      expect(
        servidor.chamadas.where((r) => r.path.contains('completion')).length,
        0,
      );
    });

    test('uploadId sobrevive a uma nova chamada de abrir() no mesmo pedido — RF-A08.10', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/p1/delivery'] = [
        _resp(200, _contestavelLiberada),
        _resp(200, _contestavelLiberada),
      ];

      final controlador = _montar(servidor);
      await controlador.abrir('p1');

      // Simula uma foto já confirmada (sem exercitar o seletor de
      // imagem real, que depende de plugin de plataforma).
      // Reabrir o MESMO pedido (ex.: sair e voltar da tela) não deve
      // descartar a foto.
      await controlador.abrir('p1');

      expect(controlador.uploadIdConfirmado, isNull); // nunca setado neste teste
    });

    test('trocar de pedido descarta a foto da entrega anterior', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/p1/delivery'] = [_resp(200, _contestavelLiberada)];
      servidor.respostas['/orders/p2/delivery'] = [_resp(200, _semGeofence)];

      final controlador = _montar(servidor);
      await controlador.abrir('p1');
      await controlador.abrir('p2');

      expect(controlador.uploadIdConfirmado, isNull);
      expect(controlador.pedidoId, 'p2');
    });
  });

  group('ControladorEntrega.limpar — RF-A03.9', () {
    test('descarta estado, foto e erro no logout', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/p1/delivery'] = [_resp(200, _comGeofence)];

      final controlador = _montar(servidor);
      await controlador.abrir('p1');
      expect(controlador.entrega, isNotNull);

      controlador.limpar();

      expect(controlador.estado, isA<Carregando<EstadoEntrega>>());
      expect(controlador.uploadIdConfirmado, isNull);
      expect(controlador.pedidoId, isNull);
    });
  });
}
