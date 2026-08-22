import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/cadastro/controlador_cadastro.dart';
import 'package:uaiou/core/cadastro/rascunho_cadastro.dart';
import 'package:uaiou/core/rede/cliente_api.dart';
import 'package:uaiou/core/sessao/cofre_sessao.dart';
import 'package:uaiou/core/sessao/controlador_sessao.dart';
import 'package:uaiou/core/sessao/identidade.dart';
import 'package:uaiou/core/sessao/repositorio_auth.dart';

class _Contador implements HttpClientAdapter {
  int chamadas = 0;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<List<int>>? s,
    Future<void>? c,
  ) async {
    chamadas++;
    await Future.delayed(const Duration(milliseconds: 30));
    if (o.path.contains('registrations')) {
      return ResponseBody.fromString(
        '{"id":"u-1","role":"COURIER","status":"pending"}',
        201,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      '{"accessToken":"a","refreshToken":"r","expiresIn":900,"user":{"id":"u-1","role":"COURIER","status":"pending"}}',
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test(
    'duas chamadas simultâneas a concluir() disparam UM só cadastro',
    () async {
      final contador = _Contador();
      final dio = Dio()..httpClientAdapter = contador;
      final api = ClienteApi(dio: dio, baseUrl: 'http://teste/api/v1');
      final sessao = ControladorSessao(
        auth: RepositorioAuth(api),
        cofre: CofreSessaoEmMemoria(),
      );
      final cadastro = ControladorCadastro(
        cadastro: RepositorioCadastro(api),
        sessao: sessao,
      );
      final rascunho = RascunhoCadastro()
        ..papel = Papel.entregador
        ..nome = 'Teste'
        ..email = 'teste@teste.com'
        ..cpf = '390.533.447-05'
        ..login = 'teste.dup'
        ..senha = 'SenhaForte123'
        ..confirmacaoDeSenha = 'SenhaForte123';

      // simula o duplo toque: duas chamadas antes da primeira terminar
      final r1 = cadastro.concluir(rascunho);
      final r2 = cadastro.concluir(rascunho);

      final resultados = await Future.wait([r1, r2]);

      // a segunda chamada deve ter sido barrada pela guarda ANTES de
      // qualquer requisição de rede.
      expect(
        resultados.where((r) => r == true).length,
        1,
        reason: 'só uma das duas deve ter concluído',
      );
    },
  );
}
