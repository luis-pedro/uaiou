/// ===============================================================
/// IDENTIDADE — papel e status da conta
/// ===============================================================
///
/// Vocabulário do contrato (`api/auth.md`), traduzido na borda como
/// manda RF-A01.8: `role` vem em MAIÚSCULAS (`COURIER`), `status` em
/// minúsculas (`active`).
library;

/// Papel do usuário. `ADMIN` existe no contrato mas **não tem cliente
/// no app** — é exclusivo do painel web (W-05).
enum Papel {
  entregador('COURIER'),
  estabelecimento('MERCHANT'),
  admin('ADMIN'),
  desconhecido('');

  const Papel(this.noContrato);

  /// Valor enviado e recebido na API.
  final String noContrato;

  static Papel doContrato(Object? bruto) {
    if (bruto is! String) return desconhecido;
    final valor = bruto.trim().toUpperCase();
    for (final papel in values) {
      if (papel.noContrato == valor) return papel;
    }
    return desconhecido;
  }

  String get rotulo => switch (this) {
    entregador => 'Entregador',
    estabelecimento => 'Estabelecimento',
    admin => 'Administrador',
    desconhecido => '—',
  };

  /// Rota inicial do papel depois do login (RF-A02.3).
  String? get rotaInicial => switch (this) {
    entregador => '/principal_entregador',
    estabelecimento => '/principal_estabelecimento',
    // O admin não tem área no app; cai na tela informativa.
    admin || desconhecido => null,
  };
}

/// Estado da conta (RN-11.1).
///
/// `banido` e `suspenso` **nunca chegam a virar sessão**: o servidor
/// recusa o login com 403. Aparecem aqui porque o `status` também
/// viaja dentro do token e pode mudar durante a sessão.
enum StatusConta {
  /// Cadastro enviado, aguardando moderação.
  pendente('pending'),

  ativo('active'),

  /// Cadastro avaliado e negado. Volta a [pendente] no reenvio.
  rejeitado('rejected'),

  suspenso('suspended'),
  banido('banned'),
  desconhecido('');

  const StatusConta(this.noContrato);

  final String noContrato;

  static StatusConta doContrato(Object? bruto) {
    if (bruto is! String) return desconhecido;
    final valor = bruto.trim().toLowerCase();
    for (final status in values) {
      if (status.noContrato == valor) return status;
    }
    return desconhecido;
  }

  /// Só conta ativa alcança as telas de operação (RF-A02.9).
  bool get podeOperar => this == ativo;
}

/// Usuário devolvido em `POST /auth/sessions`.
class UsuarioSessao {
  final String id;
  final Papel papel;
  final StatusConta status;
  final String nomeExibicao;

  const UsuarioSessao({
    required this.id,
    required this.papel,
    required this.status,
    required this.nomeExibicao,
  });

  factory UsuarioSessao.doJson(Map<String, dynamic> json) => UsuarioSessao(
    id: json['id'] as String? ?? '',
    papel: Papel.doContrato(json['role']),
    status: StatusConta.doContrato(json['status']),
    nomeExibicao: json['displayName'] as String? ?? '',
  );

  Map<String, dynamic> paraJson() => {
    'id': id,
    'role': papel.noContrato,
    'status': status.noContrato,
    'displayName': nomeExibicao,
  };
}
