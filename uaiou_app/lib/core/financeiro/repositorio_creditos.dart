import '../rede/cliente_api.dart';
import '../rede/erros_api.dart';
import 'creditos.dart';

/// `GET /me/credits` — restrito a MERCHANT no backend
/// (`MyCreditsController.requireMerchant`).
class RepositorioCreditos {
  final ClienteApi _api;

  const RepositorioCreditos(this._api);

  Future<Creditos> obter() async {
    final resposta = await _api.obter('/me/credits');
    if (resposta is! Map) {
      throw const ErroInesperado(mensagem: 'Resposta de créditos fora do contrato.');
    }
    return Creditos.doJson(Map<String, dynamic>.from(resposta));
  }
}
