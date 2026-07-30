/// ===============================================================
/// MODELO DOS PEDIDOS
/// ===============================================================
///
/// Compartilhado entre a Tela Principal (cria o pedido) e a Tela de
/// Pedidos do Estabelecimento (exibe a lista).

enum StatusPedido {
  pendente,
  aceito,
  finalizado,
  cancelado,
}

class Pedido {
  final int numeroPedido;
  final String bairro;
  final String rua;
  final String numero;
  StatusPedido status;

  Pedido({
    required this.numeroPedido,
    required this.bairro,
    required this.rua,
    required this.numero,
    required this.status,
  });
}