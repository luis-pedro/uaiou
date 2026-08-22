/// ===============================================================
/// CAIXA DE ENTRADA — RF-A11.6/RF-A11.7 (`NotificationSummary.java`)
/// ===============================================================
///
/// **Divergência confirmada contra o backend real**: o exemplo de
/// `system-documentation/api/notificacoes.md` mostra um
/// `_links.deliveryCode` em cada item, mas o `NotificationSummary`
/// real (`com.uaiou.notifications.dto.NotificationSummary`) não tem
/// `_links` nenhum — só `id`, `type`, `priority`, `title`, `body`,
/// `payload`, `readAt`, `createdAt`. O deep link é montado no cliente
/// a partir de `type`/`payload`, não de um link pronto do servidor
/// (ver `controlador_notificacoes.dart#destino`).
library;

/// `NotificationPriority` — `urgent`/`normal` via `@JsonValue`
/// (nunca o nome do enum Java). RF-A11.3: contingência de código é
/// `urgent`.
enum PrioridadeNotificacao {
  normal,
  urgente;

  static PrioridadeNotificacao doJson(Object? valor) =>
      valor == 'urgent' ? PrioridadeNotificacao.urgente : PrioridadeNotificacao.normal;
}

class Notificacao {
  final String id;
  final String type;
  final PrioridadeNotificacao priority;
  final String title;
  final String body;

  /// RNF-A11.2 — o servidor já garante que nada sensível vai aqui; a
  /// tela nunca renderiza este mapa direto (RF-A11.10), só usa campos
  /// específicos e já validados para montar o deep link.
  final Map<String, Object?> payload;

  final DateTime? readAt;
  final DateTime? createdAt;

  const Notificacao({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.body,
    required this.payload,
    this.readAt,
    this.createdAt,
  });

  bool get lida => readAt != null;

  factory Notificacao.doJson(Map<String, dynamic> json) => Notificacao(
    id: json['id'] as String? ?? '',
    type: json['type'] as String? ?? '',
    priority: PrioridadeNotificacao.doJson(json['priority']),
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    payload: json['payload'] is Map
        ? Map<String, Object?>.from(json['payload'] as Map)
        : const {},
    readAt: _dataLocal(json['readAt']),
    createdAt: _dataLocal(json['createdAt']),
  );

  /// Marcada como lida localmente, sem esperar nova busca ao servidor
  /// — usado depois de `PUT /notifications/{id}/read` responder.
  Notificacao comoLida(DateTime quando) => Notificacao(
    id: id,
    type: type,
    priority: priority,
    title: title,
    body: body,
    payload: payload,
    readAt: quando,
    createdAt: createdAt,
  );
}

DateTime? _dataLocal(Object? bruto) {
  if (bruto is! String) return null;
  return DateTime.tryParse(bruto)?.toLocal();
}

/// `GET /me/notifications` (`NotificationListResponse.java`).
/// **Sem `_links`**: pagina por `page`/`perPage` manuais, não por
/// href do servidor (diferente de `Pagina<T>` de `modelos/pagina.dart`,
/// que é para listas com `_links`).
class RespostaNotificacoes {
  final List<Notificacao> data;
  final int page;
  final int perPage;
  final int total;

  /// `meta.unread` — contagem REAL do usuário, não do recorte da
  /// página (RF-A11.7): é o número que vai no badge.
  final int unread;

  const RespostaNotificacoes({
    required this.data,
    required this.page,
    required this.perPage,
    required this.total,
    required this.unread,
  });

  static const RespostaNotificacoes vazia = RespostaNotificacoes(
    data: [],
    page: 1,
    perPage: 20,
    total: 0,
    unread: 0,
  );

  /// Item malformado é descartado, não derruba a lista — mesmo
  /// critério de `Pagina.doJson`.
  factory RespostaNotificacoes.doJson(Object? json) {
    final mapa = json is Map ? json : const {};
    final bruto = mapa['data'];
    final itens = <Notificacao>[];
    if (bruto is List) {
      for (final item in bruto) {
        if (item is! Map) continue;
        try {
          itens.add(Notificacao.doJson(Map<String, dynamic>.from(item)));
        } on Object {
          continue;
        }
      }
    }

    final meta = mapa['meta'] is Map ? mapa['meta'] as Map : const {};
    return RespostaNotificacoes(
      data: itens,
      page: _inteiro(meta['page'], 1),
      perPage: _inteiro(meta['perPage'], 20),
      total: _inteiro(meta['total'], 0),
      unread: _inteiro(meta['unread'], 0),
    );
  }

  bool get temProximaPagina => page * perPage < total;
}

int _inteiro(Object? valor, int padrao) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  if (valor is String) return int.tryParse(valor) ?? padrao;
  return padrao;
}

/// `GET`/`PUT /me/notification-preferences`
/// (`NotificationPreferencesResponse.java`).
class PreferenciasNotificacao {
  final Map<String, bool> channels;

  /// Tipos que o servidor não deixa desligar — RF-A11.8: a interface
  /// mostra cadeado, não um botão que não funciona.
  final List<String> mandatory;

  const PreferenciasNotificacao({required this.channels, required this.mandatory});

  static const PreferenciasNotificacao vazia = PreferenciasNotificacao(
    channels: {},
    mandatory: [],
  );

  factory PreferenciasNotificacao.doJson(Object? json) {
    final mapa = json is Map ? json : const {};
    final canaisBrutos = mapa['channels'] is Map
        ? Map<String, dynamic>.from(mapa['channels'] as Map)
        : const <String, dynamic>{};
    final canais = <String, bool>{
      for (final entrada in canaisBrutos.entries)
        entrada.key: entrada.value == true,
    };

    final mandatorios = mapa['mandatory'] is List
        ? List<String>.from((mapa['mandatory'] as List).whereType<String>())
        : const <String>[];

    return PreferenciasNotificacao(channels: canais, mandatory: mandatorios);
  }

  bool ehObrigatorio(String canal) => mandatory.contains(canal);
}
