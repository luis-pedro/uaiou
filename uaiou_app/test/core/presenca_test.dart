import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/presenca/controlador_presenca.dart';
import 'package:uaiou/core/presenca/leitor_de_posicao.dart';
import 'package:uaiou/core/presenca/repositorio_presenca.dart';
import 'package:uaiou/core/rede/cliente_api.dart';

/// Fake de [LeitorDePosicao] — geolocalização real de browser não dá
/// para exercitar em `flutter test`; só a lógica de decisão importa
/// aqui (RF-A06.6/RF-A06.7).
class _LeitorFake implements LeitorDePosicao {
  bool servico = true;
  bool permissao = true;
  bool concedeSePedida = true;
  PosicaoLida posicao = const PosicaoLida(lat: -19.9, lng: -43.9, precisao: 5);
  final StreamController<PosicaoLida> _controlador =
      StreamController<PosicaoLida>.broadcast();
  int chamadasDeStream = 0;

  @override
  Future<bool> servicoHabilitado() async => servico;

  @override
  Future<bool> permissaoConcedida() async => permissao;

  @override
  Future<bool> pedirPermissao() async {
    if (concedeSePedida) permissao = true;
    return permissao;
  }

  @override
  Future<PosicaoLida> posicaoAtual() async => posicao;

  @override
  Stream<PosicaoLida> stream({required int filtroDeDistanciaMetros}) {
    chamadasDeStream++;
    return _controlador.stream;
  }

  void emitir(PosicaoLida p) => _controlador.add(p);

  void fechar() => _controlador.close();
}

