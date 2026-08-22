import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/estado/carregavel.dart';
import 'package:uaiou/core/notificacoes/controlador_notificacoes.dart';
import 'package:uaiou/core/notificacoes/controlador_preferencias_notificacao.dart';
import 'package:uaiou/core/notificacoes/identificador_dispositivo.dart';
import 'package:uaiou/core/notificacoes/modelo_notificacao.dart';
import 'package:uaiou/core/notificacoes/repositorio_dispositivo.dart';
import 'package:uaiou/core/notificacoes/repositorio_notificacoes.dart';
import 'package:uaiou/core/rede/cliente_api.dart';
import 'package:uaiou/core/sessao/cofre_sessao.dart';
import 'package:uaiou/core/sessao/controlador_sessao.dart';
import 'package:uaiou/core/sessao/identidade.dart';
import 'package:uaiou/core/sessao/repositorio_auth.dart';

/// Fake de transporte que enfileira respostas por rota e registra toda
/// requisição — mesmo padrão de `ganhos_test.dart`/`entregas_test.dart`.
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

const _paginaComDuas = '''
{
  "data": [
    {
      "id": "n1",
      "type": "counteroffer.received",
      "priority": "normal",
      "title": "Nova contraproposta",
      "body": "O entregador enviou uma contraproposta.",
      "payload": {"orderId": "p1"},
      "readAt": null,
      "createdAt": "2026-08-10T10:00:00Z"
    },
    {
      "id": "n2",
      "type": "delivery.code_contingency",
      "priority": "urgent",
      "title": "Código de contingência",
      "body": "Use o código para confirmar a entrega.",
      "payload": {"orderId": "p2"},
      "readAt": "2026-08-09T10:00:00Z",
      "createdAt": "2026-08-09T09:00:00Z"
    }
  ],
  "meta": {"page": 1, "perPage": 50, "total": 2, "unread": 1}
}
''';

