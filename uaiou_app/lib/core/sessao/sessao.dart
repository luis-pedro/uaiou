import 'dart:convert';

import 'identidade.dart';

/// Sessão autenticada — o que `POST /auth/sessions` devolve, mais o
/// instante calculado de expiração do access token.
class Sessao {
  final String accessToken;
  final String refreshToken;

  /// Quando o [accessToken] deixa de valer, em fuso local.
  final DateTime expiraEm;

  final UsuarioSessao usuario;

  const Sessao({
    required this.accessToken,
    required this.refreshToken,
    required this.expiraEm,
    required this.usuario,
  });

  /// `expiresIn` vem em **segundos**; guardamos o instante para não
  /// depender de quanto tempo o app ficou fechado.
  factory Sessao.doJson(Map<String, dynamic> json) {
    final segundos = switch (json['expiresIn']) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v) ?? 0,
      _ => 0,
    };

    final usuario = json['usuario'] ?? json['user'];

    return Sessao(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiraEm: DateTime.now().add(Duration(seconds: segundos)),
      usuario: UsuarioSessao.doJson(
        usuario is Map ? Map<String, dynamic>.from(usuario) : const {},
      ),
    );
  }

  /// Margem antes da expiração real.
  ///
  /// Renovar só depois de expirar garante ao menos um 401 por ciclo;
  /// antecipar evita que uma requisição saia com token que morre em
  /// trânsito.
  static const Duration _margem = Duration(seconds: 30);

  bool get expirado => DateTime.now().isAfter(expiraEm.subtract(_margem));

  bool get valido => accessToken.isNotEmpty && !expirado;

  String paraJsonTexto() => jsonEncode({
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiraEm': expiraEm.toIso8601String(),
    'usuario': usuario.paraJson(),
  });

  /// Reconstrói do cofre. Devolve `null` se o conteúdo não serve —
  /// credencial corrompida é tratada como ausência de sessão, nunca
  /// como falha que trava a abertura do app.
  static Sessao? deJsonTexto(String? texto) {
    if (texto == null || texto.isEmpty) return null;
    try {
      final json = jsonDecode(texto);
      if (json is! Map) return null;

      final accessToken = json['accessToken'] as String? ?? '';
      final refreshToken = json['refreshToken'] as String? ?? '';
      if (refreshToken.isEmpty) return null;

      final expiraEm = DateTime.tryParse(json['expiraEm'] as String? ?? '');
      if (expiraEm == null) return null;

      return Sessao(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiraEm: expiraEm,
        usuario: UsuarioSessao.doJson(
          Map<String, dynamic>.from(json['usuario'] as Map? ?? const {}),
        ),
      );
    } on Object {
      return null;
    }
  }

  Sessao comUsuario(UsuarioSessao novo) => Sessao(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiraEm: expiraEm,
    usuario: novo,
  );
}
