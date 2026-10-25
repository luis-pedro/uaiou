import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/rotas/modelo_rota.dart';
import 'package:uaiou/core/rotas/modelo_roteiro.dart';

void main() {
  final corpo = <String, dynamic>{
    'available': true,
    'optimized': true,
    'roadDistanceKm': 4.2,
    'durationMinutes': 9,
    'geometry': [
      {'lat': 0.0, 'lng': 0.0},
      {'lat': 0.01, 'lng': 0.0},
      {'lat': 0.02, 'lng': 0.0},
      {'lat': 0.03, 'lng': 0.0},
    ],
    'steps': [
      {
        'instruction': 'Siga pela Rua A',
        'distanceMeters': 100,
        'pointIndex': 0,
      },
    ],
    'stops': [
      {
        'orderId': 'b',
        'kind': 'PICKUP',
        'location': {'lat': 0.01, 'lng': 0.0},
        'pointIndex': 1,
      },
      {
        'orderId': 'b',
        'kind': 'DROPOFF',
        'location': {'lat': 0.02, 'lng': 0.0},
        'pointIndex': 2,
      },
      {'orderId': 'a', 'kind': 'DROPOFF', 'pointIndex': 3},
      {'orderId': 'x', 'kind': 'DESCONHECIDO'},
    ],
    'attribution': '© OpenStreetMap contributors',
  };

  test(
    'lê o trajeto da raiz e as paradas em ordem, descartando tipos desconhecidos',
    () {
      final roteiro = RoteiroDoEntregador.doJson(corpo);

      expect(roteiro.temTracado, isTrue);
      expect(roteiro.otimizado, isTrue);
      expect(roteiro.trajeto.distanciaPorViaKm, 4.2);
      expect(roteiro.trajeto.passos, hasLength(1));
      expect(roteiro.paradas.map((p) => '${p.pedidoId}:${p.tipo.name}'), [
        'b:coleta',
        'b:entrega',
        'a:entrega',
      ]);
      expect(
        roteiro.comoRotaDoPedido().atribuicao,
        '© OpenStreetMap contributors',
      );
    },
  );

  test('a próxima parada é a primeira ainda à frente no traçado', () {
    final roteiro = RoteiroDoEntregador.doJson(corpo);

    expect(roteiro.proximaParadaDe(null)?.tipo, TipoParada.coleta);
    final passouDaColeta = roteiro.proximaParadaDe(const PontoGeo(0.019, 0));
    expect(passouDaColeta?.pedidoId, 'b');
    expect(passouDaColeta?.tipo, TipoParada.entrega);
  });

  test('sem pedidos em andamento é distinto de sem traçado', () {
    final vazio = RoteiroDoEntregador.doJson({
      'available': false,
      'unavailableReason': 'NO_ACTIVE_ORDERS',
      'stops': <Object>[],
    });

    expect(vazio.semPedidos, isTrue);
    expect(vazio.temTracado, isFalse);
  });
}
