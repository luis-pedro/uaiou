import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/modelos/pagina.dart';
import 'package:uaiou/core/rede/erros_api.dart';
import 'package:uaiou/others/pedido.dart';

/// Critérios de aceite 3 e 7 da A-01: o envelope de erro chega
/// tipado com `message` e `rule`; status desconhecido não quebra.
void main() {
  group('StatusPedido — tradução de vocabulário (RF-A01.8)', () {
    test('traduz os estados do contrato', () {
      expect(StatusPedido.doContrato('published'), StatusPedido.pendente);
      expect(StatusPedido.doContrato('accepted'), StatusPedido.aceito);
      expect(StatusPedido.doContrato('finalized'), StatusPedido.entregue);
      expect(StatusPedido.doContrato('cancelled'), StatusPedido.cancelado);
    });

    test('estado desconhecido não lança', () {
      expect(StatusPedido.doContrato('quantum_superposition'),
          StatusPedido.desconhecido);
      expect(StatusPedido.doContrato(null), StatusPedido.desconhecido);
      expect(StatusPedido.doContrato(42), StatusPedido.desconhecido);
    });

    test('volta ao vocabulário do contrato', () {
      expect(StatusPedido.pendente.paraContrato, 'published');
      expect(StatusPedido.desconhecido.paraContrato, isNull);
    });
  });

  group('erroDoContrato (RF-A01.5)', () {
    Map<String, dynamic> envelope({
      String codigo = 'INSUFFICIENT_CREDITS',
      String mensagem = 'Créditos insuficientes para publicar o pedido.',
      String? regra = 'RN-05.1',
    }) =>
        {
          'error': {
            'code': codigo,
            'message': mensagem,
            'rule': regra,
            'details': {'required': 1, 'available': 0},
          }
        };

    test('422 vira RegraDeNegocio com message e rule', () {
      final erro = erroDoContrato(422, envelope());

      expect(erro, isA<RegraDeNegocio>());
      expect(erro.codigo, 'INSUFFICIENT_CREDITS');
      expect(erro.mensagem, 'Créditos insuficientes para publicar o pedido.');
      expect(erro.regra, 'RN-05.1');
      expect(erro.detalhes['available'], 0);
    });

    test('cada status vira o seu tipo', () {
      expect(erroDoContrato(400, envelope()), isA<RequisicaoInvalida>());
      expect(erroDoContrato(401, envelope()), isA<NaoAutenticado>());
      expect(erroDoContrato(403, envelope()), isA<SemPermissao>());
      expect(erroDoContrato(404, envelope()), isA<NaoEncontrado>());
      expect(erroDoContrato(409, envelope()), isA<Conflito>());
      expect(erroDoContrato(500, envelope()), isA<ErroInesperado>());
    });

    test('classifica pelo status mesmo sem corpo válido', () {
      final erro = erroDoContrato(409, 'isto não é json do contrato');

      expect(erro, isA<Conflito>());
      expect(erro.mensagem, isNotEmpty);
      expect(erro.regra, isNull);
    });

    test('corpo nulo não derruba a classificação', () {
      expect(erroDoContrato(403, null), isA<SemPermissao>());
    });
  });

  group('Pagina (RF-A01.9)', () {
    test('lê data, meta e _links', () {
      final pagina = Pagina<String>.doJson({
        'data': [
          {'nome': 'a'},
          {'nome': 'b'},
        ],
        'meta': {'page': 1, 'perPage': 20, 'total': 137},
        '_links': {
          'self': {'href': '/api/v1/orders?page=1'},
          'next': {'href': '/api/v1/orders?page=2'},
        },
      }, (item) => item['nome'] as String);

      expect(pagina.itens, ['a', 'b']);
      expect(pagina.meta.total, 137);
      expect(pagina.temProxima, isTrue);
      expect(pagina.proximaHref, '/api/v1/orders?page=2');
    });

    test('última página não tem next', () {
      final pagina = Pagina<String>.doJson({
        'data': <dynamic>[],
        'meta': {'page': 7, 'perPage': 20, 'total': 137},
        '_links': {
          'self': {'href': '/api/v1/orders?page=7'},
        },
      }, (item) => item['nome'] as String);

      expect(pagina.estaVazia, isTrue);
      expect(pagina.temProxima, isFalse);
    });

    test('item malformado é descartado sem derrubar a lista', () {
      final pagina = Pagina<String>.doJson({
        'data': [
          {'nome': 'a'},
          {'semNome': true},
          {'nome': 'c'},
        ],
        'meta': {'page': 1, 'perPage': 20, 'total': 3},
      }, (item) => item['nome'] as String);

      expect(pagina.itens, ['a', 'c']);
    });
  });

  group('Pedido.doJson (RF-A01.7 e RF-A01.10)', () {
    // Formato real de `OrderSummary` (api/pedidos.md). A A-01 tinha
    // adivinhado `merchantName`/`deliveryAddress`/`displayNumber`, que
    // não existem — os corretos são `merchant`/`destination`/`number`.
    Map<String, dynamic> json() => {
          'id': '3f2504e0-4f89-11d3-9a0c-0305e82c3301',
          'status': 'published',
          'proposedFee': '6.00',
          'createdAt': '2026-08-09T12:00:00Z',
          'distanceKm': 2.4,
          'merchant': {'id': 'm-1', 'name': 'Bar do Zé'},
          'destination': {
            'district': 'Centro',
            'street': 'Rua das Flores',
            'number': '120',
          },
          '_links': {
            'assignment': {'href': '/api/v1/orders/3f25/assignment'},
          },
        };

    test('usa o UUID do servidor como id', () {
      final pedido = Pedido.doJson(json());
      expect(pedido.id, '3f2504e0-4f89-11d3-9a0c-0305e82c3301');
    });

    test('valor vira Dinheiro, não double', () {
      expect(Pedido.doJson(json()).valor.paraJson(), '6.00');
    });

    test('rotuloCurto encurta o UUID quando não há número do servidor', () {
      final pedido = Pedido.doJson(json());
      expect(pedido.rotuloCurto, '2C3301');
      expect(pedido.rotuloCurto.length, 6);
    });

    test('rotuloCurto prefere o número que o servidor mandou', () {
      final pedido = Pedido.doJson({...json(), 'number': '6246'});
      expect(pedido.rotuloCurto, '6246');
    });

    test('lê estabelecimento, distância e endereço do contrato', () {
      final pedido = Pedido.doJson(json());
      expect(pedido.nomeEstabelecimento, 'Bar do Zé');
      expect(pedido.distanciaKm, 2.4);
      expect(pedido.enderecoResumido, 'Rua das Flores, 120 — Centro');
    });

    test('vitrine com só o bairro não quebra o endereço (RF-11.6)', () {
      final pedido = Pedido.doJson({
        ...json(),
        'destination': {'district': 'Centro'},
      });
      expect(pedido.temEnderecoCompleto, isFalse);
      expect(pedido.enderecoResumido, 'Centro');
    });

    test('cobre os estados que a A-01 tinha deixado de fora', () {
      for (final caso in {
        'created': StatusPedido.criado,
        'in_negotiation': StatusPedido.emNegociacao,
        'contestable_finalized': StatusPedido.entregueContestavel,
      }.entries) {
        expect(
          Pedido.doJson({...json(), 'status': caso.key}).status,
          caso.value,
          reason: caso.key,
        );
      }
    });

    test('freteFinal, quando existe, é o valor que vale', () {
      final pedido =
          Pedido.doJson({...json(), 'finalFee': '8.50'});
      expect(pedido.valor.paraJson(), '8.50');
    });

    test('preserva os _links das transições permitidas', () {
      final pedido = Pedido.doJson(json());
      expect(pedido.links.permite('assignment'), isTrue);
      expect(pedido.links.permite('completion'), isFalse);
    });

    test('data do contrato vira fuso local', () {
      expect(Pedido.doJson(json()).criadoEm.isUtc, isFalse);
    });

    test('status desconhecido não derruba a desserialização', () {
      final pedido = Pedido.doJson({...json(), 'status': 'teleported'});
      expect(pedido.status, StatusPedido.desconhecido);
    });
  });
}
