import '../modelos/links.dart';

/// ===============================================================
/// ESTADO DA ENTREGA — RF-A08.2
/// ===============================================================
///
/// Espelha o corpo de `GET /orders/{id}/delivery` (`api/entregas.md`).
/// **É a única fonte de verdade** do que o entregador pode fazer agora
/// — a tela lê `_links`, não deduz o passo pela navegação (RNF-A08.2).
class Geofence {
  final bool dentro;
  final int? raioMetros;
  final int? distanciaMetros;

  /// Ex.: `stale_location` — posição velha demais para o cálculo.
  final String? motivo;

  const Geofence({
    required this.dentro,
    this.raioMetros,
    this.distanciaMetros,
    this.motivo,
  });

  factory Geofence.doJson(Object? json) {
    if (json is! Map) return const Geofence(dentro: false);
    return Geofence(
      dentro: json['inside'] == true,
      raioMetros: (json['radiusMeters'] as num?)?.toInt(),
      distanciaMetros: (json['distanceMeters'] as num?)?.toInt(),
      motivo: json['reason'] as String?,
    );
  }
}

/// O código em si **nunca** chega ao app (RN-08.3) — só o estado da
/// tentativa.
class CodigoDeEntrega {
  final String status;

  /// Contagem é do servidor — o app não conta por conta própria
  /// (RF-A08.4).
  final int? tentativasRestantes;
  final List<String> canais;

  const CodigoDeEntrega({
    this.status = '',
    this.tentativasRestantes,
    this.canais = const [],
  });

  factory CodigoDeEntrega.doJson(Object? json) {
    if (json is! Map) return const CodigoDeEntrega();
    return CodigoDeEntrega(
      status: json['status'] as String? ?? '',
      tentativasRestantes: (json['attemptsLeft'] as num?)?.toInt(),
      canais: (json['channels'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }
}

/// Escada de contingência (T-16) — RF-A08.5.
class Contingencia {
  final int? degrau;

  /// Liberação da finalização contestável é do servidor (RN-10.1),
  /// nunca decidida no cliente — RF-A08.7.
  final bool contestavelLiberada;
  final String? canal;
  final DateTime? prazoDoEstabelecimento;
  final bool penalidadeAplicada;

  const Contingencia({
    this.degrau,
    this.contestavelLiberada = false,
    this.canal,
    this.prazoDoEstabelecimento,
    this.penalidadeAplicada = false,
  });

  factory Contingencia.doJson(Object? json) {
    if (json is! Map) return const Contingencia();
    return Contingencia(
      degrau: (json['step'] as num?)?.toInt(),
      contestavelLiberada: json['contestableReleased'] == true,
      canal: json['channel'] as String?,
      prazoDoEstabelecimento: _dataLocal(json['merchantDeadlineAt']),
      penalidadeAplicada: json['merchantPenaltyApplied'] == true,
    );
  }
}

DateTime? _dataLocal(Object? bruto) {
  if (bruto is! String) return null;
  return DateTime.tryParse(bruto)?.toLocal();
}

class EstadoEntrega {
  final String orderId;
  final String status;
  final Geofence geofence;
  final CodigoDeEntrega codigo;
  final Contingencia contingencia;

  /// `completion`/`codeRecoveries` — só existem quando o servidor
  /// oferece a transição (RF-A08.3/RF-A08.7).
  final Links links;

  const EstadoEntrega({
    required this.orderId,
    required this.status,
    this.geofence = const Geofence(dentro: false),
    this.codigo = const CodigoDeEntrega(),
    this.contingencia = const Contingencia(),
    this.links = Links.vazio,
  });

  factory EstadoEntrega.doJson(Map<String, dynamic> json) => EstadoEntrega(
    orderId: json['orderId'] as String? ?? '',
    status: json['status'] as String? ?? '',
    geofence: Geofence.doJson(json['geofence']),
    codigo: CodigoDeEntrega.doJson(json['deliveryCode']),
    contingencia: Contingencia.doJson(json['contingency']),
    links: Links.doJson(json['_links']),
  );

  /// A pergunta que a tela faz para mostrar o botão de finalizar por
  /// código — RF-A08.3.
  bool get podeFinalizar => links.permite('completion');

  bool get podeAcionarContingencia => links.permite('codeRecoveries');

  /// RF-A08.6/RF-A08.7 — só quando a escada esgotou.
  bool get contestavelDisponivel => contingencia.contestavelLiberada;

  bool get finalizada => status == 'finalized' || status == 'contestable_finalized';
}
