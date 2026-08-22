/// ===============================================================
/// _links — RF-A01.10
/// ===============================================================
///
/// O contrato mira HATEOAS: toda resposta traz as transições
/// **permitidas naquele estado para aquele papel**. Isso não é
/// enfeite — é o que evita o app reimplementar geofence,
/// elegibilidade e prazo (api/README, princípio 3).
///
/// Regra de uso: **botão que a API não ofereceu não é renderizado.**
library;

class LinkRef {
  final String href;

  const LinkRef(this.href);

  static LinkRef? doJson(Object? json) {
    if (json is Map && json['href'] is String) {
      return LinkRef(json['href'] as String);
    }
    return null;
  }

  @override
  String toString() => href;
}

/// Coleção de transições que o servidor ofereceu para um recurso.
class Links {
  final Map<String, LinkRef> _mapa;

  const Links(this._mapa);

  static const Links vazio = Links({});

  factory Links.doJson(Object? json) {
    if (json is! Map) return vazio;

    final mapa = <String, LinkRef>{};
    json.forEach((chave, valor) {
      final link = LinkRef.doJson(valor);
      if (chave is String && link != null) mapa[chave] = link;
    });
    return Links(mapa);
  }

  LinkRef? operator [](String nome) => _mapa[nome];

  /// A pergunta que as telas fazem: *posso oferecer esta ação?*
  bool permite(String nome) => _mapa.containsKey(nome);

  bool get estaVazio => _mapa.isEmpty;

  Iterable<String> get acoes => _mapa.keys;

  @override
  String toString() => _mapa.keys.join(', ');
}
