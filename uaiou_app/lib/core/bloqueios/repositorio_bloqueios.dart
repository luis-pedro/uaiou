import '../rede/cliente_api.dart';
import 'bloqueio.dart';

/// `GET`/`POST`/`DELETE /me/blocked-couriers` — restrito a MERCHANT
/// (`BlockedCouriersController.requireMerchant`).
class RepositorioBloqueios {
  final ClienteApi _api;

  const RepositorioBloqueios(this._api);

  Future<List<EntregadorBloqueado>> listar() async {
    final resposta = await _api.obter('/me/blocked-couriers');
    if (resposta is! List) return const [];
    return resposta
        .whereType<Map>()
        .map((b) => EntregadorBloqueado.doJson(Map<String, dynamic>.from(b)))
        .toList();
  }

  Future<void> bloquear({required String entregadorId, String? motivo}) => _api.criar(
    '/me/blocked-couriers',
    corpo: {'courierId': entregadorId, if (motivo != null && motivo.isNotEmpty) 'reason': motivo},
  );

  Future<void> desbloquear(String entregadorId) =>
      _api.remover('/me/blocked-couriers/$entregadorId');
}
