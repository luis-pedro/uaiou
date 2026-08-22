import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/bloqueios/bloqueio.dart';
import 'package:uaiou/core/bloqueios/estado_bloqueios.dart';
import 'package:uaiou/core/bloqueios/repositorio_bloqueios.dart';
import 'package:uaiou/core/estado/carregavel.dart';
import 'package:uaiou/core/financeiro/creditos.dart';
import 'package:uaiou/core/financeiro/repositorio_creditos.dart';
import 'package:uaiou/core/gamificacao/repositorio_score.dart';
import 'package:uaiou/core/gamificacao/score.dart';
import 'package:uaiou/core/rede/cliente_api.dart';

class _RespostaFixa implements HttpClientAdapter {
  final Object? corpo;
  final int status;
  RequestOptions? ultimaRequisicao;

  _RespostaFixa(this.corpo, {this.status = 200});

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ultimaRequisicao = options;
    return ResponseBody.fromString(
      jsonEncode(corpo),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

ClienteApi _apiCom(Object corpo, {int status = 200}) {
  final dio = Dio()..httpClientAdapter = _RespostaFixa(corpo, status: status);
  return ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1');
}

void main() {
  group('Score — GET /me/score (RF-A05.4)', () {
    test('parseia value, window, calculatedAt e components', () {
      final score = Score.doJson({
        'value': '87.50',
        'window': '30d',
        'calculatedAt': '2026-07-22T03:00:00Z',
        'components': [
          {
            'metric': 'activeReviewsAverage',
            'value': '4.80',
            'weight': 0.35,
            'contribution': '33.60',
          },
        ],
      });

      expect(score.valor, '87.50');
      expect(score.janela, '30d');
      expect(score.calculadoEm, isNotNull);
      expect(score.componentes.single.metrica, 'activeReviewsAverage');
      expect(score.componentes.single.peso, 0.35);
    });

    test('estabelecimento traz penalties com orderId', () {
      final score = Score.doJson({
        'value': '72.00',
        'window': '30d',
        'penalties': [
          {
            'rule': 'RN-09.3',
            'reason': 'Código não repassado',
            'points': -2,
            'orderId': 'b0f2',
          },
        ],
      });

      expect(score.penalidades.single.pedidoId, 'b0f2');
      expect(score.penalidades.single.pontos, -2);
    });

    test('RepositorioScore chama GET /me/score', () async {
      final api = _apiCom({'value': '87.50', 'window': '30d'});
      final score = await RepositorioScore(api).obter();
      expect(score.valor, '87.50');
    });
  });

  group('Creditos — GET /me/credits (RF-A05.5)', () {
    test('parseia saldo e assinatura', () {
      final creditos = Creditos.doJson({
        'creditsBalance': 42,
        'subscription': {
          'planName': 'Essencial',
          'monthlyCredits': 100,
          'consumedThisCycle': 58,
          'renewsAt': '2026-08-01',
          'status': 'active',
        },
      });

      expect(creditos.saldo, 42);
      expect(creditos.assinatura?.consumidosNoCiclo, 58);
      expect(creditos.assinatura?.creditosMensais, 100);
    });

    test('sem assinatura, o campo fica nulo em vez de quebrar', () {
      final creditos = Creditos.doJson({'creditsBalance': 0});
      expect(creditos.assinatura, isNull);
    });

    test('RepositorioCreditos chama GET /me/credits', () async {
      final api = _apiCom({'creditsBalance': 10});
      final creditos = await RepositorioCreditos(api).obter();
      expect(creditos.saldo, 10);
    });
  });

  group('Bloqueios — GET/POST/DELETE /me/blocked-couriers (RF-A05.6)', () {
    test('EntregadorBloqueado.doJson lê courierId, courierName e reason', () {
      final bloqueado = EntregadorBloqueado.doJson({
        'courierId': '3f7a',
        'courierName': 'Pedro',
        'reason': 'Atraso recorrente',
        'blockedAt': '2026-07-22T20:14:00Z',
      });

      expect(bloqueado.entregadorId, '3f7a');
      expect(bloqueado.nome, 'Pedro');
      expect(bloqueado.motivo, 'Atraso recorrente');
    });

    test('bloquear() manda POST com courierId e reason', () async {
      final adaptador = _RespostaFixa({
        'courierId': '3f7a',
        'courierName': 'Pedro',
      }, status: 201);
      final dio = Dio()..httpClientAdapter = adaptador;
      final api = ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1');

      await RepositorioBloqueios(
        api,
      ).bloquear(entregadorId: '3f7a', motivo: 'Atraso');

      expect(adaptador.ultimaRequisicao?.method, 'POST');
      expect(adaptador.ultimaRequisicao?.path, '/me/blocked-couriers');
      expect(adaptador.ultimaRequisicao?.data, {
        'courierId': '3f7a',
        'reason': 'Atraso',
      });
    });

    test('desbloquear() manda DELETE no id do entregador', () async {
      final adaptador = _RespostaFixa(null, status: 204);
      final dio = Dio()..httpClientAdapter = adaptador;
      final api = ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1');

      await RepositorioBloqueios(api).desbloquear('3f7a');

      expect(adaptador.ultimaRequisicao?.method, 'DELETE');
      expect(adaptador.ultimaRequisicao?.path, '/me/blocked-couriers/3f7a');
    });

    test('EstadoBloqueios: lista vazia vira Vazio, não Pronto([])', () async {
      final api = _apiCom(<dynamic>[]);
      final estado = EstadoBloqueios(repositorio: RepositorioBloqueios(api));

      await estado.carregar();

      expect(estado.estado, isA<Vazio<List<EntregadorBloqueado>>>());
    });

    test('EstadoBloqueios: lista com itens vira Pronto', () async {
      final api = _apiCom([
        {'courierId': '3f7a', 'courierName': 'Pedro'},
      ]);
      final estado = EstadoBloqueios(repositorio: RepositorioBloqueios(api));

      await estado.carregar();

      expect(estado.estado, isA<Pronto<List<EntregadorBloqueado>>>());
      expect(estado.estado.valorOuNulo?.single.nome, 'Pedro');
    });
  });
}
