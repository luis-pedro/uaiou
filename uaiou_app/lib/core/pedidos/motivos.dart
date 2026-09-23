/// ===============================================================
/// MOTIVOS DE CANCELAMENTO E DESISTÊNCIA — A-15 / T-26
/// ===============================================================
///
/// Listas fechadas do contrato (RF-26.16/RF-26.25). O código viaja
/// para a API; o rótulo é só da interface. "Outro" exige observação —
/// o servidor recusa sem ela (`NOTE_REQUIRED`), e a tela não oferece
/// o envio vazio.
library;

enum MotivoCancelamento {
  clienteDesistiu('customer_gave_up', 'Cliente desistiu'),
  pagamentoRecusado('payment_declined', 'Pagamento recusado'),
  semEstoque('out_of_stock', 'Produto em falta'),
  erroNoPedido('order_error', 'Erro no pedido'),
  atrasoDoEntregador('courier_delay', 'Entregador atrasado'),
  outro('other', 'Outro');

  const MotivoCancelamento(this.codigo, this.rotulo);

  final String codigo;
  final String rotulo;

  bool get exigeObservacao => this == outro;
}

enum MotivoDesistencia {
  problemaNoVeiculo('vehicle_problem', 'Problema no veículo'),
  acidente('accident', 'Acidente'),
  pedidoErrado('wrong_order', 'Pedido errado'),
  demoraNaRetirada('pickup_delay', 'Estabelecimento demorando'),
  pessoal('personal', 'Motivo pessoal'),
  // Modo feira (docs/feira/): num salão não há veículo, acidente nem loja
  // atrasando. São os motivos de quem pegou um prêmio e desistiu de levá-lo.
  semTempo('no_time', 'Não tenho tempo agora'),
  naoAcheiOPonto('cant_find_spot', 'Não achei o ponto de entrega'),
  filaNoEstande('stand_queue', 'Fila grande no estande'),
  pegueiErrado('wrong_pick', 'Peguei o pedido errado'),
  outro('other', 'Outro');

  const MotivoDesistencia(this.codigo, this.rotulo);

  final String codigo;
  final String rotulo;

  /// O que a tela oferece no modo feira, na ordem do mais comum.
  static const List<MotivoDesistencia> paraFeira = [
    semTempo,
    naoAcheiOPonto,
    filaNoEstande,
    pegueiErrado,
    outro,
  ];

  bool get exigeObservacao => this == outro;
}
