import '../rede/cliente_api.dart';
import '../rede/erros_api.dart';
import 'score.dart';

/// `GET /me/score` — `api/gamificacao.md`. Sem rota de escrita: o
/// score muda só por regra do sistema (RF-20.7 no backend real).
class RepositorioScore {
  final ClienteApi _api;

  const RepositorioScore(this._api);

  Future<Score> obter() async {
    final resposta = await _api.obter('/me/score');
    if (resposta is! Map) {
      throw const ErroInesperado(mensagem: 'Resposta de score fora do contrato.');
    }
    return Score.doJson(Map<String, dynamic>.from(resposta));
  }
}
