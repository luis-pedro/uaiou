import '../modelos/dinheiro.dart';

/// `CounterofferResponse` — contraoferta recebida pelo estabelecimento
/// (`GET /orders/{id}/counteroffers`, api/pedidos.md). RF-A10.6.
enum StatusContraoferta {
  pendente,
  aceita,
  recusada,
  invalidada,
  desconhecido;

  static StatusContraoferta doContrato(Object? bruto) => switch (bruto) {
    'pending' => pendente,
    'accepted' => aceita,
    'rejected' => recusada,
    'invalidated' => invalidada,
    _ => desconhecido,
  };
}

class Contraoferta {
  final String id;
  final String pedidoId;
  final String? courierId;
  final String nomeEntregador;

  /// 0.0–1.0 ou nulo — quem não tem base ainda de score (RF-20.9 é
  /// posterior). O app não inventa "sem base"/"0": só exibe se vier.
  final double? scoreEntregador;

  final Dinheiro valorProposto;
  final StatusContraoferta status;
  final DateTime? criadaEm;

  const Contraoferta({
    required this.id,
    required this.pedidoId,
    required this.nomeEntregador,
    required this.valorProposto,
    required this.status,
    this.courierId,
    this.scoreEntregador,
    this.criadaEm,
  });

  bool get pendente => status == StatusContraoferta.pendente;

  factory Contraoferta.doJson(Map<String, dynamic> json) => Contraoferta(
    id: json['id'] as String? ?? '',
    pedidoId: json['orderId'] as String? ?? '',
    courierId: json['courierId'] as String?,
    nomeEntregador: json['courierName'] as String? ?? 'Entregador',
    scoreEntregador: (json['courierScore'] as num?)?.toDouble(),
    valorProposto:
        Dinheiro.tentarDeString(json['proposedFee']?.toString()) ??
        Dinheiro.zero,
    status: StatusContraoferta.doContrato(json['status']),
    criadaEm: switch (json['createdAt']) {
      final String v => DateTime.tryParse(v)?.toLocal(),
      _ => null,
    },
  );
}

/// `GET /orders/{id}/delivery/code` — código a repassar ao recebedor
/// (RF-A10.7). Só o estabelecimento dono enxerga esta rota.
class CodigoDeEntrega {
  final String pedidoId;
  final String codigo;
  final String status;
  final DateTime? expiraEm;

  const CodigoDeEntrega({
    required this.pedidoId,
    required this.codigo,
    required this.status,
    this.expiraEm,
  });

  factory CodigoDeEntrega.doJson(Map<String, dynamic> json) => CodigoDeEntrega(
    pedidoId: json['orderId'] as String? ?? '',
    codigo: json['code'] as String? ?? '',
    status: json['status'] as String? ?? '',
    expiraEm: switch (json['expiresAt']) {
      final String v => DateTime.tryParse(v)?.toLocal(),
      _ => null,
    },
  );
}
