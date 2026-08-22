import '../rede/cliente_api.dart';
import '../rede/erros_api.dart';
import 'modelo_ganhos.dart';

/// `GET /me/earnings` / `POST /me/earnings/settlements` —
/// `MyEarningsController.java` (T-18, consumido por A-09).
class RepositorioGanhos {
  final ClienteApi _api;

  const RepositorioGanhos(this._api);

  Future<RespostaGanhos> obter({int? pagina, int? porPagina}) async {
    final resposta = await _api.obter(
      '/me/earnings',
      query: {'page': ?pagina, 'perPage': ?porPagina},
    );
    return RespostaGanhos.doJson(resposta);
  }

  /// Segue `_links.next` do extrato — RF-A09.6. O app não monta a
  /// query da próxima página por conta própria.
  Future<RespostaGanhos> seguir(String href) async =>
      RespostaGanhos.doJson(await _api.seguir(href));

  /// `POST /me/earnings/settlements` — RF-A09.3.
  ///
  /// **O campo do corpo é `lancamentoIds`, em português**, sem
  /// `@JsonProperty` no DTO (`SettlementRequest.java`): a doc
  /// `financeiro.md` está desatualizada e não descreve esta rota.
  Future<void> confirmarAcerto(List<String> lancamentoIds) async {
    if (lancamentoIds.isEmpty) return;
    final resposta = await _api.criar(
      '/me/earnings/settlements',
      corpo: {'lancamentoIds': lancamentoIds},
    );
    if (resposta is! Map) {
      throw const ErroInesperado(
        mensagem: 'Resposta de acerto fora do contrato.',
      );
    }
  }
}
