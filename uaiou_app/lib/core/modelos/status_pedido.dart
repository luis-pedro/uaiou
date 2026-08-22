/// ===============================================================
/// STATUS DO PEDIDO — RF-A01.8
/// ===============================================================
///
/// O app e a API falam vocabulários diferentes: a interface foi
/// desenhada com `pendente/aceito/entregue/cancelado`, e o contrato
/// usa `published/accepted/finalized/...`.
///
/// A tradução acontece **num único ponto** — [StatusPedido.doContrato]
/// —, na desserialização. Nenhuma comparação de string de status
/// existe fora daqui.
///
/// > Corrigido em A-03: a A-01 cobria só 4 dos 7 estados do contrato.
/// > `created`, `in_negotiation` e `contestable_finalized` caíam em
/// > [desconhecido], o que apagaria da tela um pedido em negociação.
enum StatusPedido {
  /// Criado, ainda dentro da transação de criação. Efêmero — na
  /// prática o cliente vê direto [pendente].
  criado('created'),

  /// Publicado e aguardando entregador (`published`).
  pendente('published'),

  /// Há contraoferta em aberto aguardando decisão do estabelecimento.
  emNegociacao('in_negotiation'),

  /// Atribuído a um entregador (`accepted`).
  aceito('accepted'),

  /// Entrega finalizada com código (`finalized`).
  entregue('finalized'),

  /// Finalizada pela via contestável (T-17): vale como entregue, mas
  /// ainda dentro da janela de contestação.
  entregueContestavel('contestable_finalized'),

  cancelado('cancelled'),

  /// Estado que este build do app não conhece.
  ///
  /// Existe para que um servidor mais novo que o app **não derrube a
  /// tela**. A interface mostra o pedido em estado neutro, sem
  /// oferecer ação.
  desconhecido('');

  const StatusPedido(this.noContrato);

  final String noContrato;

  static StatusPedido doContrato(Object? bruto) {
    if (bruto is! String) return desconhecido;
    final valor = bruto.trim().toLowerCase();
    for (final status in values) {
      if (status.noContrato.isNotEmpty && status.noContrato == valor) {
        return status;
      }
    }
    return desconhecido;
  }

  /// Valor a enviar em `GET /orders?status=`.
  /// [desconhecido] não é enviável.
  String? get paraContrato => noContrato.isEmpty ? null : noContrato;

  String get rotulo => switch (this) {
    criado || pendente => 'Pendente',
    emNegociacao => 'Em negociação',
    aceito => 'Aceito',
    entregue => 'Entregue',
    entregueContestavel => 'Entregue',
    cancelado => 'Cancelado',
    desconhecido => '—',
  };

  /// Já saiu do fluxo ativo — alimenta as seções "concluídas" das
  /// telas de entregas e atividades.
  bool get encerrado =>
      this == entregue || this == entregueContestavel || this == cancelado;

  /// Ainda aguardando entregador.
  bool get aguardandoEntregador =>
      this == criado || this == pendente || this == emNegociacao;

  /// Conta como entrega concluída (para totais e histórico).
  bool get concluido => this == entregue || this == entregueContestavel;
}
