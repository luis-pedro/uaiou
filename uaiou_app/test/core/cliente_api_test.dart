import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/rede/cliente_api.dart';
import 'package:uaiou/core/rede/erros_api.dart';

/// Critério de aceite 4 da A-01: servidor desligado produz
/// [FalhaDeRede], não travamento nem exceção não tratada.
void main() {
  test('servidor fora do ar vira FalhaDeRede, não DioException', () async {
    // Porta 9 (discard) fechada em qualquer máquina: a conexão é
    // recusada de imediato, sem esperar tempo limite.
    final cliente = ClienteApi(baseUrl: 'http://127.0.0.1:9');

    await expectLater(
      cliente.obter('/orders'),
      throwsA(isA<FalhaDeRede>()),
    );
  });

  test('a falha carrega mensagem exibível ao usuário', () async {
    final cliente = ClienteApi(baseUrl: 'http://127.0.0.1:9');

    try {
      await cliente.obter('/orders');
      fail('deveria ter lançado');
    } on ErroApi catch (erro) {
      expect(erro.mensagemParaUsuario, isNotEmpty);
      expect(erro.regra, isNull, reason: 'falha de transporte não tem RN');
    }
  });
}
