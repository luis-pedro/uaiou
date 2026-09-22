/// ===============================================================
/// MODELOS DO MODO FEIRA — `docs/feira/`
/// ===============================================================
///
/// Versão de demonstração de estande: o pedido tem localização e um
/// prêmio em **texto** (um Bis), não um frete. Várias pessoas pegam o
/// mesmo pedido, uma vez cada, e não existe rota — tudo acontece
/// dentro de um salão.
library;

/// Pedido-prêmio como o jogador o vê.
class PedidoFeira {
  final String id;

  /// Apelido do ponto ("mesa do café"); pode não existir.
  final String? rotulo;

  final double lat;
  final double longitude;

  /// Texto livre escrito pelo operador: é o prêmio, não um valor.
  final String recompensa;

  /// Quantos prêmios ainda existem neste ponto.
  final int restantes;

  final bool encerrado;

  /// Se **este** jogador já pegou. Vem do servidor pronto: cruzar
  /// listas no app daria a resposta errada enquanto a vitrine não
  /// tivesse recarregado.
  final bool capturado;

  const PedidoFeira({
    required this.id,
    required this.rotulo,
    required this.lat,
    required this.longitude,
    required this.recompensa,
    required this.restantes,
    required this.encerrado,
    required this.capturado,
  });

  bool get capturavel => !capturado && !encerrado && restantes > 0;

  static double _numero(Object? valor) => switch (valor) {
    final num v => v.toDouble(),
    final String v => double.tryParse(v) ?? 0,
    _ => 0,
  };

  factory PedidoFeira.doJson(Map<String, dynamic> json) => PedidoFeira(
    id: json['id'] as String? ?? '',
    rotulo: json['rotulo'] as String?,
    lat: _numero(json['lat']),
    longitude: _numero(json['longitude']),
    recompensa: json['recompensa'] as String? ?? '',
    restantes: (json['restantes'] as num?)?.toInt() ?? 0,
    encerrado: json['encerrado'] as bool? ?? false,
    capturado: json['capturado'] as bool? ?? false,
  );
}

/// O comprovante: é esta tela que o visitante mostra no balcão.
class CapturaFeira {
  final String id;
  final String pedidoId;
  final String recompensa;
  final DateTime? capturadoEm;
  final DateTime? entregueEm;

  const CapturaFeira({
    required this.id,
    required this.pedidoId,
    required this.recompensa,
    required this.capturadoEm,
    required this.entregueEm,
  });

  bool get entregue => entregueEm != null;

  static DateTime? _data(Object? valor) =>
      valor is String ? DateTime.tryParse(valor) : null;

  factory CapturaFeira.doJson(Map<String, dynamic> json) => CapturaFeira(
    id: json['id'] as String? ?? '',
    pedidoId: json['pedidoId'] as String? ?? '',
    recompensa: json['recompensa'] as String? ?? '',
    capturadoEm: _data(json['capturadoEm']),
    entregueEm: _data(json['entregueEm']),
  );
}
