import '../rede/cliente_api.dart';
import '../rede/erros_api.dart';
import 'modelo_entrega.dart';

/// `delivery` — sub-recurso de execução do pedido (`api/entregas.md`).
///
/// Cada método devolve exatamente o que o servidor decidiu; nenhuma
/// regra de geofence ou de liberação de contingência é recalculada
/// aqui — ver a doc de [EstadoEntrega].
class RepositorioEntregas {
  final ClienteApi _api;

  const RepositorioEntregas(this._api);

  Future<EstadoEntrega> obter(String pedidoId) async {
    final resposta = await _api.obter('/orders/$pedidoId/delivery');
    if (resposta is! Map) {
      throw const ErroInesperado(
        mensagem: 'Resposta de entrega fora do contrato.',
      );
    }
    return EstadoEntrega.doJson(Map<String, dynamic>.from(resposta));
  }

  /// `POST .../completion` em `mode: "code"` — RF-A08.4/RF-A08.8.
  Future<void> finalizarPorCodigo(
    String pedidoId, {
    required String codigo,
    required double lat,
    required double lng,
    required String chaveIdempotencia,
  }) async {
    await _api.criar(
      '/orders/$pedidoId/delivery/completion',
      corpo: {'mode': 'code', 'deliveryCode': codigo, 'lat': lat, 'lng': lng},
      chaveIdempotencia: chaveIdempotencia,
    );
  }

  /// `POST .../completion` em `mode: "contestable"` — RF-A08.6/RF-A08.8.
  Future<void> finalizarContestavel(
    String pedidoId, {
    required String uploadId,
    required double lat,
    required double lng,
    required String chaveIdempotencia,
  }) async {
    await _api.criar(
      '/orders/$pedidoId/delivery/completion',
      corpo: {
        'mode': 'contestable',
        'proofUploadId': uploadId,
        'lat': lat,
        'lng': lng,
      },
      chaveIdempotencia: chaveIdempotencia,
    );
  }

  /// `POST .../code-recoveries` — RF-A08.5. Devolve o corpo cru: os
  /// campos (`step`, `channel`, `merchantDeadlineAt`) são só para
  /// exibição, e a fonte de verdade continua sendo o próximo
  /// `GET .../delivery` do polling.
  Future<Map<String, dynamic>> solicitarRecuperacao(
    String pedidoId, {
    String motivo = 'receiver_without_code',
  }) async {
    final resposta = await _api.criar(
      '/orders/$pedidoId/delivery/code-recoveries',
      corpo: {'reason': motivo},
    );
    if (resposta is! Map) return const {};
    return Map<String, dynamic>.from(resposta);
  }
}
