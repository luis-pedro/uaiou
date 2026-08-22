import '../rede/cliente_api.dart';
import 'identidade.dart';
import 'sessao.dart';

/// ===============================================================
/// REPOSITÓRIO DE AUTENTICAÇÃO — `api/auth.md`
/// ===============================================================
///
/// `POST /auth/sessions` é **um recurso com três credenciais**,
/// selecionadas por `grantType`. Nenhuma tela conhece essas rotas.
class RepositorioAuth {
  final ClienteApi _api;

  const RepositorioAuth(this._api);

  /// RF-A02.1 — login por senha.
  ///
  /// [papel] é obrigatório no contrato: o servidor recusa com 422
  /// `ROLE_MISMATCH` se a conta não for do tipo informado (RF-03.5).
  Future<Sessao> entrarComSenha({
    required String login,
    required String senha,
    required Papel papel,
  }) => _abrirSessao({
    'grantType': 'password',
    'login': login,
    'password': senha,
    'role': papel.noContrato,
  });

  /// RF-A02.2 — login com Google.
  ///
  /// O servidor **não cria conta implícita**: sem cadastro vinculado
  /// devolve 404 `GOOGLE_ACCOUNT_NOT_LINKED`.
  Future<Sessao> entrarComGoogle({
    required String idToken,
    required Papel papel,
  }) => _abrirSessao({
    'grantType': 'google',
    'idToken': idToken,
    'role': papel.noContrato,
  });

  /// RF-A02.5 — renovação com rotação.
  ///
  /// Reusar um refresh já revogado derruba a família inteira de
  /// sessões (RF-03.8): é assinatura de vazamento.
  Future<Sessao> renovar(String refreshToken) =>
      _abrirSessao({'grantType': 'refresh', 'refreshToken': refreshToken});

  /// RF-A02.7 — encerra só a sessão atual; outros aparelhos seguem
  /// logados. É idempotente no servidor.
  Future<void> sair(String refreshToken) async {
    await _api.remover(
      '/auth/sessions/current',
      corpo: {'refreshToken': refreshToken},
    );
  }

  /// RF-A02.8 — pede o e-mail de recuperação.
  ///
  /// Responde 202 mesmo para e-mail inexistente: confirmar o
  /// contrário entregaria quais contas existem.
  Future<void> pedirRecuperacaoDeSenha(String email) async {
    await _api.criar('/auth/password-resets', corpo: {'email': email});
  }

  Future<Sessao> _abrirSessao(Map<String, dynamic> corpo) async {
    final resposta = await _api.criar('/auth/sessions', corpo: corpo);
    if (resposta is! Map) {
      throw StateError('Resposta de sessão fora do contrato.');
    }
    return Sessao.doJson(Map<String, dynamic>.from(resposta));
  }
}
