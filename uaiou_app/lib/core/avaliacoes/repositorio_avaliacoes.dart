import '../rede/cliente_api.dart';
import '../rede/erros_api.dart';
import '../rede/idempotencia.dart';
import 'modelo_avaliacao.dart';

/// `reviews` — `POST /orders/{id}/reviews` e `GET /me/reviews`
/// (contrato real, não `api/avaliacoes.md` — ver `modelo_avaliacao.dart`
/// para as divergências conferidas contra o backend).
class RepositorioAvaliacoes {
  final ClienteApi _api;

  const RepositorioAvaliacoes(this._api);

  /// RF-A12.1/RF-A12.2 — avalia a contraparte de um pedido finalizado.
  /// **Nunca envia `targetId`**: o alvo é sempre derivado no servidor
  /// a partir do `orderId` (`CreateReviewRequest.java` não tem esse
  /// campo — aceitá-lo do cliente permitiria avaliar terceiros).
  Future<AvaliacaoCriada> criar(
    String orderId, {
    required int rating,
    String? comment,
  }) async {
    final corpo = <String, dynamic>{
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    };
    final resposta = await _api.criar(
      '/orders/$orderId/reviews',
      corpo: corpo,
      chaveIdempotencia: gerarChaveIdempotencia('review-$orderId'),
    );
    if (resposta is! Map) {
      throw const ErroInesperado(mensagem: 'Resposta de avaliação fora do contrato.');
    }
    return AvaliacaoCriada.doJson(Map<String, dynamic>.from(resposta));
  }

  /// `GET /me/reviews?direction=pending` — lista simples, **sem**
  /// envelope `data`/paginação (`MyReviewsController.pending` devolve
  /// `List<PendingReviewEntry>` puro, não um objeto com `_links`).
  Future<List<AvaliacaoPendente>> pendentes() async {
    final resposta = await _api.obter('/me/reviews', query: const {'direction': 'pending'});
    if (resposta is! List) {
      throw const ErroInesperado(mensagem: 'Resposta de pendentes fora do contrato.');
    }
    return resposta
        .whereType<Map>()
        .map((e) => AvaliacaoPendente.doJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `GET /me/reviews?direction=received` — `summary` + `data`
  /// completo, também sem paginação (ver `RespostaAvaliacoesRecebidas`).
  Future<RespostaAvaliacoesRecebidas> recebidas() async {
    final resposta = await _api.obter('/me/reviews', query: const {'direction': 'received'});
    if (resposta is! Map) {
      throw const ErroInesperado(mensagem: 'Resposta de recebidas fora do contrato.');
    }
    return RespostaAvaliacoesRecebidas.doJson(Map<String, dynamic>.from(resposta));
  }
}
