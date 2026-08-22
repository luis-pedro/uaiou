import '../modelos/dinheiro.dart';

/// Espelha `MerchantStatsResponse.java` (`GET /me/stats`, RF-22.3) —
/// metade do estabelecimento do mesmo `MyStatsController` que
/// [EstatisticasEntregador] já cobre para o entregador (A-09).
///
/// RF-A10.10: `freightSpend` é o único número de dinheiro exibido no
/// card "faturamento" da `tela_atividade_estabelecimento` — nunca uma
/// soma feita no cliente sobre a lista local de pedidos.
class EstatisticasEstabelecimento {
  final DateTime? periodoDe;
  final DateTime? periodoAte;

  final int pedidosPublicados;
  final int pedidosConcluidos;

  /// Frete efetivamente gasto no período — o "faturamento" que a
  /// tela mostra (RF-A10.10).
  final Dinheiro freteGasto;

  final int creditosConsumidos;
  final int? cotaDeCreditos;

  const EstatisticasEstabelecimento({
    this.periodoDe,
    this.periodoAte,
    this.pedidosPublicados = 0,
    this.pedidosConcluidos = 0,
    this.freteGasto = Dinheiro.zero,
    this.creditosConsumidos = 0,
    this.cotaDeCreditos,
  });

  factory EstatisticasEstabelecimento.doJson(Object? json) {
    final mapa = json is Map ? Map<String, dynamic>.from(json) : const <String, dynamic>{};
    final periodo = mapa['period'] is Map
        ? Map<String, dynamic>.from(mapa['period'] as Map)
        : const <String, dynamic>{};

    return EstatisticasEstabelecimento(
      periodoDe: _data(periodo['from']),
      periodoAte: _data(periodo['to']),
      pedidosPublicados: (mapa['ordersPublished'] as num?)?.toInt() ?? 0,
      pedidosConcluidos: (mapa['ordersCompleted'] as num?)?.toInt() ?? 0,
      freteGasto:
          Dinheiro.tentarDeString(mapa['freightSpend']?.toString()) ??
          Dinheiro.zero,
      creditosConsumidos: (mapa['creditsConsumed'] as num?)?.toInt() ?? 0,
      cotaDeCreditos: (mapa['creditsQuota'] as num?)?.toInt(),
    );
  }
}

DateTime? _data(Object? bruto) {
  if (bruto is! String) return null;
  return DateTime.tryParse(bruto)?.toLocal();
}
