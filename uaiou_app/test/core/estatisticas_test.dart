import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/estado/carregavel.dart';
import 'package:uaiou/core/estatisticas/controlador_estatisticas.dart';
import 'package:uaiou/core/estatisticas/modelo_estatisticas.dart';
import 'package:uaiou/core/estatisticas/repositorio_estatisticas.dart';
import 'package:uaiou/core/rede/cliente_api.dart';

/// Mesmo fake de transporte das demais suítes de A-09.
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

ControladorEstatisticas _montar(_Servidor servidor) {
  final dio = Dio()..httpClientAdapter = servidor;
  final api = ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1');
  return ControladorEstatisticas(repositorio: RepositorioEstatisticas(api));
}

const _respostaStats = '''
{
  "period": {"label": "30d", "from": "2026-07-11T00:00:00Z", "to": "2026-08-10T00:00:00Z"},
  "deliveriesCompleted": 48,
  "earningsReceivable": "6.00",
  "earningsSettled": "306.00",
  "averageTicket": "6.50",
  "counterofferSuccessRate": 0.42,
  "averageDeliveryMinutes": 23.5,
  "cleanFinalizationRate": 0.92,
  "availableHours": null,
  "utilization": null
}
''';

void main() {
  group('EstatisticasEntregador.doJson — RF-A09.7', () {
    test('lê contagens e taxas do contrato', () {
      final stats = EstatisticasEntregador.doJson(
        Map<String, dynamic>.from({
          'period': {'from': '2026-07-11T00:00:00Z', 'to': '2026-08-10T00:00:00Z'},
          'deliveriesCompleted': 48,
          'counterofferSuccessRate': 0.42,
          'averageDeliveryMinutes': 23.5,
          'cleanFinalizationRate': 0.92,
        }),
      );

      expect(stats.entregasConcluidas, 48);
      expect(stats.taxaSucessoContraoferta, 0.42);
      expect(stats.tempoMedioDeEntregaMin, 23.5);
      expect(stats.taxaFinalizacaoLimpa, 0.92);
    });

    test('availableHours/utilization ausentes viram nulo, não zero', () {
      final stats = EstatisticasEntregador.doJson({'deliveriesCompleted': 0});
      expect(stats.horasDisponiveis, isNull);
      expect(stats.utilizacao, isNull);
    });
  });

  group('ControladorEstatisticas.carregar', () {
    test('GET /me/stats popula o estado pronto', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/stats'] = [_resp(200, _respostaStats)];

      final controlador = _montar(servidor);
      await controlador.carregar();

      expect(controlador.estado, isA<Pronto<EstatisticasEntregador>>());
      final stats = (controlador.estado as Pronto<EstatisticasEntregador>).valor;
      expect(stats.entregasConcluidas, 48);
      expect(stats.taxaFinalizacaoLimpa, 0.92);
    });

    test('period vira query param quando informado', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/stats'] = [_resp(200, _respostaStats)];

      final controlador = _montar(servidor);
      await controlador.carregar(periodo: '30d');

      final requisicao = servidor.chamadas.firstWhere((r) => r.path.contains('/me/stats'));
      expect(requisicao.queryParameters['period'], '30d');
    });

    test('erro do servidor vira estado Falhou', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/stats'] = [
        _resp(500, '{"error":{"code":"UNEXPECTED","message":"Algo deu errado."}}'),
      ];

      final controlador = _montar(servidor);
      await controlador.carregar();

      expect(controlador.estado, isA<Falhou<EstatisticasEntregador>>());
    });
  });

  group('ControladorEstatisticas.limpar — RF-A03.9', () {
    test('descarta o estado no logout', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/stats'] = [_resp(200, _respostaStats)];

      final controlador = _montar(servidor);
      await controlador.carregar();
      controlador.limpar();

      expect(controlador.estado, isA<Carregando<EstatisticasEntregador>>());
    });
  });
}
