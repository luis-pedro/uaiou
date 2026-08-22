import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/estado/carregavel.dart';
import 'package:uaiou/core/perfil/controlador_perfil.dart';
import 'package:uaiou/core/perfil/perfil.dart';
import 'package:uaiou/core/perfil/repositorio_perfil.dart';
import 'package:uaiou/core/rede/cliente_api.dart';
import 'package:uaiou/core/sessao/identidade.dart';

Map<String, dynamic> _meCourier({List<String>? pendingFields}) => {
  'id': 'u-1',
  'role': 'COURIER',
  'status': 'active',
  'displayName': 'João Silva',
  'email': 'joao@teste.com',
  'telefone': '31999999999',
  'profile': {
    'cpf': '12345678901',
    'vehicleType': 'MOTORCYCLE',
    'available': true,
    'completedDeliveries': 4,
    'score': '87.50',
    'location': {
      'lat': -19.9182,
      'lng': -43.9386,
      'updatedAt': '2026-07-22T14:02:11Z',
    },
  },
  'pendingFields': ?pendingFields,
  '_links': {
    'self': {'href': '/api/v1/me'},
  },
};

Map<String, dynamic> _meMerchant({double? lat, double? lng}) => {
  'id': 'u-2',
  'role': 'MERCHANT',
  'status': 'active',
  'displayName': 'Bar do Zé',
  'email': 'bar@teste.com',
  'telefone': null,
  'profile': {
    'cnpj': '11222333000181',
    'businessName': 'Bar do Zé',
    'score': '72.00',
    'address': {
      'bairro': 'Centro',
      'rua': 'Rua A',
      'numero': '10',
      'cidade': 'Santa Rita',
      'cep': '39100000',
      'lat': lat,
      'lng': lng,
    },
  },
};

