import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/estado/carregavel.dart';
import 'package:uaiou/core/rede/cliente_api.dart';
import 'package:uaiou/core/rotas/controlador_rota.dart';
import 'package:uaiou/core/rotas/modelo_rota.dart';
import 'package:uaiou/core/rotas/repositorio_rotas.dart';

/// Fake de transporte no mesmo padrão de `entregas_test.dart`: conta
/// requisições por rota, que é o que o critério de aceite 9 (uma rota
/// por abertura) exige afirmar.
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

ControladorRota _montar(_Servidor servidor) {
  final dio = Dio()..httpClientAdapter = servidor;
  return ControladorRota(
    repositorio: RepositorioRotas(
      ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1'),
    ),
  );
}

/// Uma rota só, passando pela loja: quatro pontos e duas manobras.
const _rotaUnica = '''
{
  "orderId": "p1",
  "straightLineDistanceKm": 2.1,
  "route": {
    "available": true,
    "includesPickup": true,
    "roadDistanceKm": 3.0,
    "durationMinutes": 9,
    "geometry": [
      {"lat": -19.9180, "lng": -43.9380},
      {"lat": -19.9250, "lng": -43.9370},
      {"lat": -19.9300, "lng": -43.9350},
      {"lat": -19.9251, "lng": -43.9417}
    ],
    "steps": [
      {"instruction": "Siga em frente na Rua A", "distanceMeters": 400, "pointIndex": 0},
      {"instruction": "Vire à direita na Rua B", "distanceMeters": 250, "pointIndex": 2}
    ]
  },
  "attribution": "Powered by Geoapify"
}
''';

/// Estabelecimento que nunca marcou o ponto no mapa (RF-25.5): a rota
/// existe, mas vai direto ao destino.
const _semPassarPelaLoja = '''
{
  "orderId": "p1",
  "straightLineDistanceKm": 2.1,
  "route": {
    "available": true,
    "includesPickup": false,
    "roadDistanceKm": 2.4,
    "durationMinutes": 7,
    "geometry": [
      {"lat": -19.9180, "lng": -43.9380},
      {"lat": -19.9251, "lng": -43.9417}
    ],
    "steps": []
  }
}
''';

const _provedorForaDoAr = '''
{
  "orderId": "p1",
  "straightLineDistanceKm": 2.1,
  "route": {"available": false, "unavailableReason": "ROUTING_UNAVAILABLE"}
}
''';

