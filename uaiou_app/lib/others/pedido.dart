/// ===============================================================
/// MODELO DOS PEDIDOS
/// ===============================================================
///
/// Compartilhado entre a Tela Principal, a Tela de Pedidos e a Tela
/// de Atividades do Estabelecimento, e também pela Tela de Entregas
/// do Entregador (exibem a lista e os totais).

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

  /// Nome do estabelecimento que fez o pedido.
  /// Usado na Tela de Entregas do entregador.
  final String nomeEstabelecimento;

  /// Tempo estimado (em minutos) para a entrega.
  /// Nulo enquanto não houver estimativa (ex: pedido ainda pendente).
  final int? tempoEstimadoMinutos;

  /// Valor do pedido, usado para calcular o faturamento na
  /// Tela de Atividades.
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
    this.nomeEstabelecimento = "",
    this.tempoEstimadoMinutos,
    this.valor = 0,
    DateTime? data,
  }) : data = data ?? DateTime.now();
}