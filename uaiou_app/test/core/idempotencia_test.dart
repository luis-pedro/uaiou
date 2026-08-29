import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/rede/idempotencia.dart';

void main() {
  // Regressão: com `1 << 32` o teto virava 0 em JavaScript e
  // `Random().nextInt(0)` lançava RangeError — quebrando publicar
  // pedido e aceitar corrida apenas no Flutter Web.
  test('gerar chave não estoura e varia entre chamadas', () {
    final chaves = {for (var i = 0; i < 500; i++) gerarChaveIdempotencia('p')};
    expect(chaves.length, greaterThan(400));
    for (final chave in chaves) {
      expect(chave, startsWith('p-'));
      final sufixo = int.parse(chave.split('-').last);
      expect(sufixo, inInclusiveRange(0, (1 << 30) - 1));
    }
  });
}