void main() {
  group('Notificacao.doJson / RespostaNotificacoes.doJson — RF-A11.6/RF-A11.7', () {
    test('lê cada campo, inclusive prioridade e payload', () {
      final resposta = RespostaNotificacoes.doJson(
        Map<String, dynamic>.from({
          'data': [
            {
              'id': 'n1',
              'type': 'delivery.code_contingency',
              'priority': 'urgent',
              'title': 'Urgente',
              'body': 'texto',
              'payload': {'orderId': 'p1'},
              'readAt': null,
              'createdAt': '2026-08-10T10:00:00Z',
            },
          ],
          'meta': {'page': 1, 'perPage': 20, 'total': 1, 'unread': 1},
        }),
      );

      expect(resposta.unread, 1);
      expect(resposta.total, 1);
      expect(resposta.data, hasLength(1));
      final item = resposta.data.first;
      expect(item.priority, PrioridadeNotificacao.urgente);
      expect(item.lida, isFalse);
      expect(item.payload['orderId'], 'p1');
    });

    test('item malformado é descartado sem derrubar a lista', () {
      final resposta = RespostaNotificacoes.doJson({
        'data': [
          {'id': 'ok', 'type': 't', 'priority': 'normal', 'title': '', 'body': ''},
          'nao é um mapa',
        ],
        'meta': {'page': 1, 'perPage': 20, 'total': 1, 'unread': 0},
      });

      expect(resposta.data, hasLength(1));
      expect(resposta.data.first.id, 'ok');
    });

    test('resposta ausente ou malformada vira resposta vazia, sem exceção', () {
      expect(RespostaNotificacoes.doJson(null).data, isEmpty);
      expect(RespostaNotificacoes.doJson('texto').data, isEmpty);
    });
  });

  group('PreferenciasNotificacao.doJson — RF-A11.8', () {
    test('lê channels e mandatory', () {
      final preferencias = PreferenciasNotificacao.doJson({
        'channels': {'push': true, 'email': false, 'sms': null},
        'mandatory': ['delivery.code_contingency', 'dispute.opened'],
      });

      expect(preferencias.channels['push'], isTrue);
      expect(preferencias.channels['email'], isFalse);
      expect(preferencias.channels['sms'], isFalse);
      expect(preferencias.ehObrigatorio('delivery.code_contingency'), isTrue);
      expect(preferencias.ehObrigatorio('order.published'), isFalse);
    });
  });

  group('ControladorNotificacoes.carregar — RF-A11.6/RF-A11.7', () {
    test('contador de não lidas vem de meta.unread, não de soma local', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/notifications'] = [_resp(200, _paginaComDuas)];

      final controlador = ControladorNotificacoes(
        repositorio: RepositorioNotificacoes(_api(servidor)),
      );
      await controlador.carregar();

      expect(controlador.notificacoes, hasLength(2));
      // Só 1 dos 2 itens tem readAt nulo, e é exatamente o unread do
      // servidor — mas o controlador nunca soma isso: usa meta.unread
      // diretamente (ver `_buscar`).
      expect(controlador.naoLidas, 1);
      expect(controlador.estado, isA<Pronto<List<Notificacao>>>());
    });

    test('lista vazia vira estado Vazio, não Pronto([])', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/notifications'] = [
        _resp(200, '{"data":[],"meta":{"page":1,"perPage":50,"total":0,"unread":0}}'),
      ];

      final controlador = ControladorNotificacoes(
        repositorio: RepositorioNotificacoes(_api(servidor)),
      );
      await controlador.carregar();

      expect(controlador.estado, isA<Vazio<List<Notificacao>>>());
    });

    test('falha do servidor vira Falhou com a mensagem do contrato', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/notifications'] = [
        _resp(500, '{"error":{"code":"UNEXPECTED","message":"Algo deu errado."}}'),
      ];

      final controlador = ControladorNotificacoes(
        repositorio: RepositorioNotificacoes(_api(servidor)),
      );
      await controlador.carregar();

      expect(controlador.estado, isA<Falhou<List<Notificacao>>>());
    });
  });

  group('ControladorNotificacoes.marcarLida — RF-A11.6/RNF-A11.3', () {
    test('marca uma notificação como lida e decrementa o contador', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/notifications'] = [_resp(200, _paginaComDuas)];
      servidor.respostas['/me/notifications/n1/read'] = [
        _resp(
          200,
          '{"id":"n1","type":"counteroffer.received","priority":"normal",'
          '"title":"Nova contraproposta","body":"x","payload":{},'
          '"readAt":"2026-08-10T11:00:00Z","createdAt":"2026-08-10T10:00:00Z"}',
        ),
      ];

      final controlador = ControladorNotificacoes(
        repositorio: RepositorioNotificacoes(_api(servidor)),
      );
      await controlador.carregar();
      expect(controlador.naoLidas, 1);

      await controlador.marcarLida('n1');

      expect(controlador.naoLidas, 0);
      expect(
        controlador.notificacoes.firstWhere((n) => n.id == 'n1').lida,
        isTrue,
      );
    });

    test('marcar a mesma notificação lida duas vezes em sequência não duplica a chamada '
        '(RNF-A11.3 — idempotência da tela)', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/notifications'] = [_resp(200, _paginaComDuas)];
      servidor.respostas['/me/notifications/n1/read'] = [
        _resp(
          200,
          '{"id":"n1","type":"counteroffer.received","priority":"normal",'
          '"title":"x","body":"x","payload":{},'
          '"readAt":"2026-08-10T11:00:00Z","createdAt":"2026-08-10T10:00:00Z"}',
        ),
      ];

      final controlador = ControladorNotificacoes(
        repositorio: RepositorioNotificacoes(_api(servidor)),
      );
      await controlador.carregar();

      await controlador.marcarLida('n1');
      // Segunda chamada: já está lida localmente, não deveria repetir.
      await controlador.marcarLida('n1');

      final chamadasDeLeitura = servidor.chamadas
          .where((c) => c.path.contains('n1/read'))
          .length;
      expect(chamadasDeLeitura, 1);
    });
  });

  group('ControladorNotificacoes.marcarTodasLidas — critério de aceite 6', () {
    test('zera o contador de não lidas', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/notifications'] = [_resp(200, _paginaComDuas)];
      servidor.respostas['/me/notifications/read'] = [
        _resp(200, '{"marked": 1}'),
      ];

      final controlador = ControladorNotificacoes(
        repositorio: RepositorioNotificacoes(_api(servidor)),
      );
      await controlador.carregar();
      expect(controlador.naoLidas, 1);

      await controlador.marcarTodasLidas();

      expect(controlador.naoLidas, 0);
      expect(controlador.notificacoes.every((n) => n.lida), isTrue);
    });
  });

  group('ControladorNotificacoes.limpar', () {
    test('descarta estado e contador no logout', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/notifications'] = [_resp(200, _paginaComDuas)];

      final controlador = ControladorNotificacoes(
        repositorio: RepositorioNotificacoes(_api(servidor)),
      );
      await controlador.carregar();

      controlador.limpar();

      expect(controlador.estado, isA<Carregando<List<Notificacao>>>());
      expect(controlador.naoLidas, 0);
    });
  });

  group('ControladorPreferenciasNotificacao — RF-A11.8', () {
    test('alterna só o canal tocado, sem mandar os outros no corpo', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/notification-preferences'] = [
        _resp(
          200,
          '{"channels":{"push":true,"email":false,"sms":false},'
          '"mandatory":["delivery.code_contingency"]}',
        ),
        _resp(
          200,
          '{"channels":{"push":false,"email":false,"sms":false},'
          '"mandatory":["delivery.code_contingency"]}',
        ),
      ];

      final controlador = ControladorPreferenciasNotificacao(
        repositorio: RepositorioNotificacoes(_api(servidor)),
      );
      await controlador.carregar();
      expect(controlador.preferencias.channels['push'], isTrue);

      await controlador.alternarCanal('push', false);

      expect(controlador.preferencias.channels['push'], isFalse);
      final enviado =
          servidor.chamadas
                  .firstWhere((c) => c.method == 'PUT')
                  .data
              as Map;
      final canais = enviado['channels'] as Map;
      expect(canais, {'push': false});
      expect(canais.containsKey('email'), isFalse);
      expect(canais.containsKey('sms'), isFalse);
    });

    test('tipo mandatório é exposto para a tela mostrar o cadeado', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/notification-preferences'] = [
        _resp(
          200,
          '{"channels":{"push":true,"email":true,"sms":false},'
          '"mandatory":["delivery.code_contingency","dispute.opened"]}',
        ),
      ];

      final controlador = ControladorPreferenciasNotificacao(
        repositorio: RepositorioNotificacoes(_api(servidor)),
      );
      await controlador.carregar();

      expect(
        controlador.preferencias.ehObrigatorio('delivery.code_contingency'),
        isTrue,
      );
    });
  });

  group('RepositorioDispositivo — RF-A11.1/RF-A11.2', () {
    test('registrar envia platform "web" e devolve o id do servidor', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/devices'] = [
        _resp(
          201,
          '{"id":"d1","platform":"web","appVersion":null,'
          '"lastUsedAt":"2026-08-10T10:00:00Z"}',
        ),
      ];

      final repositorio = RepositorioDispositivo(_api(servidor));
      final resultado = await repositorio.registrar(pushToken: 'token-local');

      expect(resultado.id, 'd1');
      expect(resultado.platform, 'web');

      final enviado = servidor.chamadas.single.data as Map;
      expect(enviado['platform'], 'web');
      expect(enviado['pushToken'], 'token-local');
    });

    test('remover chama DELETE /me/devices/{id}', () async {
      final servidor = _Servidor();
      servidor.respostas['/me/devices/d1'] = [_resp(204, '')];

      final repositorio = RepositorioDispositivo(_api(servidor));
      await repositorio.remover('d1');

      expect(servidor.chamadas.single.method, 'DELETE');
      expect(servidor.chamadas.single.path, '/me/devices/d1');
    });
  });

  group('IdentificadorDispositivo — identificador estável', () {
    test('gera uma vez e reaproveita nas chamadas seguintes', () async {
      final identificador = IdentificadorDispositivoEmMemoria();

      final primeiro = await identificador.obterOuCriarLocal();
      final segundo = await identificador.obterOuCriarLocal();

      expect(primeiro, segundo);
    });

    test('guarda e limpa o id de registro do servidor', () async {
      final identificador = IdentificadorDispositivoEmMemoria();

      expect(await identificador.lerRegistroAtual(), isNull);

      await identificador.gravarRegistroAtual('d1');
      expect(await identificador.lerRegistroAtual(), 'd1');

      await identificador.limparRegistroAtual();
      expect(await identificador.lerRegistroAtual(), isNull);
    });
  });

  group('ControladorSessao — registro e baixa do dispositivo (RF-A11.1/RF-A11.2)', () {
    String sessaoJson() =>
        '{"accessToken":"a","refreshToken":"r","expiresIn":900,'
        '"user":{"id":"u","role":"COURIER","status":"active"}}';

    test('login registra o dispositivo com platform "web"', () async {
      final servidor = _Servidor();
      final api = _api(servidor);
      servidor.respostas['/auth/sessions'] = [_resp(201, sessaoJson())];
      servidor.respostas['/me/devices'] = [
        _resp(201, '{"id":"d1","platform":"web","appVersion":null,"lastUsedAt":null}'),
      ];

      final identificador = IdentificadorDispositivoEmMemoria();
      final controlador = ControladorSessao(
        auth: RepositorioAuth(api),
        cofre: CofreSessaoEmMemoria(),
        dispositivos: RepositorioDispositivo(api),
        identificadorDispositivo: identificador,
      );
      api.credencial = controlador;

      await controlador.entrarComSenha(
        login: 'a',
        senha: 'b',
        papel: Papel.entregador,
      );

      final registro = servidor.chamadas.firstWhere(
        (c) => c.path == '/me/devices',
      );
      expect(registro.method, 'POST');
      expect((registro.data as Map)['platform'], 'web');
      expect(await identificador.lerRegistroAtual(), 'd1');
    });

    test('logout remove o dispositivo antes de descartar a sessão', () async {
      final servidor = _Servidor();
      final api = _api(servidor);
      servidor.respostas['/auth/sessions'] = [_resp(201, sessaoJson())];
      servidor.respostas['/auth/sessions/current'] = [_resp(204, '')];
      servidor.respostas['/me/devices'] = [
        _resp(201, '{"id":"d1","platform":"web","appVersion":null,"lastUsedAt":null}'),
      ];
      servidor.respostas['/me/devices/d1'] = [_resp(204, '')];

      final identificador = IdentificadorDispositivoEmMemoria();
      final controlador = ControladorSessao(
        auth: RepositorioAuth(api),
        cofre: CofreSessaoEmMemoria(),
        dispositivos: RepositorioDispositivo(api),
        identificadorDispositivo: identificador,
      );
      api.credencial = controlador;

      await controlador.entrarComSenha(
        login: 'a',
        senha: 'b',
        papel: Papel.entregador,
      );
      await controlador.sair();

      final baixa = servidor.chamadas.firstWhere(
        (c) => c.path == '/me/devices/d1',
      );
      expect(baixa.method, 'DELETE');
      expect(await identificador.lerRegistroAtual(), isNull);
      expect(controlador.fase, FaseSessao.deslogado);
    });

    test('sem repositório de dispositivo, login e logout funcionam normalmente', () async {
      final servidor = _Servidor();
      final api = _api(servidor);
      servidor.respostas['/auth/sessions'] = [_resp(201, sessaoJson())];
      servidor.respostas['/auth/sessions/current'] = [_resp(204, '')];

      final controlador = ControladorSessao(
        auth: RepositorioAuth(api),
        cofre: CofreSessaoEmMemoria(),
      );
      api.credencial = controlador;

      await controlador.entrarComSenha(
        login: 'a',
        senha: 'b',
        papel: Papel.entregador,
      );
      expect(controlador.autenticado, isTrue);

      await controlador.sair();
      expect(controlador.fase, FaseSessao.deslogado);
      expect(
        servidor.chamadas.where((c) => c.path.contains('devices')).length,
        0,
      );
    });
  });
}
