import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/estado/carregavel.dart';
import 'package:uaiou/core/ganhos/controlador_ganhos.dart';
import 'package:uaiou/core/ganhos/modelo_ganhos.dart';
import 'package:uaiou/core/ganhos/repositorio_ganhos.dart';
import 'package:uaiou/core/modelos/dinheiro.dart';
import 'package:uaiou/core/rede/cliente_api.dart';

/// Fake de transporte que enfileira respostas por rota e registra toda
/// requisição — mesmo padrão de `entregas_test.dart`/`vitrine_test.dart`.
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

ControladorGanhos _montar(_Servidor servidor) {
  final dio = Dio()..httpClientAdapter = servidor;
  final api = ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1');
  return ControladorGanhos(repositorio: RepositorioGanhos(api));
}

const _respostaPagina1 = '''
{
  "summary": {"total": "16.00", "receivable": "6.00", "settled": "10.00"},
  "data": [
    {
      "id": "l1",
      "orderId": "p1",
      "orderNumber": "1001",
      "amount": "6.00",
      "status": "receivable",
      "createdAt": "2026-08-09T18:00:00Z",
      "settledAt": null
    },
    {
      "id": "l2",
      "orderId": "p2",
      "orderNumber": "1002",
      "amount": "10.00",
      "status": "settled",
      "createdAt": "2026-08-08T18:00:00Z",
      "settledAt": "2026-08-09T09:00:00Z"
    }
  ],
  "meta": {"page": 1, "perPage": 2, "total": 3},
  "_links": {"next": {"href": "/api/v1/me/earnings?page=2&perPage=2"}}
}
''';

const _respostaPagina2 = '''
{
  "summary": {"total": "16.00", "receivable": "6.00", "settled": "10.00"},
  "data": [
    {
      "id": "l3",
      "orderId": "p3",
      "orderNumber": "1003",
      "amount": "0.00",
      "status": "settled",
      "createdAt": "2026-08-07T18:00:00Z",
      "settledAt": "2026-08-07T20:00:00Z"
    }
  ],
  "meta": {"page": 2, "perPage": 2, "total": 3},
  "_links": {}
}
''';

