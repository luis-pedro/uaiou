import 'links.dart';

/// ===============================================================
/// PAGINAÇÃO — RF-A01.9
/// ===============================================================
///
/// Formato do contrato:
///
/// ```json
/// {
///   "data": [],
///   "meta": { "page": 1, "perPage": 20, "total": 137 },
///   "_links": { "self": {...}, "next": {...} }
/// }
/// ```
///
/// A lista avança pelo `_links.next` que o servidor mandou — o app
/// não calcula deslocamento nem monta query de página por conta.

class MetaPagina {
  final int pagina;
  final int porPagina;
  final int total;

  const MetaPagina({
    required this.pagina,
    required this.porPagina,
    required this.total,
  });

  factory MetaPagina.doJson(Object? json) {
    final mapa = json is Map ? json : const {};
    return MetaPagina(
      pagina: _inteiro(mapa['page'], 1),
      porPagina: _inteiro(mapa['perPage'], 20),
      total: _inteiro(mapa['total'], 0),
    );
  }

  static int _inteiro(Object? valor, int padrao) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    if (valor is String) return int.tryParse(valor) ?? padrao;
    return padrao;
  }
}

class Pagina<T> {
  final List<T> itens;
  final MetaPagina meta;
  final Links links;

  const Pagina({required this.itens, required this.meta, required this.links});

  Pagina.vazia()
    : itens = const [],
      meta = const MetaPagina(pagina: 1, porPagina: 20, total: 0),
      links = Links.vazio;

  /// Desserializa a página convertendo cada item com [converter].
  ///
  /// Item malformado **não derruba a lista inteira**: é descartado, e
  /// os demais chegam à tela. Uma linha ruim no servidor não pode
  /// deixar o entregador sem vitrine.
  factory Pagina.doJson(
    Object? json,
    T Function(Map<String, dynamic> item) converter,
  ) {
    final mapa = json is Map ? json : const {};
    final bruto = mapa['data'];

    final itens = <T>[];
    if (bruto is List) {
      for (final item in bruto) {
        if (item is! Map) continue;
        try {
          itens.add(converter(Map<String, dynamic>.from(item)));
        } on Object {
          // Item inválido é ignorado — ver doc acima.
          continue;
        }
      }
    }

    return Pagina(
      itens: itens,
      meta: MetaPagina.doJson(mapa['meta']),
      links: Links.doJson(mapa['_links']),
    );
  }

  bool get estaVazia => itens.isEmpty;

  /// Href da próxima página, ou `null` se esta é a última.
  String? get proximaHref => links['next']?.href;

  bool get temProxima => proximaHref != null;

  /// Concatena a página seguinte, preservando o `meta`/`_links` dela.
  Pagina<T> mais(Pagina<T> proxima) => Pagina(
    itens: [...itens, ...proxima.itens],
    meta: proxima.meta,
    links: proxima.links,
  );
}
