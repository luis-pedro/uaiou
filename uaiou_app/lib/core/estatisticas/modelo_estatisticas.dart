/// ===============================================================
/// ESTATÍSTICAS DO ENTREGADOR — RF-A09.7
/// ===============================================================
///
/// Espelha `CourierStatsResponse.java` (`GET /me/stats`). Os campos de
/// dinheiro do contrato (`earningsReceivable`/`earningsSettled`/
/// `averageTicket`) **não são exibidos por esta tela** — RF-A09.7 é
/// explícito que dinheiro vem só de `GET /me/earnings`, para não
/// existirem duas origens para o mesmo valor. O modelo ainda os
/// desserializa (o corpo do contrato os traz), só não os expõe na UI.
class EstatisticasEntregador {
  final DateTime? periodoDe;
  final DateTime? periodoAte;

  final int entregasConcluidas;

  /// 0.0–1.0, ou nulo quando o servidor não tem insumo — o app não
  /// inventa taxa (mesmo padrão de `avaliacao` nula em A-12).
  final double? taxaSucessoContraoferta;

  /// Em minutos.
  final double? tempoMedioDeEntregaMin;

  /// 0.0–1.0 — proporção de finalizações "limpas" (sem contingência).
  final double? taxaFinalizacaoLimpa;

  /// `null` — T-10 só guarda o estado atual de disponibilidade, não um
  /// log histórico por período (documentado no próprio DTO do
  /// backend). Não é ausência de dado por falha, é ausência de fonte.
  final double? horasDisponiveis;
  final double? utilizacao;

  const EstatisticasEntregador({
    this.periodoDe,
    this.periodoAte,
    this.entregasConcluidas = 0,
    this.taxaSucessoContraoferta,
    this.tempoMedioDeEntregaMin,
    this.taxaFinalizacaoLimpa,
    this.horasDisponiveis,
    this.utilizacao,
  });

  factory EstatisticasEntregador.doJson(Object? json) {
    final mapa = json is Map ? Map<String, dynamic>.from(json) : const <String, dynamic>{};
    final periodo = mapa['period'] is Map ? Map<String, dynamic>.from(mapa['period'] as Map) : const <String, dynamic>{};

    return EstatisticasEntregador(
      periodoDe: _data(periodo['from']),
      periodoAte: _data(periodo['to']),
      entregasConcluidas: (mapa['deliveriesCompleted'] as num?)?.toInt() ?? 0,
      taxaSucessoContraoferta: (mapa['counterofferSuccessRate'] as num?)?.toDouble(),
      tempoMedioDeEntregaMin: (mapa['averageDeliveryMinutes'] as num?)?.toDouble(),
      taxaFinalizacaoLimpa: (mapa['cleanFinalizationRate'] as num?)?.toDouble(),
      horasDisponiveis: (mapa['availableHours'] as num?)?.toDouble(),
      utilizacao: (mapa['utilization'] as num?)?.toDouble(),
    );
  }
}

DateTime? _data(Object? bruto) {
  if (bruto is! String) return null;
  return DateTime.tryParse(bruto)?.toLocal();
}
