import 'dart:convert';

import '../rede/cliente_api.dart';
import '../rede/erros_api.dart';

/// Camada raster dos mapas 2D, como o backend entrega.
///
/// [urlTemplate] é absoluto e já traz `{z}/{x}/{y}{r}` e o token do dia.
typedef CamadaRaster = ({
  String urlTemplate,
  int zoomMaximo,
  String atribuicao,
});

/// `GET /map-tiles/...` — o mapa do app vem do backend, que guarda em
/// cache os tiles do Geoapify e nunca expõe a chave da conta.
///
/// Tudo aqui é guardado **pelo dia (UTC)**: o token embutido nas URLs
/// vale pelo dia, e reusar a mesma URL é o que faz o cache de tiles do
/// aparelho acertar entre uma abertura do mapa e outra.
///
/// Os métodos lançam [ErroApi] quando o recurso está desligado ou fora
/// do ar; quem desenha o mapa cai no OpenStreetMap de reserva.
class RepositorioMapa {
  final ClienteApi _api;

  final Map<bool, ({String valor, int dia})> _estilos = {};
  final Map<bool, ({CamadaRaster valor, int dia})> _camadas = {};

  RepositorioMapa(this._api);

  /// Estilo vetorial (MapLibre) do mapa de rota.
  Future<String> estilo({required bool escuro}) async {
    final guardado = _estilos[escuro];
    if (guardado != null && guardado.dia == _hoje()) return guardado.valor;

    final resposta = await _api.obter('/map-tiles/styles/${_tema(escuro)}');
    if (resposta is! Map) {
      throw const ErroInesperado(mensagem: 'Estilo de mapa fora do contrato.');
    }
    final json = jsonEncode(resposta);
    _estilos[escuro] = (valor: json, dia: _hoje());
    return json;
  }

  /// Camada raster dos mapas 2D (`flutter_map`).
  Future<CamadaRaster> camadaRaster({required bool escuro}) async {
    final guardado = _camadas[escuro];
    if (guardado != null && guardado.dia == _hoje()) return guardado.valor;

    final resposta = await _api.obter('/map-tiles/raster/${_tema(escuro)}');
    if (resposta is! Map ||
        resposta['urlTemplate'] is! String ||
        resposta['maxZoom'] is! num) {
      throw const ErroInesperado(mensagem: 'Camada de mapa fora do contrato.');
    }
    final camada = (
      urlTemplate: resposta['urlTemplate'] as String,
      zoomMaximo: (resposta['maxZoom'] as num).toInt(),
      atribuicao: resposta['attribution'] as String? ?? '',
    );
    _camadas[escuro] = (valor: camada, dia: _hoje());
    return camada;
  }

  static String _tema(bool escuro) => escuro ? 'dark' : 'light';

  static int _hoje() {
    final agora = DateTime.now().toUtc();
    return DateTime.utc(
      agora.year,
      agora.month,
      agora.day,
    ).millisecondsSinceEpoch;
  }
}
