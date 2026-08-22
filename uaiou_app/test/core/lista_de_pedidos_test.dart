import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/estado/carregavel.dart';
import 'package:uaiou/core/pedidos/lista_de_pedidos.dart';
import 'package:uaiou/core/pedidos/repositorio_pedidos.dart';
import 'package:uaiou/core/rede/cliente_api.dart';
import 'package:uaiou/others/pedido.dart';

class _Servidor {
  final List<RequestOptions> chamadas = [];
  final Map<String, List<Response<dynamic>>> respostas = {};

  Dio montar() => Dio()..httpClientAdapter = _Adaptador(this);
}

class _Adaptador implements HttpClientAdapter {
  _Adaptador(this.servidor);
  final _Servidor servidor;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions opcoes,
    Stream<List<int>>? corpo,
    Future<void>? cancelamento,
  ) async {
    servidor.chamadas.add(opcoes);
    // `seguir` chega com a query embutida no caminho
    // (`/orders?page=2`); as respostas são registradas pelo recurso.
    final fila = servidor.respostas[opcoes.path.split('?').first];
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

String _pedido(String id, {String status = 'published'}) =>
    '{"id":"$id","number":"$id","status":"$status","proposedFee":"6.00",'
    '"createdAt":"2026-08-09T12:00:00Z",'
    '"destination":{"district":"Centro"},"_links":{}}';

void main() {
  late _Servidor servidor;
  late ListaDePedidos lista;

  void montar({StatusPedido? recorte}) {
    servidor = _Servidor();
    lista = ListaDePedidos(
      RepositorioPedidos(
        ClienteApi(dio: servidor.montar(), baseUrl: 'http://teste/api/v1'),
      ),
      recorte: recorte,
    );
  }

  group('os quatro caminhos — RF-A03.3', () {
    test('nasce carregando', () {
      montar();
      expect(lista.estado, isA<Carregando<List<Pedido>>>());
    });

    test('lista com itens vira Pronto', () async {
      montar();
      servidor.respostas['/orders'] = [
        _resp(200,
            '{"data":[${_pedido("a")},${_pedido("b")}],"meta":{"page":1,"perPage":20,"total":2}}')
      ];

      await lista.carregar();

      expect(lista.estado, isA<Pronto<List<Pedido>>>());
      expect(lista.itens.length, 2);
    });

    test('lista sem itens vira Vazio, não Pronto com lista vazia', () async {
      montar();
      servidor.respostas['/orders'] = [
        _resp(200, '{"data":[],"meta":{"page":1,"perPage":20,"total":0}}')
      ];

      await lista.carregar();

      expect(lista.estado, isA<Vazio<List<Pedido>>>());
    });

    test('falha vira Falhou com o erro tipado', () async {
      montar();
      servidor.respostas['/orders'] = [
        _resp(403,
            '{"error":{"code":"COURIER_ONLY","message":"Rota restrita a entregadores."}}')
      ];

      await lista.carregar();

      final estado = lista.estado;
      expect(estado, isA<Falhou<List<Pedido>>>());
      expect(
        (estado as Falhou<List<Pedido>>).erro.mensagem,
        'Rota restrita a entregadores.',
      );
    });

    test('vazio por posição obsoleta explica o motivo (RF-11.8)', () async {
      montar();
      servidor.respostas['/orders'] = [
        _resp(200,
            '{"data":[],"meta":{"page":1,"perPage":20,"total":0},"warning":"LOCATION_STALE"}')
      ];

      await lista.carregar();

      final estado = lista.estado;
      expect(estado, isA<Vazio<List<Pedido>>>());
      expect(
        (estado as Vazio<List<Pedido>>).motivo,
        contains('localização'),
        reason: 'vazio por posição velha não é "não há pedidos"',
      );
    });
  });

  group('recorte e paginação', () {
    test('o recorte vai como query para o servidor', () async {
      montar(recorte: StatusPedido.aceito);
      servidor.respostas['/orders'] = [
        _resp(200, '{"data":[],"meta":{"page":1,"perPage":20,"total":0}}')
      ];

      await lista.carregar();

      expect(servidor.chamadas.single.queryParameters['status'], 'accepted');
    });

    test('sem recorte, nenhum status é enviado', () async {
      montar();
      servidor.respostas['/orders'] = [
        _resp(200, '{"data":[],"meta":{"page":1,"perPage":20,"total":0}}')
      ];

      await lista.carregar();

      expect(
        servidor.chamadas.single.queryParameters.containsKey('status'),
        isFalse,
      );
    });

    test('carregarMais segue o _links.next do servidor — RF-A03.7', () async {
      montar();
      servidor.respostas['/orders'] = [
        _resp(200,
            '{"data":[${_pedido("a")}],"meta":{"page":1,"perPage":1,"total":2},'
            '"_links":{"next":{"href":"/api/v1/orders?page=2"}}}'),
        _resp(200,
            '{"data":[${_pedido("b")}],"meta":{"page":2,"perPage":1,"total":2},"_links":{}}'),
      ];

      await lista.carregar();
      expect(lista.temMais, isTrue);

      await lista.carregarMais();

      expect(lista.itens.map((p) => p.id).toList(), ['a', 'b']);
      expect(lista.temMais, isFalse);
    });

    test('falha ao paginar preserva o que já está na tela', () async {
      montar();
      servidor.respostas['/orders'] = [
        _resp(200,
            '{"data":[${_pedido("a")}],"meta":{"page":1,"perPage":1,"total":2},'
            '"_links":{"next":{"href":"/api/v1/orders?page=2"}}}'),
        _resp(500, '{}'),
      ];

      await lista.carregar();
      await lista.carregarMais();

      expect(lista.itens.length, 1, reason: 'a página 1 continua visível');
      expect(lista.estado, isA<Pronto<List<Pedido>>>());
    });
  });

  group('recarga — RF-A03.6', () {
    test('recarregar mantém o conteúdo durante a busca', () async {
      montar();
      servidor.respostas['/orders'] = [
        _resp(200,
            '{"data":[${_pedido("a")}],"meta":{"page":1,"perPage":20,"total":1}}')
      ];
      await lista.carregar();

      final futuro = lista.recarregar();
      // Em recarga a lista NÃO volta para "carregando": trocar o
      // estado aqui faria a tela piscar a cada gesto de puxar.
      expect(lista.estado, isA<Pronto<List<Pedido>>>());
      await futuro;
    });
  });

  group('limpar — RF-A03.9', () {
    test('descarta itens e paginação', () async {
      montar();
      servidor.respostas['/orders'] = [
        _resp(200,
            '{"data":[${_pedido("a")}],"meta":{"page":1,"perPage":1,"total":2},'
            '"_links":{"next":{"href":"/api/v1/orders?page=2"}}}')
      ];
      await lista.carregar();
      expect(lista.itens, isNotEmpty);

      lista.limpar();

      expect(lista.itens, isEmpty);
      expect(lista.temMais, isFalse);
      expect(lista.estado, isA<Carregando<List<Pedido>>>());
    });
  });
}