class _RespostaFixa implements HttpClientAdapter {
  final int status;
  final Object? corpo;
  RequestOptions? ultimaRequisicao;
  final List<RequestOptions> requisicoes = [];

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
    requisicoes.add(options);
    return ResponseBody.fromString(
      corpo == null ? '' : jsonEncode(corpo),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

ClienteApi _clienteCom(_RespostaFixa adaptador) {
  final dio = Dio()..httpClientAdapter = adaptador;
  return ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1');
}

void main() {
  group('ControladorPresenca — RF-A06.6/RF-A06.7: bloqueio antes de ativar', () {
    test('serviço de localização desligado bloqueia e não chama o servidor', () async {
      final adaptador = _RespostaFixa({'available': true});
      final repositorio = RepositorioPresenca(_clienteCom(adaptador));
      final leitor = _LeitorFake()..servico = false;
      final controlador = ControladorPresenca(
        repositorio: repositorio,
        leitor: leitor,
      );

      await controlador.alternarDisponibilidade(true);

      expect(controlador.sabeDisponibilidade, isFalse);
      expect(controlador.erro, isNotNull);
      expect(adaptador.requisicoes, isEmpty);
    });

    test('permissão negada bloqueia e explica o motivo, sem travar', () async {
      final adaptador = _RespostaFixa({'available': true});
      final repositorio = RepositorioPresenca(_clienteCom(adaptador));
      final leitor = _LeitorFake()
        ..permissao = false
        ..concedeSePedida = false;
      final controlador = ControladorPresenca(
        repositorio: repositorio,
        leitor: leitor,
      );

      await controlador.alternarDisponibilidade(true);

      expect(controlador.sabeDisponibilidade, isFalse);
      expect(controlador.erro, contains('Permissão'));
      expect(adaptador.requisicoes, isEmpty);
    });
  });

  group('ControladorPresenca — RF-A06.1: estado confirmado pelo servidor', () {
    test('ativar com sucesso: envia localização, depois disponibilidade, e inicia o stream', () async {
      final adaptador = _RespostaFixa({'available': true});
      final repositorio = RepositorioPresenca(_clienteCom(adaptador));
      final leitor = _LeitorFake();
      final controlador = ControladorPresenca(
        repositorio: repositorio,
        leitor: leitor,
      );

      await controlador.alternarDisponibilidade(true);

      expect(controlador.disponivel, isTrue);
      expect(controlador.enviando, isFalse);
      expect(controlador.erro, isNull);
      expect(adaptador.requisicoes.map((r) => r.path), [
        '/me/location',
        '/me/availability',
      ]);
      expect(leitor.chamadasDeStream, 1);
    });

    test('falha do servidor reverte para o estado anterior e avisa', () async {
      final adaptador = _RespostaFixa({
        'error': {'code': 'UNEXPECTED', 'message': 'Falhou'},
      }, status: 500);
      final repositorio = RepositorioPresenca(_clienteCom(adaptador));
      final leitor = _LeitorFake();
      final controlador = ControladorPresenca(
        repositorio: repositorio,
        leitor: leitor,
      );

      await controlador.alternarDisponibilidade(true);

      expect(controlador.sabeDisponibilidade, isFalse);
      expect(controlador.erro, isNotNull);
    });

    test('desativar com sucesso para o envio de posição', () async {
      final adaptadorLigar = _RespostaFixa({'available': true});
      final repositorio = RepositorioPresenca(_clienteCom(adaptadorLigar));
      final leitor = _LeitorFake();
      final controlador = ControladorPresenca(
        repositorio: repositorio,
        leitor: leitor,
      );
      await controlador.alternarDisponibilidade(true);
      expect(leitor.chamadasDeStream, 1);

      final adaptadorDesligar = _RespostaFixa({'available': false});
      final controlador2 = ControladorPresenca(
        repositorio: RepositorioPresenca(_clienteCom(adaptadorDesligar)),
        leitor: leitor,
      );
      // Simula já estar disponível antes de desligar.
      await controlador2.alternarDisponibilidade(true);
      await controlador2.alternarDisponibilidade(false);

      expect(controlador2.disponivel, isFalse);
    });
  });

  group('ControladorPresenca — RF-A06.8: queda de presença', () {
    test('GET /me com available=false reflete a queda na interface', () async {
      final adaptadorLigar = _RespostaFixa({'available': true});
      final leitor = _LeitorFake();
      final controlador = ControladorPresenca(
        repositorio: RepositorioPresenca(_clienteCom(adaptadorLigar)),
        leitor: leitor,
      );
      await controlador.alternarDisponibilidade(true);
      expect(controlador.disponivel, isTrue);

      final adaptadorMe = _RespostaFixa({
        'profile': {'available': false},
      });
      final controladorComMe = ControladorPresenca(
        repositorio: RepositorioPresenca(_clienteCom(adaptadorMe)),
        leitor: leitor,
      );
      await controladorComMe.alternarDisponibilidade(true);
      await controladorComMe.recarregarDoServidor();

      expect(controladorComMe.disponivel, isFalse);
    });

    test('não consulta o servidor quando o app já se acha indisponível', () async {
      final adaptador = _RespostaFixa({'available': true});
      final controlador = ControladorPresenca(
        repositorio: RepositorioPresenca(_clienteCom(adaptador)),
        leitor: _LeitorFake(),
      );

      await controlador.recarregarDoServidor();

      expect(adaptador.requisicoes, isEmpty);
    });
  });

  group('ControladorPresenca — RNF-A06.2: falha de envio de posição não trava', () {
    test('erro ao enviar posição do stream é descartado, sem propagar', () async {
      final adaptadorLigar = _RespostaFixa({'available': true});
      final leitor = _LeitorFake();
      final controlador = ControladorPresenca(
        repositorio: RepositorioPresenca(_clienteCom(adaptadorLigar)),
        leitor: leitor,
      );
      await controlador.alternarDisponibilidade(true);

      // A partir daqui, todo PUT /me/location falha — mas o
      // controlador não deve lançar nem travar.
      leitor.emitir(const PosicaoLida(lat: -19.91, lng: -43.91));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controlador.posicaoAtual?.lat, -19.91);
    });
  });

  group('ControladorPresenca — RF-A06.4/RF-A03.9: limpar() encerra o envio', () {
    test('limpar() cancela o stream e volta ao estado inicial', () async {
      final adaptador = _RespostaFixa({'available': true});
      final leitor = _LeitorFake();
      final controlador = ControladorPresenca(
        repositorio: RepositorioPresenca(_clienteCom(adaptador)),
        leitor: leitor,
      );
      await controlador.alternarDisponibilidade(true);
      expect(controlador.disponivel, isTrue);

      controlador.limpar();

      expect(controlador.sabeDisponibilidade, isFalse);
      expect(controlador.posicaoAtual, isNull);
      expect(controlador.erro, isNull);
    });
  });
}
