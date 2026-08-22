import '../rede/cliente_api.dart';
import '../rede/erros_api.dart';
import 'modelo_notificacao.dart';

/// `GET/PUT /me/notifications*` e `/me/notification-preferences` —
/// `MeNotificationsController.java` (RF-A11.6/RF-A11.7/RF-A11.8).
class RepositorioNotificacoes {
  final ClienteApi _api;

  const RepositorioNotificacoes(this._api);

  Future<RespostaNotificacoes> obter({
    bool? somenteNaoLidas,
    String? tipo,
    int? pagina,
    int? porPagina,
  }) async {
    final resposta = await _api.obter(
      '/me/notifications',
      query: {
        'unread': ?somenteNaoLidas,
        'type': ?tipo,
        'page': ?pagina,
        'perPage': ?porPagina,
      },
    );
    return RespostaNotificacoes.doJson(resposta);
  }

  /// `PUT /me/notifications/{id}/read` — devolve o item atualizado.
  Future<Notificacao> marcarLida(String id) async {
    final resposta = await _api.substituir('/me/notifications/$id/read');
    if (resposta is! Map) {
      throw const ErroInesperado(
        mensagem: 'Resposta de marcar como lida fora do contrato.',
      );
    }
    return Notificacao.doJson(Map<String, dynamic>.from(resposta));
  }

  /// `PUT /me/notifications/read` — `{ "marked": <long> }`.
  Future<int> marcarTodasLidas() async {
    final resposta = await _api.substituir('/me/notifications/read');
    if (resposta is! Map) return 0;
    final marcado = resposta['marked'];
    if (marcado is num) return marcado.toInt();
    return 0;
  }

  Future<PreferenciasNotificacao> obterPreferencias() async =>
      PreferenciasNotificacao.doJson(await _api.obter('/me/notification-preferences'));

  /// `PUT /me/notification-preferences` — **campo ausente mantém o
  /// valor atual no servidor**: nunca manda um canal que o usuário
  /// não tocou (por isso os parâmetros são todos opcionais e só
  /// entram no corpo quando não-nulos).
  Future<PreferenciasNotificacao> atualizarPreferencias({
    bool? push,
    bool? email,
    bool? sms,
  }) async {
    final resposta = await _api.substituir(
      '/me/notification-preferences',
      corpo: {
        'channels': {'push': ?push, 'email': ?email, 'sms': ?sms},
      },
    );
    return PreferenciasNotificacao.doJson(resposta);
  }
}