void main() {
  group('RespostaGanhos.doJson — RF-A09.1/RF-A09.5', () {
    test('lê summary e cada lançamento, incluindo status e datas', () {
      final resposta = RespostaGanhos.doJson(
        Map<String, dynamic>.from({
          'summary': {'total': '16.00', 'receivable': '6.00', 'settled': '10.00'},
          'data': [
            {
              'id': 'l1',
              'orderId': 'p1',
              'orderNumber': '1001',
              'amount': '6.00',
              'status': 'receivable',
              'createdAt': '2026-08-09T18:00:00Z',
            },
          ],
          'meta': {'page': 1, 'perPage': 20, 'total': 1},
          '_links': {},
        }),
      );

      expect(resposta.resumo.total, Dinheiro.deString('16.00'));
      expect(resposta.resumo.receivable, Dinheiro.deString('6.00'));
      expect(resposta.resumo.settled, Dinheiro.deString('10.00'));
      expect(resposta.pagina.itens, hasLength(1));
      expect(resposta.pagina.itens.first.status, StatusLancamento.aReceber);
      expect(resposta.pagina.itens.first.aReceber, isTrue);
      expect(resposta.pagina.itens.first.orderNumber, '1001');
    });

    test('status "settled" vira StatusLancamento.recebido', () {
      final lancamento = Lancamento.doJson({
        'id': 'l2',
        'orderId': 'p2',
        'orderNumber': '1002',
        'amount': '10.00',
        'status': 'settled',
        'settledAt': '2026-08-09T09:00:00Z',
      });

      expect(lancamento.status, StatusLancamento.recebido);
      expect(lancamento.aReceber, isFalse);
      expect(lancamento.settledAt, isNotNull);
    });
  });

  group('RNF-A09.1 — dinheiro exibido nunca perde precisão', () {
    test('"0.10" somado dez vezes exibe R\$ 1,00', () {
      final soma = List.generate(10, (_) => Dinheiro.deString('0.10')).soma;
      expect(soma.formatarBRL(), 'R\$ 1,00');
    });

    test('summary preserva "1234.56" exatamente', () {
      final resumo = ResumoGanhos.doJson({
        'total': '1234.56',
        'receivable': '0.00',
        'settled': '1234.56',
      });
      expect(resumo.total.formatarBRL(), 'R\$ 1.234,56');
    });
  });

  group('ControladorGanhos.carregar — RF-A09.1', () {
    test('nunca soma lançamentos: o total exibido é o summary do servidor', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/earnings'] = [_resp(200, _respostaPagina1)];

      final controlador = _montar(servidor);
      await controlador.carregar();

      // RNF-A09.2: soma dos itens listados bate com o total do resumo
      // (verificação de consistência), mas o valor exibido vem de
      // `resumo`, não de uma soma feita aqui.
      final somaListada = controlador.lancamentos.map((l) => l.amount).toList().soma;
      expect(somaListada, controlador.resumo.total);
      expect(controlador.resumo.receivable.formatarBRL(), 'R\$ 6,00');
      expect(controlador.resumo.settled.formatarBRL(), 'R\$ 10,00');
      expect(controlador.temMais, isTrue);
    });
  });

  group('ControladorGanhos.carregarMais — RF-A09.6', () {
    test('segue _links.next e acumula os itens', () async {
      // O fake de transporte identifica a rota só pelo caminho (sem
      // query string, ver `_Servidor.fetch`), então a segunda página
      // entra na mesma fila — igual ao padrão de `entregas_test.dart`.
      final servidor = _Servidor();
      servidor.respostas['/me/earnings'] = [
        _resp(200, _respostaPagina1),
        _resp(200, _respostaPagina2),
      ];

      final controlador = _montar(servidor);
      await controlador.carregar();
      expect(controlador.lancamentos, hasLength(2));

      await controlador.carregarMais();

      expect(controlador.lancamentos, hasLength(3));
      expect(controlador.temMais, isFalse);
    });
  });

  group('ControladorGanhos.confirmarSelecionados — RF-A09.3/RF-A09.4', () {
    test('envia lancamentoIds (em português) e recarrega o extrato', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/earnings'] = [
        _resp(200, _respostaPagina1),
        _resp(
          200,
          '{"summary": {"total": "10.00", "receivable": "0.00", "settled": "10.00"}, '
          '"data": [], "meta": {"page":1,"perPage":20,"total":0}, "_links": {}}',
        ),
      ];
      servidor.respostas['/me/earnings/settlements'] = [
        _resp(200, '{"settled": ["l1"], "settledAt": "2026-08-10T12:00:00Z"}'),
      ];

      final controlador = _montar(servidor);
      await controlador.carregar();
      controlador.alternarSelecao('l1');

      final ok = await controlador.confirmarSelecionados();

      expect(ok, isTrue);
      expect(controlador.selecionados, isEmpty);

      final requisicao = servidor.chamadas.firstWhere(
        (r) => r.path.contains('settlements'),
      );
      expect(requisicao.method, 'POST');
      // O contrato exige literalmente `lancamentoIds`, em português —
      // `financeiro.md` descreve rota antiga e não cobre este campo.
      expect(requisicao.data, {
        'lancamentoIds': ['l1'],
      });
    });

    test('sem seleção, não dispara requisição', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/earnings'] = [_resp(200, _respostaPagina1)];

      final controlador = _montar(servidor);
      await controlador.carregar();

      final ok = await controlador.confirmarSelecionados();

      expect(ok, isFalse);
      expect(
        servidor.chamadas.where((r) => r.path.contains('settlements')).length,
        0,
      );
    });

    test('duas confirmações simultâneas: só uma dispara requisição — reentrância', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/earnings'] = [
        _resp(200, _respostaPagina1),
        _resp(200, _respostaPagina1),
      ];
      servidor.respostas['/me/earnings/settlements'] = [
        _resp(200, '{"settled": ["l1"], "settledAt": "2026-08-10T12:00:00Z"}'),
      ];

      final controlador = _montar(servidor);
      await controlador.carregar();
      controlador.alternarSelecao('l1');

      final r1 = controlador.confirmarSelecionados();
      final r2 = controlador.confirmarSelecionados();
      final resultados = await Future.wait([r1, r2]);

      expect(resultados.where((r) => r).length, 1);
      expect(
        servidor.chamadas.where((r) => r.path.contains('settlements')).length,
        1,
      );
    });

    test('erro do servidor não limpa a seleção e expõe a mensagem', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/earnings'] = [_resp(200, _respostaPagina1)];
      servidor.respostas['/me/earnings/settlements'] = [
        _resp(
          422,
          '{"error":{"code":"ALREADY_SETTLED","message":"Este lançamento já foi acertado.","rule":"RN-18.4"}}',
        ),
      ];

      final controlador = _montar(servidor);
      await controlador.carregar();
      controlador.alternarSelecao('l1');

      final ok = await controlador.confirmarSelecionados();

      expect(ok, isFalse);
      expect(controlador.erro, contains('já foi acertado'));
      expect(controlador.selecionados, contains('l1'));
    });
  });

  group('ControladorGanhos.limpar — RF-A03.9', () {
    test('descarta estado, resumo e seleção no logout', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/earnings'] = [_resp(200, _respostaPagina1)];

      final controlador = _montar(servidor);
      await controlador.carregar();
      controlador.alternarSelecao('l1');

      controlador.limpar();

      expect(controlador.estado, isA<Carregando<List<Lancamento>>>());
      expect(controlador.resumo.total.eZero, isTrue);
      expect(controlador.selecionados, isEmpty);
    });
  });
}
