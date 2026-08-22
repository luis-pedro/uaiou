/// `GET /me/credits` — `api/financeiro.md` (RF-A05.5).
///
/// A v1 não vende crédito no app (plano atribuído pelo admin): este
/// modelo não carrega link de compra, e a tela não desenha botão de
/// comprar mesmo se o servidor um dia oferecer `_links.purchases`.
class AssinaturaDeCreditos {
  final String nomeDoPlano;
  final int creditosMensais;
  final int consumidosNoCiclo;
  final DateTime? renovaEm;
  final String status;

  const AssinaturaDeCreditos({
    required this.nomeDoPlano,
    required this.creditosMensais,
    required this.consumidosNoCiclo,
    this.renovaEm,
    required this.status,
  });

  factory AssinaturaDeCreditos.doJson(Map<String, dynamic> json) => AssinaturaDeCreditos(
    nomeDoPlano: json['planName'] as String? ?? '',
    creditosMensais: (json['monthlyCredits'] as num?)?.toInt() ?? 0,
    consumidosNoCiclo: (json['consumedThisCycle'] as num?)?.toInt() ?? 0,
    renovaEm: switch (json['renewsAt']) {
      final String v => DateTime.tryParse(v),
      _ => null,
    },
    status: json['status'] as String? ?? '',
  );
}

class Creditos {
  final int saldo;
  final AssinaturaDeCreditos? assinatura;

  const Creditos({required this.saldo, this.assinatura});

  factory Creditos.doJson(Map<String, dynamic> json) => Creditos(
    saldo: (json['creditsBalance'] as num?)?.toInt() ?? 0,
    assinatura: json['subscription'] is Map
        ? AssinaturaDeCreditos.doJson(Map<String, dynamic>.from(json['subscription'] as Map))
        : null,
  );
}
