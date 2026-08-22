/// ===============================================================
/// AVALIAÇÕES — A-12
/// ===============================================================
///
/// Espelha `POST /orders/{id}/reviews` e `GET /me/reviews` (contrato
/// real conferido em `reviews/web/ReviewsController.java` e
/// `MyReviewsController.java`, não a doc `api/avaliacoes.md` — ver
/// as divergências documentadas abaixo).
library;

/// Resposta de `POST /orders/{id}/reviews` — 201.
///
/// **Sem `targetId` no pedido**: o alvo é sempre derivado no servidor
/// a partir do pedido (`CreateReviewRequest.java`), nunca aceito do
/// corpo — RF-A12.1/RF-19.3 do backend. `targetId` só aparece aqui,
/// na resposta, não no que o app envia.
class AvaliacaoCriada {
  final String id;
  final String orderId;
  final String targetId;
  final int rating;
  final String? comment;
  final DateTime? createdAt;

  const AvaliacaoCriada({
    required this.id,
    required this.orderId,
    required this.targetId,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  factory AvaliacaoCriada.doJson(Map<String, dynamic> json) => AvaliacaoCriada(
    id: json['id']?.toString() ?? '',
    orderId: json['orderId']?.toString() ?? '',
    targetId: json['targetId']?.toString() ?? '',
    rating: (json['rating'] as num?)?.toInt() ?? 0,
    comment: json['comment'] as String?,
    createdAt: switch (json['createdAt']) {
      final String v => DateTime.tryParse(v)?.toLocal(),
      _ => null,
    },
  );
}

/// `GET /me/reviews?direction=pending` — `PendingReviewEntry` do
/// backend. **Esta lista É o gate real de RF-A12.1**: o backend não
/// expõe `_links.reviews` em `GET /orders/{id}` nem em
/// `GET /orders/{id}/delivery` (conferido nos dois DTOs reais,
/// `OrderResponse.java`/`DeliveryStateResponse.java` — nenhum dos
/// dois tem chave `reviews` em `_links`). Um pedido só aparece aqui
/// enquanto a avaliação dele ainda está dentro do prazo (`deadline`),
/// então "está na lista de pendentes" é o sinal correto para oferecer
/// o botão de avaliar — equivalente, na prática, ao que a spec pedia
/// via `_links`.
class AvaliacaoPendente {
  final String orderId;
  final String orderNumber;
  final String counterpartyId;
  final String counterpartyName;
  final DateTime? deadline;

  const AvaliacaoPendente({
    required this.orderId,
    required this.orderNumber,
    required this.counterpartyId,
    required this.counterpartyName,
    this.deadline,
  });

  factory AvaliacaoPendente.doJson(Map<String, dynamic> json) => AvaliacaoPendente(
    orderId: json['orderId']?.toString() ?? '',
    orderNumber: json['orderNumber']?.toString() ?? '',
    counterpartyId: json['counterpartyId']?.toString() ?? '',
    counterpartyName: json['counterpartyName'] as String? ?? '',
    deadline: switch (json['deadline']) {
      final String v => DateTime.tryParse(v)?.toLocal(),
      _ => null,
    },
  );
}

/// Um item de `GET /me/reviews?direction=received` — o que a outra
/// parte escreveu sobre pedidos já concluídos. **É a leitura cruzada
/// real que o app oferece para RF-A12.3**: não existe
/// `GET /orders/{id}/reviews` no backend (conferido exaustivamente em
/// `reviews/web/` — só há `POST /orders/{id}/reviews` e
/// `GET /me/reviews`), então não há como ler, pedido a pedido, o que
/// a contraparte escreveu logo após finalizar. O que dá para mostrar
/// — e é mostrado aqui — é o agregado de tudo que a pessoa já
/// recebeu, com `comment`/`rating` por avaliação.
class AvaliacaoRecebida {
  final String id;
  final String orderId;
  final String orderNumber;
  final int rating;
  final String? comment;
  final bool active;
  final DateTime? createdAt;

  const AvaliacaoRecebida({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.rating,
    this.comment,
    required this.active,
    this.createdAt,
  });

  factory AvaliacaoRecebida.doJson(Map<String, dynamic> json) => AvaliacaoRecebida(
    id: json['id']?.toString() ?? '',
    orderId: json['orderId']?.toString() ?? '',
    orderNumber: json['orderNumber']?.toString() ?? '',
    rating: (json['rating'] as num?)?.toInt() ?? 0,
    comment: json['comment'] as String?,
    active: json['active'] == true,
    createdAt: switch (json['createdAt']) {
      final String v => DateTime.tryParse(v)?.toLocal(),
      _ => null,
    },
  );
}

/// `summary` de `GET /me/reviews?direction=received`. `activeRate`
/// existe para que uma média alta formada por avaliações automáticas
/// (padrão positivo do job, RF-A12.2) não passe por excelência real —
/// a tela mostra os dois números lado a lado, nunca só a média.
class ResumoAvaliacoesRecebidas {
  final double average;
  final double activeRate;
  final int count;

  const ResumoAvaliacoesRecebidas({
    required this.average,
    required this.activeRate,
    required this.count,
  });

  factory ResumoAvaliacoesRecebidas.doJson(Map<String, dynamic> json) =>
      ResumoAvaliacoesRecebidas(
        average: (json['average'] as num?)?.toDouble() ?? 0,
        activeRate: (json['activeRate'] as num?)?.toDouble() ?? 0,
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

/// `GET /me/reviews?direction=received` inteiro.
///
/// **Sem paginação**: `ReceivedReviewsResponse.java` (backend real)
/// devolve `{ summary, data }` sem `_links` nem `meta.page` — RF-A12.7
/// da spec pede "paginado por `_links`", mas isso não existe hoje no
/// backend. `data` já vem completo; o app não inventa paginação
/// client-side nem chama uma rota de página seguinte que não existe.
class RespostaAvaliacoesRecebidas {
  final ResumoAvaliacoesRecebidas resumo;
  final List<AvaliacaoRecebida> itens;

  const RespostaAvaliacoesRecebidas({required this.resumo, this.itens = const []});

  factory RespostaAvaliacoesRecebidas.doJson(Map<String, dynamic> json) =>
      RespostaAvaliacoesRecebidas(
        resumo: json['summary'] is Map
            ? ResumoAvaliacoesRecebidas.doJson(Map<String, dynamic>.from(json['summary'] as Map))
            : const ResumoAvaliacoesRecebidas(average: 0, activeRate: 0, count: 0),
        itens: json['data'] is List
            ? (json['data'] as List)
                  .whereType<Map>()
                  .map((e) => AvaliacaoRecebida.doJson(Map<String, dynamic>.from(e)))
                  .toList()
            : const [],
      );
}