void main() {
  group('leitura da rota', () {
    test('uma rota só, passando pela loja, com traçado e instruções', () async {
      final servidor = _Servidor()
        ..respostas['/orders/p1/route'] = [_resp(200, _rotaUnica)];
      final controlador = _montar(servidor);

      await controlador.carregar('p1');
      final trajeto = controlador.rota!.trajeto;

      expect(trajeto.temTracado, isTrue);
      expect(trajeto.passaPelaRetirada, isTrue);
      expect(trajeto.distanciaPorViaKm, 3.0);
      expect(trajeto.duracaoMinutos, 9);
      expect(trajeto.geometria, hasLength(4));
      expect(trajeto.passos, hasLength(2));
      expect(controlador.rota!.atribuicao, isNotNull);
    });

    /// RF-A14.5 — a linha reta continua existindo, com nome próprio.
    test('linha reta e distância por via são campos distintos', () async {
      final servidor = _Servidor()
        ..respostas['/orders/p1/route'] = [_resp(200, _rotaUnica)];
      final controlador = _montar(servidor);

      await controlador.carregar('p1');

      expect(controlador.rota!.distanciaEmLinhaRetaKm, 2.1);
      expect(controlador.rota!.trajeto.distanciaPorViaKm, 3.0);
    });

    /// RF-25.5: sem coordenada da loja o trajeto existe do mesmo jeito —
    /// e a tela precisa saber que ele não passa pela retirada.
    test('sem ponto do estabelecimento a rota vai direto ao destino', () async {
      final servidor = _Servidor()
        ..respostas['/orders/p1/route'] = [_resp(200, _semPassarPelaLoja)];
      final controlador = _montar(servidor);

      await controlador.carregar('p1');

      expect(controlador.rota!.trajeto.temTracado, isTrue);
      expect(controlador.rota!.trajeto.passaPelaRetirada, isFalse);
    });

    /// Provedor indisponível não vira exceção nem estado de erro — a
    /// tela de entrega segue inteira (RF-A14.6).
    test('provedor fora do ar responde 200 sem traçado', () async {
      final servidor = _Servidor()
        ..respostas['/orders/p1/route'] = [_resp(200, _provedorForaDoAr)];
      final controlador = _montar(servidor);

      await controlador.carregar('p1');

      expect(controlador.estado.temConteudo, isTrue);
      expect(controlador.rota!.trajeto.temTracado, isFalse);
      expect(controlador.rota!.trajeto.explicacao, contains('não está disponível'));
    });

    test('falha de rede não lança e não derruba o controlador', () async {
      final servidor = _Servidor()
        ..respostas['/orders/p1/route'] = [_resp(500, '{}')];
      final controlador = _montar(servidor);

      await controlador.carregar('p1');

      expect(controlador.estado, isA<Falhou<RotaDoPedido>>());
      expect(controlador.rota, isNull);
    });
  });

  group('navegação no app', () {
    late Trajeto trajeto;

    setUp(() async {
      final servidor = _Servidor()
        ..respostas['/orders/p1/route'] = [_resp(200, _rotaUnica)];
      final controlador = _montar(servidor);
      await controlador.carregar('p1');
      trajeto = controlador.rota!.trajeto;
    });

    /// A manobra exibida é a próxima **à frente**, não a mais próxima em
    /// qualquer direção: parado depois da primeira curva, quem interessa
    /// é a segunda.
    test('o passo mostrado é o próximo à frente da posição', () {
      const noComeco = PontoGeo(-19.9180, -43.9380);
      const jaNaSegundaMetade = PontoGeo(-19.9300, -43.9350);

      expect(
        trajeto.proximoPassoDe(noComeco)!.instrucao,
        'Siga em frente na Rua A',
      );
      expect(
        trajeto.proximoPassoDe(jaNaSegundaMetade)!.instrucao,
        'Vire à direita na Rua B',
      );
    });

    /// Sem posição do aparelho a tela ainda mostra por onde começar, em
    /// vez de ficar vazia.
    test('sem posição, mostra o primeiro passo', () {
      expect(trajeto.proximoPassoDe(null)!.instrucao, 'Siga em frente na Rua A');
    });

    /// A distância até a manobra é medida **pelo traçado**, somando os
    /// trechos — não em linha reta até a curva.
    test('a distância até a manobra segue o caminho, não a linha reta', () {
      const noComeco = PontoGeo(-19.9180, -43.9380);
      final passo = trajeto.passos[1];

      final pelaRota = trajeto.metrosAte(passo, noComeco)!;
      final emLinhaReta = noComeco.metrosAte(trajeto.geometria[2]);

      expect(pelaRota, greaterThan(emLinhaReta));
    });

    test('o restante encolhe conforme o entregador avança', () {
      const noComeco = PontoGeo(-19.9180, -43.9380);
      const quaseNoFim = PontoGeo(-19.9251, -43.9417);

      expect(
        trajeto.metrosRestantes(quaseNoFim),
        lessThan(trajeto.metrosRestantes(noComeco)!),
      );
    });
  });

  group('consumo do provedor', () {
    /// Critério de aceite 9 / RNF-A14.1: reabrir a tela não pode
    /// disparar chamada nova para o mesmo pedido — é o que impede a rota
    /// de pegar carona no polling.
    test('abrir o mesmo pedido de novo não vai à rede', () async {
      final servidor = _Servidor()
        ..respostas['/orders/p1/route'] = [_resp(200, _rotaUnica)];
      final controlador = _montar(servidor);

      await controlador.carregar('p1');
      await controlador.carregar('p1');
      await controlador.carregar('p1');

      expect(controlador.consultasFeitas, 1);
      expect(servidor.chamadas.length, 1);
    });

    test('outro pedido busca a rota dele', () async {
      final servidor = _Servidor()
        ..respostas['/orders/p1/route'] = [_resp(200, _rotaUnica)]
        ..respostas['/orders/p2/route'] = [_resp(200, _rotaUnica)];
      final controlador = _montar(servidor);

      await controlador.carregar('p1');
      await controlador.carregar('p2');

      expect(servidor.chamadas.length, 2);
    });

    /// "Recalcular" na tela de navegação é a única forma de refazer a
    /// rota para o mesmo pedido: o app não recalcula sozinho a cada
    /// desvio, senão a cota do provedor iria embora sem teto.
    test('recalcular é a única repetição de chamada', () async {
      final servidor = _Servidor()
        ..respostas['/orders/p1/route'] = [_resp(200, _rotaUnica)];
      final controlador = _montar(servidor);

      await controlador.carregar('p1');
      await controlador.recarregar();

      expect(servidor.chamadas.length, 2);
    });
  });
}
