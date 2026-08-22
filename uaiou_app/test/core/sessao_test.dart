import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/rede/cliente_api.dart';
import 'package:uaiou/core/rede/erros_api.dart';
import 'package:uaiou/core/sessao/cofre_sessao.dart';
import 'package:uaiou/core/sessao/controlador_sessao.dart';
import 'package:uaiou/core/sessao/identidade.dart';
import 'package:uaiou/core/sessao/repositorio_auth.dart';
import 'package:uaiou/core/sessao/sessao.dart';

/// Servidor falso: responde no formato do contrato sem rede.
class _ApiFalsa {
  final List<RequestOptions> chamadas = [];

  /// Respostas por caminho, na ordem em que devem ser devolvidas.
  /// Com uma só na fila, ela é reutilizada indefinidamente.
  final Map<String, List<Response<dynamic>>> respostas = {};

  Dio montar() {
    final dio = Dio();
    dio.httpClientAdapter = _AdaptadorFalso(this);
    return dio;
  }
}

class _AdaptadorFalso implements HttpClientAdapter {
  _AdaptadorFalso(this.api);

  final _ApiFalsa api;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    api.chamadas.add(options);

    final fila = api.respostas[options.path];
    if (fila == null || fila.isEmpty) {
      return ResponseBody.fromString('{}', 404);
    }

