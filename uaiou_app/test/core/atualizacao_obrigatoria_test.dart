import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/rede/cliente_api.dart';
import 'package:uaiou/core/rede/erros_api.dart';

/// RF-A13.6 — o backend real não emite 426 hoje (não há endpoint de
/// versão mínima no contrato), mas o cliente precisa tratar esse
/// status de forma defensiva, sem cair no erro genérico.
class _AdaptadorFalso implements HttpClientAdapter {
  _AdaptadorFalso(this.status, this.corpo);

  final int status;
  final String corpo;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      corpo,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test('426 vira AtualizacaoObrigatoria, não ErroInesperado', () async {
    final dio = Dio()
      ..httpClientAdapter = _AdaptadorFalso(
        426,
        '{"error":{"code":"UPGRADE_REQUIRED","message":"Atualize o app."}}',
      );
    final cliente = ClienteApi(dio: dio, baseUrl: 'http://teste');

    await expectLater(
      cliente.obter('/orders'),
      throwsA(isA<AtualizacaoObrigatoria>()),
    );
  });

  test('426 aciona o callback de exigir atualização', () async {
    final dio = Dio()
      ..httpClientAdapter = _AdaptadorFalso(
        426,
        '{"error":{"code":"UPGRADE_REQUIRED","message":"Atualize o app."}}',
      );
    var acionado = false;
    final cliente = ClienteApi(
      dio: dio,
      baseUrl: 'http://teste',
      aoExigirAtualizacao: () => acionado = true,
    );

    await expectLater(cliente.obter('/orders'), throwsA(isA<ErroApi>()));
    expect(acionado, isTrue);
  });

  test('erro sem envelope reconhecido continua ErroInesperado', () async {
    final dio = Dio()..httpClientAdapter = _AdaptadorFalso(500, '{}');
    final cliente = ClienteApi(dio: dio, baseUrl: 'http://teste');

    await expectLater(cliente.obter('/orders'), throwsA(isA<ErroInesperado>()));
  });
}
