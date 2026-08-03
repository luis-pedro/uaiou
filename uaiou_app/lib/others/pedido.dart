enum StatusPedido {
  pendente,
  aceito,
  entregue,
  cancelado,
}

class Pedido {
  final int numeroPedido;
  final String bairro;
  final String rua;
  final String numero;

  /// Valor do pedido, usado para calcular o faturamento na Tela de Atividades
  final double valor;

  /// Data em que o pedido foi realizado, usada para filtrar o
  /// faturamento "de hoje" e para agrupar os pedidos por data.
  final DateTime data;

  StatusPedido status;

  Pedido({
    required this.numeroPedido,
    required this.bairro,
    required this.rua,
    required this.numero,
    required this.status,
    this.valor = 0,
    DateTime? data,
  }) : data = data ?? DateTime.now();
}