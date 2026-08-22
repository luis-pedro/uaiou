import '../rede/cliente_api.dart';
import 'modelo_payables.dart';

/// `GET /me/payables` — `MyPayablesController.java` (T-18), restrito a
/// MERCHANT no backend. RF-A10.9.
class RepositorioPayables {
  final ClienteApi _api;

  const RepositorioPayables(this._api);

  Future<Payables> obter() async {
    final resposta = await _api.obter('/me/payables');
    return Payables.doJson(resposta);
  }
}