    final resposta = fila.length == 1 ? fila.first : fila.removeAt(0);
    return ResponseBody.fromString(
      resposta.data as String,
      resposta.statusCode!,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Response<dynamic> _resp(int status, String corpo) =>
    Response<dynamic>(requestOptions: RequestOptions(), statusCode: status, data: corpo);

String _sessaoJson({
  String access = 'access-1',
  String refresh = 'refresh-1',
  int expiraEm = 900,
  String papel = 'COURIER',
  String status = 'active',
}) =>
    '{"accessToken":"$access","refreshToken":"$refresh","expiresIn":$expiraEm,'
    '"user":{"id":"u-1","role":"$papel","status":"$status",'
    '"displayName":"Fulano"}}';

void main() {
  group('Identidade — vocabulário do contrato', () {
    test('papel traduz nos dois sentidos', () {
      expect(Papel.doContrato('COURIER'), Papel.entregador);
      expect(Papel.doContrato('MERCHANT'), Papel.estabelecimento);
      expect(Papel.entregador.noContrato, 'COURIER');
      expect(Papel.doContrato('WIZARD'), Papel.desconhecido);
    });

    test('status traduz e sabe quem pode operar', () {
      expect(StatusConta.doContrato('active').podeOperar, isTrue);
      expect(StatusConta.doContrato('pending').podeOperar, isFalse);
      expect(StatusConta.doContrato('suspended').podeOperar, isFalse);
      expect(StatusConta.doContrato('rejected').podeOperar, isFalse);
      expect(StatusConta.doContrato(null), StatusConta.desconhecido);
    });

    test('rota inicial existe só para os papéis do app', () {
      expect(Papel.entregador.rotaInicial, '/principal_entregador');
      expect(Papel.estabelecimento.rotaInicial, '/principal_estabelecimento');
      expect(Papel.admin.rotaInicial, isNull);
    });
  });

  group('Sessao', () {
    test('expiresIn em segundos vira instante de expiração', () {
      final sessao = Sessao.doJson({
        'accessToken': 'a',
        'refreshToken': 'r',
        'expiresIn': 900,
        'user': {'id': 'u', 'role': 'COURIER', 'status': 'active'},
      });

      expect(sessao.valido, isTrue);
      expect(sessao.expiraEm.isAfter(DateTime.now()), isTrue);
    });

    test('token vencido é reconhecido como expirado', () {
      final sessao = Sessao.doJson({
        'accessToken': 'a',
        'refreshToken': 'r',
        'expiresIn': 0,
        'user': {'id': 'u', 'role': 'COURIER', 'status': 'active'},
      });

      expect(sessao.expirado, isTrue);
      expect(sessao.valido, isFalse);
    });

    test('sobrevive a ida e volta pelo cofre', () {
      final original = Sessao.doJson({
        'accessToken': 'a',
        'refreshToken': 'r',
        'expiresIn': 900,
        'user': {
          'id': 'u-1',
          'role': 'MERCHANT',
          'status': 'active',
          'displayName': 'Bar do Zé',
        },
      });

      final voltou = Sessao.deJsonTexto(original.paraJsonTexto())!;

      expect(voltou.accessToken, 'a');
      expect(voltou.refreshToken, 'r');
      expect(voltou.usuario.papel, Papel.estabelecimento);
      expect(voltou.usuario.nomeExibicao, 'Bar do Zé');
    });

    test('conteúdo corrompido vira ausência de sessão', () {
      expect(Sessao.deJsonTexto('{{{'), isNull);
      expect(Sessao.deJsonTexto(''), isNull);
      expect(Sessao.deJsonTexto(null), isNull);
    });
  });

  group('ControladorSessao', () {
    late _ApiFalsa falsa;
    late ClienteApi api;
    late CofreSessaoEmMemoria cofre;
    late ControladorSessao controlador;

    void montar({Sessao? guardada}) {
      falsa = _ApiFalsa();
      api = ClienteApi(dio: falsa.montar(), baseUrl: 'http://teste/api/v1');
      cofre = CofreSessaoEmMemoria(guardada);
      controlador = ControladorSessao(
        auth: RepositorioAuth(api),
        cofre: cofre,
      );
      api.credencial = controlador;
    }

    test('login por senha envia grantType e role, e guarda a sessão', () async {
      montar();
      falsa.respostas['/auth/sessions'] = [_resp(201, _sessaoJson())];

      await controlador.entrarComSenha(
        login: 'ze@teste.com',
        senha: 'segredo',
        papel: Papel.entregador,
      );

      final enviado = falsa.chamadas.single.data as Map;
      expect(enviado['grantType'], 'password');
      expect(enviado['role'], 'COURIER');
      expect(enviado['login'], 'ze@teste.com');

      expect(controlador.autenticado, isTrue);
      expect(controlador.papel, Papel.entregador);
      expect(controlador.podeOperar, isTrue);
      expect(await cofre.ler(), isNotNull, reason: 'sessão precisa persistir');
    });

    test('a navegação segue o papel do servidor, não o toggle', () async {
      montar();
      // O usuário escolheu "entregador"; o servidor diz MERCHANT.
      falsa.respostas['/auth/sessions'] = [
        _resp(201, _sessaoJson(papel: 'MERCHANT'))
      ];

      await controlador.entrarComSenha(
        login: 'a',
        senha: 'b',
        papel: Papel.entregador,
      );

      expect(controlador.papel, Papel.estabelecimento);
    });

    test('credencial inválida não autentica e expõe a mensagem', () async {
      montar();
      falsa.respostas['/auth/sessions'] = [
        _resp(401,
            '{"error":{"code":"INVALID_CREDENTIALS","message":"Login ou senha incorretos."}}')
      ];

      await expectLater(
        controlador.entrarComSenha(
          login: 'a',
          senha: 'errada',
          papel: Papel.entregador,
        ),
        throwsA(
          isA<NaoAutenticado>().having(
            (e) => e.mensagem,
            'mensagem',
            'Login ou senha incorretos.',
          ),
        ),
      );

      expect(controlador.autenticado, isFalse);
    });

    test('papel errado devolve a regra de negócio do servidor', () async {
      montar();
      falsa.respostas['/auth/sessions'] = [
        _resp(422,
            '{"error":{"code":"ROLE_MISMATCH","message":"Esta conta não é do tipo informado.","rule":"RF-03.5"}}')
      ];

      await expectLater(
        controlador.entrarComSenha(
          login: 'a',
          senha: 'b',
          papel: Papel.estabelecimento,
        ),
        throwsA(isA<RegraDeNegocio>()
            .having((e) => e.regra, 'regra', 'RF-03.5')),
      );
    });

    test('conta pendente autentica mas não pode operar', () async {
      montar();
      falsa.respostas['/auth/sessions'] = [
        _resp(201, _sessaoJson(status: 'pending'))
      ];

      await controlador.entrarComSenha(
        login: 'a',
        senha: 'b',
        papel: Papel.entregador,
      );

      expect(controlador.autenticado, isTrue);
      expect(controlador.podeOperar, isFalse,
          reason: 'RF-A02.9 — pendente não alcança telas de operação');
    });

    test('restaura sessão guardada sem passar pelo login', () async {
      final guardada = Sessao.doJson({
        'accessToken': 'a',
        'refreshToken': 'r',
        'expiresIn': 900,
        'user': {'id': 'u', 'role': 'COURIER', 'status': 'active'},
      });
      montar(guardada: guardada);

      await controlador.restaurar();

      expect(controlador.fase, FaseSessao.autenticado);
      expect(falsa.chamadas, isEmpty, reason: 'token válido não renova');
    });

    test('sem nada guardado, abre deslogado', () async {
      montar();
      await controlador.restaurar();
      expect(controlador.fase, FaseSessao.deslogado);
    });

    test('sessão guardada e expirada é renovada na abertura', () async {
      final vencida = Sessao.doJson({
        'accessToken': 'velho',
        'refreshToken': 'refresh-velho',
        'expiresIn': 0,
        'user': {'id': 'u', 'role': 'COURIER', 'status': 'active'},
      });
      montar(guardada: vencida);
      falsa.respostas['/auth/sessions'] = [
        _resp(201, _sessaoJson(access: 'novo', refresh: 'refresh-novo'))
      ];

      await controlador.restaurar();

      expect(controlador.fase, FaseSessao.autenticado);
      expect(await controlador.tokenAtual(), 'novo');

      final enviado = falsa.chamadas.single.data as Map;
      expect(enviado['grantType'], 'refresh');
      expect(enviado['refreshToken'], 'refresh-velho');
    });

    test('refresh recusado desloga e limpa o cofre', () async {
      final vencida = Sessao.doJson({
        'accessToken': 'velho',
        'refreshToken': 'r',
        'expiresIn': 0,
        'user': {'id': 'u', 'role': 'COURIER', 'status': 'active'},
      });
      montar(guardada: vencida);
      falsa.respostas['/auth/sessions'] = [
        _resp(401, '{"error":{"code":"INVALID_REFRESH_TOKEN","message":"x"}}')
      ];

      await controlador.restaurar();

      expect(controlador.fase, FaseSessao.deslogado);
      expect(await cofre.ler(), isNull);
    });

    /// Critério de aceite 6 — o mais importante desta task.
    ///
    /// O servidor rotaciona o refresh e trata reuso como vazamento,
    /// revogando a família inteira. Se cada requisição concorrente
    /// renovasse por conta, o usuário seria deslogado de todo lugar.
    test('três requisições com token expirado produzem UMA renovação',
        () async {
      montar();
      falsa.respostas['/auth/sessions'] = [
        _resp(201, _sessaoJson(access: 'novo', refresh: 'refresh-novo'))
      ];
      falsa.respostas['/orders'] = [
        _resp(401, '{"error":{"code":"EXPIRED","message":"expirado"}}'),
        _resp(401, '{"error":{"code":"EXPIRED","message":"expirado"}}'),
        _resp(401, '{"error":{"code":"EXPIRED","message":"expirado"}}'),
        _resp(200, '{"data":[],"meta":{"page":1,"perPage":20,"total":0}}'),
        _resp(200, '{"data":[],"meta":{"page":1,"perPage":20,"total":0}}'),
        _resp(200, '{"data":[],"meta":{"page":1,"perPage":20,"total":0}}'),
      ];

      await controlador.entrarComSenha(
        login: 'a',
        senha: 'b',
        papel: Papel.entregador,
      );

      await Future.wait([
        api.obter('/orders'),
        api.obter('/orders'),
        api.obter('/orders'),
      ]);

      final renovacoes = falsa.chamadas
          .where((c) => c.path == '/auth/sessions')
          .where((c) => (c.data as Map)['grantType'] == 'refresh')
          .length;

      expect(renovacoes, 1);
      expect(await controlador.tokenAtual(), 'novo');
    });

    test('o token vai no header de toda requisição', () async {
      montar();
      falsa.respostas['/auth/sessions'] = [_resp(201, _sessaoJson())];
      falsa.respostas['/orders'] = [
        _resp(200, '{"data":[],"meta":{"page":1,"perPage":20,"total":0}}')
      ];

      await controlador.entrarComSenha(
        login: 'a',
        senha: 'b',
        papel: Papel.entregador,
      );
      await api.obter('/orders');

      final pedido = falsa.chamadas.last;
      expect(pedido.headers['Authorization'], 'Bearer access-1');
    });

    test('logout avisa o servidor e limpa tudo', () async {
      montar();
      falsa.respostas['/auth/sessions'] = [_resp(201, _sessaoJson())];
      falsa.respostas['/auth/sessions/current'] = [_resp(204, '')];

      await controlador.entrarComSenha(
        login: 'a',
        senha: 'b',
        papel: Papel.entregador,
      );
      await controlador.sair();

      expect(controlador.fase, FaseSessao.deslogado);
      expect(controlador.usuario, isNull);
      expect(await cofre.ler(), isNull);
      expect(await controlador.tokenAtual(), isNull);

      final saida = falsa.chamadas.last;
      expect(saida.path, '/auth/sessions/current');
      expect((saida.data as Map)['refreshToken'], 'refresh-1');
    });

    test('logout limpa a sessão local mesmo se o servidor falhar', () async {
      montar();
      falsa.respostas['/auth/sessions'] = [_resp(201, _sessaoJson())];
      falsa.respostas['/auth/sessions/current'] = [_resp(500, '{}')];

      await controlador.entrarComSenha(
        login: 'a',
        senha: 'b',
        papel: Papel.entregador,
      );
      await controlador.sair();

      expect(controlador.fase, FaseSessao.deslogado);
      expect(await cofre.ler(), isNull);
    });

    test('recuperação de senha chama a rota do contrato', () async {
      montar();
      falsa.respostas['/auth/password-resets'] = [_resp(202, '{}')];

      await controlador.pedirRecuperacaoDeSenha('ze@teste.com');

      final pedido = falsa.chamadas.single;
      expect(pedido.path, '/auth/password-resets');
      expect((pedido.data as Map)['email'], 'ze@teste.com');
    });
  });
}
