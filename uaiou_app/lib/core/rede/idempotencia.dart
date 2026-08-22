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
String gerarChaveIdempotencia(String prefixo) {
  final agora = DateTime.now().microsecondsSinceEpoch;
  final aleatorio = Random().nextInt(1 << 32);
  return '$prefixo-$agora-$aleatorio';
}
