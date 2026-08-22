/// ===============================================================
/// ROTA DO PEDIDO — A-14
/// ===============================================================
///
/// Espelha o corpo de `GET /orders/{id}/route` (T-25, `api/pedidos.md`).
///
/// **Uma rota só**, do ponto do entregador até o destino, passando pelo
/// estabelecimento — decisão do dono de 2026-08-16, que substituiu as
/// duas pernas independentes do desenho anterior.
///
/// Modelo em Dart puro, sem `latlong2`: quem converte [PontoGeo] em
/// `LatLng` é o widget de mapa. O núcleo não precisa saber qual pacote
/// de mapa a tela usa hoje.
library;

import 'dart:math' as math;

/// Um ponto do traçado. Nome próprio em vez de `LatLng` para deixar
/// claro que é dado vindo do servidor, não posição do aparelho.
class PontoGeo {
  final double lat;
  final double lng;

  const PontoGeo(this.lat, this.lng);

  static PontoGeo? doJson(Object? json) {
    if (json is! Map) return null;
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return PontoGeo(lat, lng);
  }

  /// Distância em metros até [outro] — Haversine, a mesma conta do
  /// servidor (`Distances.haversineKm`). Usada só para descobrir em que
  /// ponto do traçado o entregador está; nada de regra de negócio
  /// depende dela no cliente.
  double metrosAte(PontoGeo outro) {
    const raioDaTerraKm = 6371.0088;
    double rad(double g) => g * math.pi / 180;

    final dLat = rad(outro.lat - lat);
    final dLng = rad(outro.lng - lng);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat)) *
            math.cos(rad(outro.lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * raioDaTerraKm * math.asin(math.min(1, math.sqrt(a))) * 1000;
  }
}

/// Uma instrução de curva, em português, vinda do provedor.
///
/// [indiceNoTracado] é a posição da manobra dentro da geometria — é o
/// que permite saber qual passo vem a seguir sem recalcular rota: acha
/// o ponto do traçado mais próximo do entregador e compara índices.
class PassoDaRota {
  final String instrucao;
  final int distanciaMetros;
  final int indiceNoTracado;

  const PassoDaRota({
    required this.instrucao,
    required this.distanciaMetros,
    required this.indiceNoTracado,
  });

  factory PassoDaRota.doJson(Object? json) {
    if (json is! Map) {
      return const PassoDaRota(instrucao: '', distanciaMetros: 0, indiceNoTracado: 0);
    }
    return PassoDaRota(
      instrucao: json['instruction'] as String? ?? '',
      distanciaMetros: (json['distanceMeters'] as num?)?.toInt() ?? 0,
      indiceNoTracado: (json['pointIndex'] as num?)?.toInt() ?? 0,
    );
  }
}

/// O trajeto em si.
///
/// **Indisponível não é erro** (RF-A14.6): o servidor diz o motivo
/// (`COURIER_LOCATION_UNKNOWN`, `ROUTING_UNAVAILABLE`) e a tela segue
/// funcionando sem o traçado.
class Trajeto {
  final bool disponivel;
  final String? motivoIndisponivel;

  /// `false` quando o estabelecimento não tem coordenada (RF-25.5): a
  /// rota existe, mas vai direto ao destino. Dizer isso é o que impede
  /// a tela de afirmar uma passagem pela loja que o trajeto não tem.
  final bool passaPelaRetirada;

  /// Distância **por via** — nunca confundida com a linha reta da
  /// vitrine (RF-A14.5): nomes diferentes já no modelo.
  final double? distanciaPorViaKm;
  final int? duracaoMinutos;
  final List<PontoGeo> geometria;
  final List<PassoDaRota> passos;

  const Trajeto({
    this.disponivel = false,
    this.motivoIndisponivel,
    this.passaPelaRetirada = false,
    this.distanciaPorViaKm,
    this.duracaoMinutos,
    this.geometria = const [],
    this.passos = const [],
  });

  factory Trajeto.doJson(Object? json) {
    if (json is! Map) return const Trajeto();
    return Trajeto(
      disponivel: json['available'] == true,
      motivoIndisponivel: json['unavailableReason'] as String?,
      passaPelaRetirada: json['includesPickup'] == true,
      distanciaPorViaKm: (json['roadDistanceKm'] as num?)?.toDouble(),
      duracaoMinutos: (json['durationMinutes'] as num?)?.toInt(),
      geometria:
          (json['geometry'] as List?)
              ?.map(PontoGeo.doJson)
              .whereType<PontoGeo>()
              .toList(growable: false) ??
          const [],
      passos:
          (json['steps'] as List?)
              ?.map(PassoDaRota.doJson)
              .where((p) => p.instrucao.isNotEmpty)
              .toList(growable: false) ??
          const [],
    );
  }

