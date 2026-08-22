import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/avaliacoes/controlador_avaliacoes.dart';
import 'package:uaiou/core/avaliacoes/modelo_avaliacao.dart';
import 'package:uaiou/core/avaliacoes/repositorio_avaliacoes.dart';
import 'package:uaiou/core/estado/carregavel.dart';
import 'package:uaiou/core/gamificacao/controlador_score.dart';
import 'package:uaiou/core/gamificacao/repositorio_score.dart';
import 'package:uaiou/core/rede/cliente_api.dart';

/// Fake de transporte — mesmo padrão de `ganhos_test.dart`/`notificacoes_test.dart`.
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

ClienteApi _api(_Servidor servidor) {
  final dio = Dio()..httpClientAdapter = servidor;
  return ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1');
}

void main() {
  group('RepositorioAvaliacoes.criar — RF-A12.1', () {
    test('POST /orders/{id}/reviews nunca envia targetId no corpo', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/p1/reviews'] = [
        _resp(
          201,
          '{"id":"r1","orderId":"p1","targetId":"u9","rating":5,'
          '"comment":"Ótimo","createdAt":"2026-08-10T12:00:00Z"}',
        ),
      ];

      final repositorio = RepositorioAvaliacoes(_api(servidor));
      final criada = await repositorio.criar('p1', rating: 5, comment: 'Ótimo');

      expect(criada.id, 'r1');
      // O alvo (`targetId`) só existe na RESPOSTA — o corpo enviado
      // não pode conter essa chave, senão o app estaria fingindo poder
      // escolher quem avaliar (RF-19.3 do backend).
      final requisicao = servidor.chamadas.single;
      expect(requisicao.method, 'POST');
      final corpoEnviado = requisicao.data as Map;
      expect(corpoEnviado.containsKey('targetId'), isFalse);
      expect(corpoEnviado, {'rating': 5, 'comment': 'Ótimo'});
    });

    test('comentário vazio não é enviado', () async {
      final servidor = _Servidor();
      servidor.respostas['/orders/p1/reviews'] = [
        _resp(201, '{"id":"r1","orderId":"p1","targetId":"u9","rating":4,"createdAt":null}'),
      ];

      final repositorio = RepositorioAvaliacoes(_api(servidor));
      await repositorio.criar('p1', rating: 4, comment: '   ');

      final corpoEnviado = servidor.chamadas.single.data as Map;
      expect(corpoEnviado.containsKey('comment'), isFalse);
    });
  });

  group('RepositorioAvaliacoes.pendentes — RF-A12.1', () {
    test('parseia lista simples sem envelope (contrato real, sem `data`/`_links`)', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/reviews'] = [
        _resp(
          200,
          '[{"orderId":"p1","orderNumber":"1001","counterpartyId":"u1",'
          '"counterpartyName":"Zé","deadline":"2026-08-15T00:00:00Z"}]',
        ),
      ];

      final itens = await RepositorioAvaliacoes(_api(servidor)).pendentes();

      expect(itens, hasLength(1));
      expect(itens.first.orderNumber, '1001');
      expect(itens.first.counterpartyName, 'Zé');
      expect(itens.first.deadline, isNotNull);

      final requisicao = servidor.chamadas.single;
      expect(requisicao.queryParameters['direction'], 'pending');
    });
  });

  group('RepositorioAvaliacoes.recebidas — RF-A12.7', () {
    test('parseia summary + data completo, sem paginação inventada', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/reviews'] = [
        _resp(
          200,
          '{"summary":{"average":4.7,"activeRate":0.8,"count":10},'
          '"data":[{"id":"r1","orderId":"p1","orderNumber":"1001","rating":5,'
          '"comment":"Rápido","active":true,"createdAt":"2026-08-01T10:00:00Z"},'
          '{"id":"r2","orderId":"p2","orderNumber":"1002","rating":5,'
          '"comment":null,"active":false,"createdAt":"2026-08-02T10:00:00Z"}]}',
        ),
      ];

      final resposta = await RepositorioAvaliacoes(_api(servidor)).recebidas();

      expect(resposta.resumo.average, 4.7);
      expect(resposta.resumo.activeRate, 0.8);
      expect(resposta.resumo.count, 10);
      expect(resposta.itens, hasLength(2));
      expect(resposta.itens.first.comment, 'Rápido');
      expect(resposta.itens.last.active, isFalse);

      final requisicao = servidor.chamadas.single;
      expect(requisicao.queryParameters['direction'], 'received');
    });
  });

  group('ControladorAvaliacoes — RF-A12.1/RF-A12.2', () {
    test('carregar popula pendentes e recebidas; avaliar recarrega pendentes', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/reviews'] = [
        _resp(
          200,
          '[{"orderId":"p1","orderNumber":"1001","counterpartyId":"u1",'
          '"counterpartyName":"Zé","deadline":"2026-08-15T00:00:00Z"}]',
        ),
        _resp(
          200,
          '{"summary":{"average":0,"activeRate":0,"count":0},"data":[]}',
        ),
        // Após avaliar, a lista de pendentes é recarregada e o pedido
        // avaliado já não deve mais aparecer.
        _resp(200, '[]'),
      ];
      servidor.respostas['/orders/p1/reviews'] = [
        _resp(201, '{"id":"r1","orderId":"p1","targetId":"u1","rating":5,"createdAt":null}'),
      ];

      final controlador = ControladorAvaliacoes(
        repositorio: RepositorioAvaliacoes(_api(servidor)),
      );
      await controlador.carregar();

      expect(controlador.pendentes, isA<Pronto<List<AvaliacaoPendente>>>());
      expect(controlador.recebidas, isA<Pronto<RespostaAvaliacoesRecebidas>>());

      final ok = await controlador.avaliar('p1', rating: 5);

      expect(ok, isTrue);
      expect(controlador.pendentes, isA<Vazio<List<AvaliacaoPendente>>>());
    });

    test('erro do servidor ao avaliar não derruba o app: mensagem exposta', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/reviews'] = [
        _resp(200, '[]'),
        _resp(200, '{"summary":{"average":0,"activeRate":0,"count":0},"data":[]}'),
      ];
      servidor.respostas['/orders/p1/reviews'] = [
        _resp(
          422,
          '{"error":{"code":"ALREADY_REVIEWED","message":"Você já avaliou este pedido.",'
          '"rule":"RN-19.2"}}',
        ),
      ];

      final controlador = ControladorAvaliacoes(
        repositorio: RepositorioAvaliacoes(_api(servidor)),
      );
      await controlador.carregar();

      final ok = await controlador.avaliar('p1', rating: 5);

      expect(ok, isFalse);
      expect(controlador.erroEnvio, contains('já avaliou'));
    });
  });

  group('ControladorScore — RF-A12.4/RF-A12.5/critério 8', () {
    test('sem nota ainda (404), score fica nulo — nunca "0,0" fingido', () async {
      final servidor = _Servidor();
      // Sem entrada para '/me/score': o fake devolve 404 por padrão.

      final controlador = ControladorScore(
        repositorio: RepositorioScore(_api(servidor)),
      );
      await controlador.carregar();

      expect(controlador.estado, isA<Falhou<dynamic>>());
      expect(controlador.score, isNull);
    });

    test('com nota, expõe valor e componentes sem recalcular nada', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/score'] = [
        _resp(
          200,
          '{"value":"4.8","window":"90d","calculatedAt":"2026-08-10T00:00:00Z",'
          '"components":[{"metric":"activeReviewsAverage","value":"4.8","weight":0.6,'
          '"contribution":"2.88"}],"penalties":[]}',
        ),
      ];

      final controlador = ControladorScore(
        repositorio: RepositorioScore(_api(servidor)),
      );
      await controlador.carregar();

      expect(controlador.score?.valor, '4.8');
      expect(controlador.score?.componentes, hasLength(1));
      expect(controlador.score?.componentes.first.metrica, 'activeReviewsAverage');
    });
  });
}
