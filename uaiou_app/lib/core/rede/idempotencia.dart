import 'dart:math';

/// ===============================================================
/// CHAVE DE IDEMPOTÊNCIA — RF-A07.3
/// ===============================================================
///
/// `POST /orders/{id}/assignment` exige `Idempotency-Key`: uma chave
/// repetida devolve a mesma `assignment` em vez de 409, o que protege
/// um retry de rede de parecer uma corrida perdida (api/pedidos.md).
///
/// O projeto não depende do pacote `uuid` (não está no `pubspec.yaml`
/// — conferido antes de escrever isto). Em vez de somar a dependência
/// para um único uso, a chave junta o instante em microssegundos com
/// um sufixo aleatório: o bastante para não colidir entre toques do
/// mesmo aparelho, que é a única garantia que este uso precisa.
/// Teto do sufixo aleatório.
///
/// **Não usar `1 << 32` aqui.** Em Dart compilado para JavaScript o
/// deslocamento é de 32 bits, então `1 << 32` vale `0` no navegador
/// (na VM nativa vale 4294967296). `Random().nextInt(0)` lança
/// `RangeError`, e como o erro escapava antes de qualquer requisição,
/// publicar pedido e aceitar corrida falhavam **só no Flutter Web** —
/// invisivelmente, porque a suíte de testes roda na VM.
///
/// 2^30 cabe nos 32 bits com folga em ambas as plataformas e, somado
/// ao instante em microssegundos, sobra para o que esta chave precisa.
const int _tetoDoSufixo = 1 << 30;

String gerarChaveIdempotencia(String prefixo) {
  final agora = DateTime.now().microsecondsSinceEpoch;
  final aleatorio = Random().nextInt(_tetoDoSufixo);
  return '$prefixo-$agora-$aleatorio';
}
