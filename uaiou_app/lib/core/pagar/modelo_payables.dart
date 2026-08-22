import '../modelos/dinheiro.dart';
import '../ganhos/modelo_ganhos.dart';

/// ===============================================================
/// A PAGAR — A-10 / T-18 (`GET /me/payables`, `PayablesResponse.java`)
/// ===============================================================
///
/// Espelho do lado do estabelecimento de `RespostaGanhos` (A-09):
/// quanto se deve, agrupado por entregador. **Só leitura** — RF-A10.9
/// é explícito que a confirmação do acerto é do entregador; o
/// estabelecimento vê, não confirma. Por isso não existe aqui um
/// equivalente a `confirmarSelecionados`.
///
/// Reaproveita [StatusLancamento] de `core/ganhos`: é o mesmo
/// `LedgerStatus` do contrato, só que visto do outro lado do
/// lançamento.
class LancamentoAPagar {
  final String id;
  final String orderId;
  final String orderNumber;
  final Dinheiro amount;
  final StatusLancamento status;
  final DateTime? createdAt;

  const LancamentoAPagar({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.amount,
    required this.status,
    this.createdAt,
  });

  factory LancamentoAPagar.doJson(Map<String, dynamic> json) => LancamentoAPagar(
    id: json['id'] as String? ?? '',
    orderId: json['orderId'] as String? ?? '',
    orderNumber: json['orderNumber'] as String? ?? '',
    amount: Dinheiro.tentarDeString(json['amount']?.toString()) ?? Dinheiro.zero,
    status: StatusLancamento.doJson(json['status']),
    createdAt: switch (json['createdAt']) {
      final String v => DateTime.tryParse(v)?.toLocal(),
      _ => null,
    },
  );
}

/// `PayablesResponse.ByCourier` — um entregador e o que se deve a ele.
class APagarPorEntregador {
  final String courierId;
  final String courierName;
  final Dinheiro total;
  final List<LancamentoAPagar> lancamentos;

  const APagarPorEntregador({
    required this.courierId,
    required this.courierName,
    required this.total,
    required this.lancamentos,
  });

  factory APagarPorEntregador.doJson(Map<String, dynamic> json) {
    final entradas = json['entries'];
    return APagarPorEntregador(
      courierId: json['courierId'] as String? ?? '',
      courierName: json['courierName'] as String? ?? 'Entregador',
      total: Dinheiro.tentarDeString(json['total']?.toString()) ?? Dinheiro.zero,
      lancamentos: entradas is List
          ? entradas
                .whereType<Map>()
                .map((e) => LancamentoAPagar.doJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
    );
  }
}

/// Corpo completo de `GET /me/payables`. Sem paginação no contrato —
/// o servidor devolve tudo de uma vez (`PayablesResponse.java`).
class Payables {
  final Dinheiro total;
  final List<APagarPorEntregador> porEntregador;

  const Payables({required this.total, required this.porEntregador});

  static const Payables vazio = Payables(total: Dinheiro.zero, porEntregador: []);

  factory Payables.doJson(Object? json) {
    final mapa = json is Map ? Map<String, dynamic>.from(json) : const <String, dynamic>{};
    final porEntregador = mapa['byCourier'];
    return Payables(
      total: Dinheiro.tentarDeString(mapa['total']?.toString()) ?? Dinheiro.zero,
      porEntregador: porEntregador is List
          ? porEntregador
                .whereType<Map>()
                .map((e) => APagarPorEntregador.doJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
    );
  }
}
