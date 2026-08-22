/// `GET /me/blocked-couriers` — `api/usuarios.md` (RF-A05.6).
class EntregadorBloqueado {
  final String entregadorId;
  final String? nome;
  final String? motivo;
  final DateTime? bloqueadoEm;

  const EntregadorBloqueado({
    required this.entregadorId,
    this.nome,
    this.motivo,
    this.bloqueadoEm,
  });

  factory EntregadorBloqueado.doJson(Map<String, dynamic> json) => EntregadorBloqueado(
    entregadorId: json['courierId'] as String? ?? '',
    nome: json['courierName'] as String? ?? json['displayName'] as String?,
    motivo: json['reason'] as String?,
    bloqueadoEm: switch (json['createdAt'] ?? json['blockedAt']) {
      final String v => DateTime.tryParse(v)?.toLocal(),
      _ => null,
    },
  );
}
