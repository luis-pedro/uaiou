/// ===============================================================
/// ROTEIRO DO ENTREGADOR — vários pedidos de uma vez
/// ===============================================================
///
/// Espelha o corpo de `GET /couriers/me/route`: **um trajeto só** que
/// passa por todas as lojas ainda não visitadas e todos os destinos
/// dos pedidos em andamento, na ordem sugerida pelo servidor.
///
/// O traçado reaproveita [Trajeto] — mesma geometria, mesmos passos —
/// para que mapa e cartão de manobra sirvam às duas rotas sem cópia.
library;

import 'modelo_rota.dart';

enum TipoParada { coleta, entrega }

class ParadaDoRoteiro {
  final String pedidoId;
  final TipoParada tipo;
  final PontoGeo? local;

  /// Onde a parada acontece dentro de [Trajeto.geometria]; nulo sem
  /// traçado ou quando o provedor não separou as pernas.
  final int? indiceNoTracado;

  const ParadaDoRoteiro({
    required this.pedidoId,
    required this.tipo,
    this.local,
    this.indiceNoTracado,
  });

  static ParadaDoRoteiro? doJson(Object? json) {
    if (json is! Map) return null;
    final id = json['orderId'] as String?;
    final tipo = switch (json['kind']) {
      'PICKUP' => TipoParada.coleta,
      'DROPOFF' => TipoParada.entrega,
      _ => null,
    };
    if (id == null || tipo == null) return null;
    return ParadaDoRoteiro(
      pedidoId: id,
      tipo: tipo,
      local: PontoGeo.doJson(json['location']),
      indiceNoTracado: (json['pointIndex'] as num?)?.toInt(),
    );
  }
}

class RoteiroDoEntregador {
  final Trajeto trajeto;

  /// `true` quando a ordem saiu dos tempos por via; `false` quando o
  /// servidor caiu na ordem de aceite (provedor sem matriz ou pedidos
  /// demais). A tela diz qual foi — o entregador pode discordar dela.
  final bool otimizado;

  final List<ParadaDoRoteiro> paradas;
  final String? atribuicao;

  const RoteiroDoEntregador({
    this.trajeto = const Trajeto(),
    this.otimizado = false,
    this.paradas = const [],
    this.atribuicao,
  });

  /// O corpo traz os campos do trajeto na raiz, não aninhados como em
  /// `/orders/{id}/route` — por isso o [Trajeto] é montado à mão.
  factory RoteiroDoEntregador.doJson(Map<String, dynamic> json) {
    final base = Trajeto.doJson(json);
    return RoteiroDoEntregador(
      trajeto: Trajeto(
        disponivel: base.disponivel,
        motivoIndisponivel: base.motivoIndisponivel,
        distanciaPorViaKm: base.distanciaPorViaKm,
        duracaoMinutos: base.duracaoMinutos,
        geometria: base.geometria,
        passos: base.passos,
      ),
      otimizado: json['optimized'] == true,
      paradas:
          (json['stops'] as List?)
              ?.map(ParadaDoRoteiro.doJson)
              .whereType<ParadaDoRoteiro>()
              .toList(growable: false) ??
          const [],
      atribuicao: json['attribution'] as String?,
    );
  }

  bool get temTracado => trajeto.temTracado;

  /// Sem pedido em andamento não há o que mostrar — diferente de "sem
  /// traçado", em que as paradas continuam valendo.
  bool get semPedidos => trajeto.motivoIndisponivel == 'NO_ACTIVE_ORDERS';

  /// A próxima parada, dada a posição atual: a primeira cujo ponto no
  /// traçado ainda está à frente. Sem posição ou sem índices, a
  /// primeira da lista.
  ParadaDoRoteiro? proximaParadaDe(PontoGeo? posicao) {
    if (paradas.isEmpty) return null;
    if (posicao == null || !temTracado) return paradas.first;
    final atual = trajeto.indiceMaisProximoDe(posicao);
    for (final parada in paradas) {
      final indice = parada.indiceNoTracado;
      if (indice == null) return paradas.first;
      if (indice >= atual) return parada;
    }
    return paradas.last;
  }

  /// Para reaproveitar o widget de mapa, que recebe uma rota de pedido.
  RotaDoPedido comoRotaDoPedido() =>
      RotaDoPedido(orderId: '', trajeto: trajeto, atribuicao: atribuicao);
}
