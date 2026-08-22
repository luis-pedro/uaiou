import '../rede/cliente_api.dart';
import 'modelo_estatisticas.dart';
import 'modelo_estatisticas_estabelecimento.dart';

/// `GET /me/stats?period=` — `MyStatsController.java`/`StatsService`.
///
/// Escopo travado no token (RF-22.1 do backend): não existe parâmetro
/// de usuário nesta rota, e o app não tenta passar um. A mesma rota
/// devolve `CourierStatsResponse` ou `MerchantStatsResponse` conforme
/// o papel do token — os dois métodos abaixo só diferem no conversor.
class RepositorioEstatisticas {
  final ClienteApi _api;

  const RepositorioEstatisticas(this._api);

  /// [periodo] aceita `7d` | `30d` | `cycle` (`api/estatisticas.md`).
  /// `null` deixa o servidor escolher o padrão.
  Future<EstatisticasEntregador> obter({String? periodo}) async {
    final resposta = await _api.obter(
      '/me/stats',
      query: {'period': ?periodo},
    );
    return EstatisticasEntregador.doJson(resposta);
  }

  /// RF-A10.10 — lado do estabelecimento (`MerchantStatsResponse`).
  Future<EstatisticasEstabelecimento> obterEstabelecimento({String? periodo}) async {
    final resposta = await _api.obter(
      '/me/stats',
      query: {'period': ?periodo},
    );
    return EstatisticasEstabelecimento.doJson(resposta);
  }
}