  bool get temTracado => disponivel && geometria.length >= 2;

  /// Explicação curta para a tela — o entregador não lê código de erro.
  /// Sempre uma constatação, nunca um alarme: nada aqui o impede de
  /// entregar (RF-A14.6).
  String get explicacao => switch (motivoIndisponivel) {
    'COURIER_LOCATION_UNKNOWN' =>
      'Sem a sua posição atual não dá para traçar o caminho.',
    'ROUTING_UNAVAILABLE' => 'O traçado não está disponível agora.',
    _ => 'Trajeto indisponível.',
  };

  /// Índice do ponto do traçado mais próximo de [posicao] — onde o
  /// entregador está, dentro do caminho planejado.
  int indiceMaisProximoDe(PontoGeo posicao) {
    var melhor = 0;
    var menorDistancia = double.infinity;
    for (var i = 0; i < geometria.length; i++) {
      final distancia = posicao.metrosAte(geometria[i]);
      if (distancia < menorDistancia) {
        menorDistancia = distancia;
        melhor = i;
      }
    }
    return melhor;
  }

  /// A manobra que vem a seguir, dada a posição atual.
  ///
  /// **Não é recálculo**: se o entregador sair do trajeto, isto continua
  /// apontando o passo do traçado planejado mais próximo dele — a rota
  /// só muda quando ele pedir. Recalcular sozinho a cada desvio
  /// multiplicaria chamadas ao provedor sem teto (RNF-A14.1).
  PassoDaRota? proximoPassoDe(PontoGeo? posicao) {
    if (passos.isEmpty) return null;
    if (posicao == null || geometria.isEmpty) return passos.first;

    final atual = indiceMaisProximoDe(posicao);
    for (final passo in passos) {
      if (passo.indiceNoTracado >= atual) return passo;
    }
    return passos.last;
  }

  /// Distância, em metros, do entregador até a manobra [passo] — soma
  /// dos trechos do traçado entre onde ele está e onde a curva acontece.
  double? metrosAte(PassoDaRota passo, PontoGeo? posicao) {
    if (posicao == null || geometria.isEmpty) return null;
    final atual = indiceMaisProximoDe(posicao);
    final alvo = passo.indiceNoTracado.clamp(0, geometria.length - 1);
    if (alvo <= atual) return 0;

    var total = posicao.metrosAte(geometria[atual]);
    for (var i = atual; i < alvo; i++) {
      total += geometria[i].metrosAte(geometria[i + 1]);
    }
    return total;
  }

  /// Quanto falta até o fim do trajeto, pelo caminho — não em linha
  /// reta.
  double? metrosRestantes(PontoGeo? posicao) {
    if (posicao == null || geometria.length < 2) return null;
    final atual = indiceMaisProximoDe(posicao);
    var total = posicao.metrosAte(geometria[atual]);
    for (var i = atual; i < geometria.length - 1; i++) {
      total += geometria[i].metrosAte(geometria[i + 1]);
    }
    return total;
  }
}

class RotaDoPedido {
  final String orderId;

  /// A mesma linha reta que a vitrine mostra (RF-11.7/RF-A14.5) —
  /// mantida na resposta justamente para que as duas medidas apareçam
  /// identificadas lado a lado, em vez de o entregador achar que uma
  /// delas está errada.
  final double? distanciaEmLinhaRetaKm;

  final Trajeto trajeto;

  /// RF-A14.7 — obrigação de licença do provedor (RNF-25.2), não
  /// enfeite: quando vem, aparece junto do mapa.
  final String? atribuicao;

  const RotaDoPedido({
    required this.orderId,
    this.distanciaEmLinhaRetaKm,
    this.trajeto = const Trajeto(),
    this.atribuicao,
  });

  factory RotaDoPedido.doJson(Map<String, dynamic> json) => RotaDoPedido(
    orderId: json['orderId'] as String? ?? '',
    distanciaEmLinhaRetaKm: (json['straightLineDistanceKm'] as num?)?.toDouble(),
    trajeto: Trajeto.doJson(json['route']),
    atribuicao: json['attribution'] as String?,
  );

  bool get temTracado => trajeto.temTracado;
}