class _RespostaFixa implements HttpClientAdapter {
  final int status;
  final Object corpo;
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

void main() {
  group('Perfil.doJson — espelha o DTO real do backend', () {
    test('entregador: sem cidade nem fotoUrl (o DTO não tem esses campos)', () {
      final perfil = Perfil.doJson(_meCourier());

      expect(perfil.papel, Papel.entregador);
      expect(perfil.status, StatusConta.ativo);
      expect(perfil.nomeExibicao, 'João Silva');
      expect(perfil.telefone, '31999999999');
      expect(perfil.detalhes?.cpf, '12345678901');
      expect(perfil.detalhes?.tipoDeVeiculo, 'MOTORCYCLE');
      expect(perfil.detalhes?.entregasConcluidas, 4);
      expect(perfil.detalhes?.localizacao?.lat, -19.9182);
      expect(perfil.detalhes?.endereco, isNull);
    });

    test('estabelecimento: endereço vem em profile.address', () {
      final perfil = Perfil.doJson(_meMerchant());

      expect(perfil.papel, Papel.estabelecimento);
      expect(perfil.detalhes?.cnpj, '11222333000181');
      expect(perfil.detalhes?.nomeDoNegocio, 'Bar do Zé');
      expect(perfil.detalhes?.endereco?.cidade, 'Santa Rita');
    });

    test('pendingFields nulo em GET, lista em PATCH', () {
      expect(Perfil.doJson(_meCourier()).camposPendentes, isNull);
      expect(
        Perfil.doJson(_meCourier(pendingFields: const [])).camposPendentes,
        isEmpty,
      );
      expect(
        Perfil.doJson(_meCourier(pendingFields: const ['cpf'])).camposPendentes,
        ['cpf'],
      );
    });
  });

  group('diffDeEdicao — RF-A05.2: só o que mudou vai no PATCH', () {
    test('editar só o nome envia apenas o nome', () {
      final original = Perfil.doJson(_meCourier());

      final edicao = diffDeEdicao(
        original: original,
        nomeExibicao: 'João S. Entregas',
        telefone: original.telefone!,
      );

      expect(edicao, isNotNull);
      final json = edicao!.paraJson();
      expect(json['displayName'], 'João S. Entregas');
      expect(json.containsKey('telefone'), isFalse);
      expect(json.containsKey('profile'), isFalse);
    });

    test('nada mudou devolve null — a tela não manda PATCH vazio', () {
      final original = Perfil.doJson(_meCourier());

      final edicao = diffDeEdicao(
        original: original,
        nomeExibicao: original.nomeExibicao,
        telefone: original.telefone!,
      );

      expect(edicao, isNull);
    });

    test('endereço do estabelecimento vai inteiro quando qualquer campo muda', () {
      final original = Perfil.doJson(_meMerchant());

      final edicao = diffDeEdicao(
        original: original,
        nomeExibicao: original.nomeExibicao,
        telefone: '',
        bairro: 'Centro',
        rua: 'Rua A',
        numero: '10',
        cidade: 'Nova Cidade',
        cep: '39100000',
      );

      expect(edicao, isNotNull);
      final perfil = edicao!.paraJson()['profile'] as Map;
      expect(perfil['cidade'], 'Nova Cidade');
    });

    test('coordenada marcada no mapa vai como par no PATCH', () {
      final original = Perfil.doJson(_meMerchant());

      final edicao = diffDeEdicao(
        original: original,
        nomeExibicao: original.nomeExibicao,
        telefone: '',
        lat: -19.9182,
        lng: -43.9386,
      );

      expect(edicao, isNotNull);
      final perfil = edicao!.paraJson()['profile'] as Map;
      expect(perfil['lat'], -19.9182);
      expect(perfil['lng'], -43.9386);
    });

    test('coordenada igual à salva não entra no PATCH', () {
      final original = Perfil.doJson(_meMerchant(lat: -19.9182, lng: -43.9386));

      final endereco = original.detalhes!.endereco!;
      final edicao = diffDeEdicao(
        original: original,
        nomeExibicao: original.nomeExibicao,
        telefone: '',
        bairro: endereco.bairro,
        rua: endereco.rua,
        numero: endereco.numero,
        cidade: endereco.cidade,
        cep: endereco.cep,
        lat: -19.9182,
        lng: -43.9386,
      );

      expect(edicao, isNull);
    });
  });

  group('RepositorioPerfil — GET/PATCH /me', () {
    test('obter() decodifica a resposta do contrato', () async {
      final adaptador = _RespostaFixa(_meCourier());
      final dio = Dio()..httpClientAdapter = adaptador;
      final api = ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1');

      final perfil = await RepositorioPerfil(api).obter();

      expect(adaptador.ultimaRequisicao?.method, 'GET');
      expect(adaptador.ultimaRequisicao?.path, '/me');
      expect(perfil.nomeExibicao, 'João Silva');
    });

    test('editar() manda PATCH com o corpo do diff', () async {
      final adaptador = _RespostaFixa(_meCourier(pendingFields: const []));
      final dio = Dio()..httpClientAdapter = adaptador;
      final api = ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1');

      await RepositorioPerfil(
        api,
      ).editar(const EdicaoDePerfil(nomeExibicao: 'Novo Nome'));

      expect(adaptador.ultimaRequisicao?.method, 'PATCH');
      expect(adaptador.ultimaRequisicao?.data, {'displayName': 'Novo Nome'});
    });
  });

  group('ControladorPerfil — Carregavel<Perfil>', () {
    test('carregar() vai de Carregando para Pronto', () async {
      final adaptador = _RespostaFixa(_meCourier());
      final dio = Dio()..httpClientAdapter = adaptador;
      final api = ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1');
      final controlador = ControladorPerfil(repositorio: RepositorioPerfil(api));

      expect(controlador.estado, isA<Carregando<Perfil>>());

      await controlador.carregar();

      expect(controlador.estado, isA<Pronto<Perfil>>());
      expect(controlador.estado.valorOuNulo?.nomeExibicao, 'João Silva');
    });

    test('erro do servidor vira Falhou', () async {
      final adaptador = _RespostaFixa({
        'error': {'code': 'UNEXPECTED', 'message': 'Falhou'},
      }, status: 500);
      final dio = Dio()..httpClientAdapter = adaptador;
      final api = ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1');
      final controlador = ControladorPerfil(repositorio: RepositorioPerfil(api));

      await controlador.carregar();

      expect(controlador.estado, isA<Falhou<Perfil>>());
    });

    test('limpar() volta para Carregando — RF-A03.9', () async {
      final adaptador = _RespostaFixa(_meCourier());
      final dio = Dio()..httpClientAdapter = adaptador;
      final api = ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1');
      final controlador = ControladorPerfil(repositorio: RepositorioPerfil(api));

      await controlador.carregar();
      controlador.limpar();

      expect(controlador.estado, isA<Carregando<Perfil>>());
    });
  });
}
