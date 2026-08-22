/// `GET /me/score` — `api/gamificacao.md` (RF-A05.4).
///
/// Só leitura: score é materializado por job no servidor, o app não
/// calcula média (RN-04.1 exige transparência dos componentes, não
/// que o cliente refaça a conta).
class ComponenteDeScore {
  final String metrica;
  final String valor;
  final double peso;
  final String? contribuicao;

  const ComponenteDeScore({
    required this.metrica,
    required this.valor,
    required this.peso,
    this.contribuicao,
  });

  factory ComponenteDeScore.doJson(Map<String, dynamic> json) => ComponenteDeScore(
    metrica: json['metric'] as String? ?? '',
    valor: json['value']?.toString() ?? '',
    peso: (json['weight'] as num?)?.toDouble() ?? 0,
    contribuicao: json['contribution']?.toString(),
  );
}

/// Penalidade individual (estabelecimento) — RN-09.4: cada desconto
/// aponta o pedido que o gerou, para não virar arbitrariedade.
class PenalidadeDeScore {
  final String regra;
  final String motivo;
  final int pontos;
  final String? pedidoId;
  final DateTime? aplicadaEm;

  const PenalidadeDeScore({
    required this.regra,
    required this.motivo,
    required this.pontos,
    this.pedidoId,
    this.aplicadaEm,
  });

  factory PenalidadeDeScore.doJson(Map<String, dynamic> json) => PenalidadeDeScore(
    regra: json['rule'] as String? ?? '',
    motivo: json['reason'] as String? ?? '',
    pontos: (json['points'] as num?)?.toInt() ?? 0,
    pedidoId: json['orderId'] as String?,
    aplicadaEm: switch (json['appliedAt']) {
      final String v => DateTime.tryParse(v)?.toLocal(),
      _ => null,
    },
  );
}

class Score {
  final String valor;
  final String janela;
  final DateTime? calculadoEm;
  final List<ComponenteDeScore> componentes;
  final List<PenalidadeDeScore> penalidades;

  const Score({
    required this.valor,
    required this.janela,
    this.calculadoEm,
    this.componentes = const [],
    this.penalidades = const [],
  });

  factory Score.doJson(Map<String, dynamic> json) => Score(
    valor: json['value']?.toString() ?? '',
    janela: json['window'] as String? ?? '',
    calculadoEm: switch (json['calculatedAt']) {
      final String v => DateTime.tryParse(v)?.toLocal(),
      _ => null,
    },
    componentes: json['components'] is List
        ? (json['components'] as List)
              .whereType<Map>()
              .map((c) => ComponenteDeScore.doJson(Map<String, dynamic>.from(c)))
              .toList()
        : const [],
    penalidades: json['penalties'] is List
        ? (json['penalties'] as List)
              .whereType<Map>()
              .map((p) => PenalidadeDeScore.doJson(Map<String, dynamic>.from(p)))
              .toList()
        : const [],
  );
}
