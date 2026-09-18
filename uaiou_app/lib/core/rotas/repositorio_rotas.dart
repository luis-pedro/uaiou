import 'dart:convert';

import '../rede/cliente_api.dart';
import '../rede/erros_api.dart';
import 'modelo_rota.dart';

/// `GET /orders/{id}/route` — sub-recurso de rota do pedido (T-25).
///
/// Separado de [RepositorioPedidos] de propósito: a rota é a única
/// leitura do app que depende de um provedor externo, e manter a
/// fronteira visível é o que impede alguém amanhã embutir a chamada no
/// caminho da vitrine (RF-25.7).
class RepositorioRotas {
  final ClienteApi _api;

  /// Estilo por tema, guardado com o dia (UTC) em que foi buscado: o
  /// token embutido nas URLs de tile vale pelo dia, e reusar o mesmo
  /// estilo mantém a URL igual — que é o que faz o cache do MapLibre
  /// acertar entre uma abertura do mapa e outra.
  final Map<bool, ({String json, int dia})> _estilos = {};

  RepositorioRotas(this._api);

  /// [origem] é a leitura de GPS do aparelho neste momento. Sem ela o
  /// servidor usa a última posição reportada, que pode estar velha.
  Future<RotaDoPedido> obter(String pedidoId, {PontoGeo? origem}) async {
    final resposta = await _api.obter(
      '/orders/$pedidoId/route',
      query: origem == null ? null : {'lat': origem.lat, 'lng': origem.lng},
    );
    if (resposta is! Map) {
      throw const ErroInesperado(
        mensagem: 'Resposta de rota fora do contrato.',
      );
    }
    return RotaDoPedido.doJson(Map<String, dynamic>.from(resposta));
  }

  /// `GET /map-tiles/styles/{light|dark}` — estilo vetorial do mapa de
  /// navegação, com tiles, fontes e sprites servidos pelo backend.
  ///
  /// Lança [ErroApi] quando o recurso está desligado ou fora do ar;
  /// quem desenha o mapa cai no estilo raster de reserva.
  Future<String> estiloDoMapa({required bool escuro}) async {
    final hoje = DateTime.now().toUtc();
    final dia = DateTime.utc(
      hoje.year,
      hoje.month,
      hoje.day,
    ).millisecondsSinceEpoch;
    final guardado = _estilos[escuro];
    if (guardado != null && guardado.dia == dia) return guardado.json;

    final resposta = await _api.obter(
      '/map-tiles/styles/${escuro ? 'dark' : 'light'}',
    );
    if (resposta is! Map) {
      throw const ErroInesperado(mensagem: 'Estilo de mapa fora do contrato.');
    }
    final json = jsonEncode(resposta);
    _estilos[escuro] = (json: json, dia: dia);
    return json;
  }
}
