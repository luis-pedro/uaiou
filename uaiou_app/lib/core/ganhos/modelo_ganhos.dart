import '../modelos/dinheiro.dart';
import '../modelos/pagina.dart';

/// ===============================================================
/// GANHOS E ACERTO — A-09 / T-18 (livro-razão do entregador)
/// ===============================================================
///
/// Espelha `GET /me/earnings` (`EarningsResponse.java`). **O app não
/// soma lançamentos para chegar a um total** — `summary` já vem
/// pronto do servidor (RF-A09.1), e a soma exibida na tela é só para
/// conferência visual (RNF-A09.2), nunca para substituir o valor do
/// servidor.
///
/// Nomenclatura do protótipo que a v1 aposenta (RF-A09.2): não existe
/// "saldo disponível" nem "resgatar" — só "a receber" (ainda não
/// acertado por fora) e "recebido" (acerto confirmado pelo próprio
/// entregador).
enum StatusLancamento {
  aReceber,
  recebido;

  /// `LedgerStatus` do contrato serializa em minúsculo via `@JsonValue`
  /// (`receivable`/`settled`) — nunca o nome do enum Java.
  static StatusLancamento doJson(Object? valor) => switch (valor) {
    'settled' => StatusLancamento.recebido,
    _ => StatusLancamento.aReceber,
  };
}

/// `summary` de `EarningsResponse` — o agregado do período que o
/// servidor calculou. Nunca recalculado no cliente (RF-A09.1).
class ResumoGanhos {
  final Dinheiro total;
  final Dinheiro receivable;
  final Dinheiro settled;

  const ResumoGanhos({
    required this.total,
    required this.receivable,
    required this.settled,
  });

  static const ResumoGanhos zero = ResumoGanhos(
    total: Dinheiro.zero,
    receivable: Dinheiro.zero,
    settled: Dinheiro.zero,
  );

  factory ResumoGanhos.doJson(Object? json) {
    if (json is! Map) return zero;
    return ResumoGanhos(
      total: Dinheiro.tentarDeString(json['total'] as String?) ?? Dinheiro.zero,
      receivable:
          Dinheiro.tentarDeString(json['receivable'] as String?) ?? Dinheiro.zero,
      settled: Dinheiro.tentarDeString(json['settled'] as String?) ?? Dinheiro.zero,
    );
  }
}

/// Um lançamento do livro-razão (`EarningsResponse.Entry`) — uma
/// entrega finalizada que gerou frete a receber ou já acertado.
class Lancamento {
  final String id;
  final String orderId;
  final String orderNumber;
  final Dinheiro amount;
  final StatusLancamento status;
  final DateTime? createdAt;

  /// Só existe depois da confirmação de acerto — RF-A09.5.
  final DateTime? settledAt;

  const Lancamento({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.amount,
    required this.status,
    this.createdAt,
    this.settledAt,
  });

  bool get aReceber => status == StatusLancamento.aReceber;

  factory Lancamento.doJson(Map<String, dynamic> json) => Lancamento(
    id: json['id'] as String? ?? '',
    orderId: json['orderId'] as String? ?? '',
    orderNumber: json['orderNumber'] as String? ?? '',
    amount: Dinheiro.tentarDeString(json['amount'] as String?) ?? Dinheiro.zero,
    status: StatusLancamento.doJson(json['status']),
    createdAt: _dataLocal(json['createdAt']),
    settledAt: _dataLocal(json['settledAt']),
  );
}

DateTime? _dataLocal(Object? bruto) {
  if (bruto is! String) return null;
  return DateTime.tryParse(bruto)?.toLocal();
}

/// Corpo completo de `GET /me/earnings`: resumo do período + extrato
/// paginado por `_links` (RF-A09.6).
class RespostaGanhos {
  final ResumoGanhos resumo;
  final Pagina<Lancamento> pagina;

  const RespostaGanhos({required this.resumo, required this.pagina});

  static RespostaGanhos vazia = RespostaGanhos(
    resumo: ResumoGanhos.zero,
    pagina: Pagina<Lancamento>.vazia(),
  );

  factory RespostaGanhos.doJson(Object? json) {
    final mapa = json is Map ? Map<String, dynamic>.from(json) : const <String, dynamic>{};
    return RespostaGanhos(
      resumo: ResumoGanhos.doJson(mapa['summary']),
      pagina: Pagina<Lancamento>.doJson(mapa, Lancamento.doJson),
    );
  }
}
