import 'dart:async';
import 'dart:convert';
import 'dart:math' show max, min;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:provider/provider.dart';

import 'package:uaiou/core/rotas/modelo_rota.dart';
import 'package:uaiou/core/rotas/repositorio_rotas.dart';
import 'package:uaiou/core/tema/cores.dart';

/// ===============================================================
/// TRAÇADO DO PEDIDO — RF-A14.1/RF-A14.2
/// ===============================================================
///
/// **Uma rota só** (revisão de 2026-08-16): sai de onde o entregador
/// está, passa pelo estabelecimento e termina no destino. Os
/// marcadores dizem o que é cada ponto; o traçado é contínuo porque a
/// viagem é uma só.
///
/// O mapa **não afirma se a encomenda já foi apanhada** — esse estado
/// não existe no contrato (`OrderStatus` vai de `accepted` direto a
/// `finalized`), e inferir por proximidade seria o app inventando um
/// estado que o sistema não tem.
///
/// **Mapa vetorial (MapLibre)**, servido pelo backend com cache — ao
/// contrário do seletor de endereço, que segue raster no
/// `flutter_map`. Vetorial é o que deixa a câmera inclinar: no modo
/// seguir em tela cheia, o mapa vira visão de GPS (inclinado e girado
/// na direção do movimento). O tema acompanha o do app; sem o estilo
/// do backend, cai num raster do OpenStreetMap para nunca ficar sem
/// mapa.
///
/// O modo "seguir" recentraliza o mapa a cada nova posição (A-06) e
/// desliga sozinho ao primeiro toque no mapa: mapa que teima em voltar
/// ao centro é mapa que não se deixa consultar.
class MapaRota extends StatefulWidget {
  final RotaDoPedido rota;

  /// Posição do entregador, quando conhecida (A-06). Só entra como
  /// marcador e como alvo do modo seguir — o traçado é sempre o que o
  /// servidor mandou (RF-A14.8: trajeto planejado, nunca rastro).
  final LatLng? posicaoAtual;

  final double altura;

  /// Quando presente, mostra o botão de tela cheia.
  final VoidCallback? aoExpandir;

  /// Modo "o mapa é a tela": ocupa todo o espaço que o pai der, e
  /// legenda e atribuição passam a flutuar por cima do mapa em vez de
  /// empurrá-lo para cima. É também o modo em que seguir inclina a
  /// câmera — no cartão pequeno, a visão de cima lê melhor.
  final bool preencher;

  /// Na tela de navegação o entregador está rodando: o mapa já nasce
  /// acompanhando a posição, em vez de exigir um toque para começar.
  final bool seguirDesdeOInicio;

  /// Quem está por cima do mapa (entrega em andamento) já mostra a
  /// manobra no alto; a legenda flutuante disputaria o mesmo espaço.
  final bool mostrarLegenda;

  /// Incrementar liga o modo seguir de fora — o botão "Navegar" da
  /// folha de entrega usa isto para centrar no entregador.
  final int pedidosDeSeguir;

  const MapaRota({
    super.key,
    required this.rota,
    this.posicaoAtual,
    this.altura = 260,
    this.aoExpandir,
    this.preencher = false,
    this.seguirDesdeOInicio = false,
    this.mostrarLegenda = true,
    this.pedidosDeSeguir = 0,
  });

  static const Color corRetirada = Color.fromRGBO(41, 98, 255, 1);
  static const Color corEntrega = Color.fromRGBO(254, 98, 29, 1);

  /// Santa Rita do Sapucaí — mesmo centro padrão do resto do app.
  static const LatLng centroPadrao = LatLng(-22.2526, -45.7033);

  /// Câmera do modo navegação: perto o bastante para ler a rua e
  /// inclinada o bastante para ver a próxima esquina.
  static const double zoomNavegacao = 17;
  static const double inclinacaoNavegacao = 60;

  @override
  State<MapaRota> createState() => _MapaRotaState();
}

class _MapaRotaState extends State<MapaRota> {
  static const _fonteRota = 'rota';
  static const _fontePontos = 'rota-pontos';
  static const _fontePosicao = 'rota-posicao';

  /// Abaixo disto o GPS oscila parado e o rumo calculado gira à toa.
  static const double _deslocamentoMinimoParaRumoMetros = 4;

  ml.MapLibreMapController? _mapa;
  late bool _seguindo = widget.seguirDesdeOInicio;
  bool _camadasProntas = false;

  bool? _estiloEscuro;
  String? _estilo;

  /// Direção do movimento, em graus a partir do norte. O `PosicaoLida`
  /// não traz rumo; ele sai de duas leituras seguidas.
  double _rumo = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final escuro = context.temaEscuro;
    if (escuro != _estiloEscuro) {
      _estiloEscuro = escuro;
      _carregarEstilo(escuro);
    }
  }

  Future<void> _carregarEstilo(bool escuro) async {
    String estilo;
    try {
      estilo = await context.read<RepositorioRotas>().estiloDoMapa(
        escuro: escuro,
      );
    } catch (_) {
      // Recurso desligado ou backend fora: melhor um mapa simples que
      // um quadro cinza no meio da entrega.
      estilo = _estiloDeReserva;
    }
    if (!mounted || escuro != _estiloEscuro) return;
    setState(() {
      _estilo = estilo;
      // Troca de estilo apaga as camadas próprias; o callback de estilo
      // carregado as recria.
      _camadasProntas = false;
    });
  }

  @override
  void didUpdateWidget(MapaRota anterior) {
    super.didUpdateWidget(anterior);
    final posicao = widget.posicaoAtual;
    final anteriorPos = anterior.posicaoAtual;

    if (posicao != null && anteriorPos != null && posicao != anteriorPos) {
      final metros = const Distance().as(
        LengthUnit.Meter,
        anteriorPos,
        posicao,
      );
      if (metros >= _deslocamentoMinimoParaRumoMetros) {
        _rumo = const Distance().bearing(anteriorPos, posicao) % 360;
      }
    }

    if (!identical(widget.rota, anterior.rota)) unawaited(_desenharRota());
    if (posicao != anteriorPos) unawaited(_desenharPosicao());

    if (widget.pedidosDeSeguir != anterior.pedidosDeSeguir) {
      _seguindo = true;
      unawaited(_seguirPosicao(animar: true));
      return;
    }
    if (_seguindo && posicao != null && posicao != anteriorPos) {
      unawaited(_seguirPosicao(animar: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.preencher) {
      return Stack(
        children: [
          Positioned.fill(child: _buildMapa()),
          if (widget.mostrarLegenda)
            Positioned(
              top: 12,
              left: 12,
              right: 76,
              child: _legendaFlutuante(),
            ),
          if (widget.rota.atribuicao != null)
            Positioned(left: 12, bottom: 10, child: _atribuicaoFlutuante()),
          _buildControles(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: widget.altura,
            child: Stack(children: [_buildMapa(), _buildControles()]),
          ),
        ),
        const SizedBox(height: 10),
        _legenda(),
        // RF-A14.7/RNF-25.2 — condição de licença do provedor, não
        // escolha de layout: quando o servidor manda a atribuição, ela
        // aparece junto do mapa.
        if (widget.rota.atribuicao != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.rota.atribuicao!,
            style: TextStyle(fontSize: 11, color: context.cores.textoSuave),
          ),
        ],
      ],
    );
  }

  Widget _buildMapa() {
    final estilo = _estilo;
    if (estilo == null) {
      return ColoredBox(color: context.cores.superficieSuave);
    }
    final tracado = _tracado;
    final centro = tracado.isNotEmpty
        ? tracado.first
        : widget.posicaoAtual ?? MapaRota.centroPadrao;

    // Tocar o mapa é o entregador dizendo "quero olhar outro canto" — o
    // seguir sai de cena sem pedir confirmação. Os botões ficam fora
    // deste Listener, então tocá-los não conta.
    return Listener(
      onPointerDown: (_) {
        if (_seguindo) setState(() => _seguindo = false);
      },
      child: ml.MapLibreMap(
        styleString: estilo,
        initialCameraPosition: ml.CameraPosition(
          target: _paraMl(centro),
          zoom: tracado.isEmpty ? 13 : 15,
        ),
        onMapCreated: (controlador) => _mapa = controlador,
        onStyleLoadedCallback: _aoCarregarEstilo,
        compassEnabled: true,
        attributionButtonPosition: ml.AttributionButtonPosition.bottomRight,
      ),
    );
  }

  Future<void> _aoCarregarEstilo() async {
    final mapa = _mapa;
    if (mapa == null) return;

    await mapa.addGeoJsonSource(_fonteRota, _geoJsonRota());
    await mapa.addGeoJsonSource(_fontePontos, _geoJsonPontos());
    await mapa.addGeoJsonSource(_fontePosicao, _geoJsonPosicao());

    // Contorno branco por baixo do traço: sobre rua clara, uma linha
    // chapada some. É o mesmo recurso que qualquer app de mapa usa.
    await mapa.addLineLayer(
      _fonteRota,
      'rota-contorno',
      const ml.LineLayerProperties(
        lineColor: '#ffffff',
        lineWidth: 11,
        lineJoin: 'round',
        lineCap: 'round',
      ),
      enableInteraction: false,
    );
    await mapa.addLineLayer(
      _fonteRota,
      'rota-linha',
      ml.LineLayerProperties(
        lineColor: _hex(MapaRota.corEntrega),
        lineWidth: 7,
        lineJoin: 'round',
        lineCap: 'round',
      ),
      enableInteraction: false,
    );
    await mapa.addCircleLayer(
      _fontePontos,
      'rota-pontos',
      const ml.CircleLayerProperties(
        circleRadius: 9,
        circleColor: ['get', 'cor'],
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 3,
        circlePitchAlignment: 'map',
      ),
      enableInteraction: false,
    );
    await mapa.addCircleLayer(
      _fontePosicao,
      'rota-posicao',
      ml.CircleLayerProperties(
        circleRadius: 10,
        circleColor: _hex(MapaRota.corRetirada),
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 4,
        circlePitchAlignment: 'map',
      ),
      enableInteraction: false,
    );
    _camadasProntas = true;

    if (_seguindo && widget.posicaoAtual != null) {
      await _seguirPosicao(animar: false);
    } else {
      await _enquadrarTrajeto();
    }
  }

  Future<void> _desenharRota() async {
    final mapa = _mapa;
    if (mapa == null || !_camadasProntas) return;
    await mapa.setGeoJsonSource(_fonteRota, _geoJsonRota());
    await mapa.setGeoJsonSource(_fontePontos, _geoJsonPontos());
  }

  Future<void> _desenharPosicao() async {
    final mapa = _mapa;
    if (mapa == null || !_camadasProntas) return;
    await mapa.setGeoJsonSource(_fontePosicao, _geoJsonPosicao());
  }

  /// Enquadra o trajeto inteiro: o entregador precisa ver onde
  /// termina, não só onde começa.
  Future<void> _enquadrarTrajeto() async {
    final mapa = _mapa;
    final pontos = [..._tracado, ?widget.posicaoAtual];
    if (mapa == null || pontos.length < 2) return;

    final lats = pontos.map((p) => p.latitude);
    final lngs = pontos.map((p) => p.longitude);
    await mapa.moveCamera(
      ml.CameraUpdate.newLatLngBounds(
        ml.LatLngBounds(
          southwest: ml.LatLng(lats.reduce(min), lngs.reduce(min)),
          northeast: ml.LatLng(lats.reduce(max), lngs.reduce(max)),
        ),
        left: 36,
        top: 36,
        right: 36,
        bottom: 36,
      ),
    );
  }

  Future<void> _seguirPosicao({required bool animar}) async {
    final mapa = _mapa;
    final posicao = widget.posicaoAtual;
    if (mapa == null || posicao == null || !_camadasProntas) return;

    final navegando = widget.preencher;
    final atualizacao = ml.CameraUpdate.newCameraPosition(
      ml.CameraPosition(
        target: _paraMl(posicao),
        zoom: navegando ? MapaRota.zoomNavegacao : 16.5,
        tilt: navegando ? MapaRota.inclinacaoNavegacao : 0,
        bearing: navegando ? _rumo : 0,
      ),
    );
    if (animar) {
      await mapa.animateCamera(
        atualizacao,
        duration: const Duration(milliseconds: 900),
      );
    } else {
      await mapa.moveCamera(atualizacao);
    }
  }

  Widget _buildControles() {
    return Positioned(
      right: 10,
      // Em tela cheia o rodapé é da folha arrastável (entrega) ou da
      // barra de navegação (tela de trajeto); os controles sobem para
      // o alto direito, onde nada os cobre.
      top: widget.preencher ? 12 : null,
      bottom: widget.preencher ? null : 10,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.aoExpandir != null)
            _botao(Icons.open_in_full, 'Ampliar o mapa', widget.aoExpandir!),
          _botao(Icons.add, 'Aproximar', () => _zoom(ml.CameraUpdate.zoomIn())),
          _botao(
            Icons.remove,
            'Afastar',
            () => _zoom(ml.CameraUpdate.zoomOut()),
          ),
          if (widget.posicaoAtual != null)
            _botao(
              _seguindo ? Icons.gps_fixed : Icons.gps_not_fixed,
              _seguindo ? 'Parar de seguir' : 'Seguir minha posição',
              _alternarSeguir,
              destacado: _seguindo,
            ),
        ],
      ),
    );
  }

  /// RNF-A14.2 — alvo de 44px: uso de rua, uma mão, sol na tela.
  Widget _botao(
    IconData icone,
    String descricao,
    VoidCallback aoTocar, {
    bool destacado = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: destacado ? MapaRota.corEntrega : Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: aoTocar,
          child: Tooltip(
            message: descricao,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                icone,
                size: 22,
                // Fundo do botão é branco nos dois temas (fica sobre o mapa).
                color: destacado ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _zoom(ml.CameraUpdate passo) => unawaited(_mapa?.animateCamera(passo));

  void _alternarSeguir() {
    setState(() => _seguindo = !_seguindo);
    if (_seguindo) {
      unawaited(_seguirPosicao(animar: true));
    } else {
      // Sair do seguir devolve o mapa de cima e com o norte para cima:
      // é o jeito de consultar o trajeto inteiro.
      unawaited(
        _mapa?.animateCamera(
          ml.CameraUpdate.newCameraPosition(
            ml.CameraPosition(
              target:
                  _mapa!.cameraPosition?.target ??
                  _paraMl(MapaRota.centroPadrao),
              zoom: _mapa!.cameraPosition?.zoom ?? 15,
            ),
          ),
        ),
      );
    }
  }

  List<LatLng> get _tracado => widget.rota.trajeto.geometria
      .map((p) => LatLng(p.lat, p.lng))
      .toList(growable: false);

  Map<String, dynamic> _geoJsonRota() {
    final tracado = _tracado;
    return _colecao([
      if (tracado.length >= 2)
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'LineString',
            'coordinates': [for (final p in tracado) _coordenada(p)],
          },
        },
    ]);
  }

  /// Origem, loja (quando o trajeto passa por ela) e destino. A cor vai
  /// na propriedade do ponto; a camada lê com `['get', 'cor']`.
  Map<String, dynamic> _geoJsonPontos() {
    final tracado = _tracado;
    if (tracado.isEmpty) return _colecao(const []);

    return _colecao([
      _ponto(tracado.first, _hex(context.cores.textoSuave)),
      // O estabelecimento é o ponto onde o trajeto dobra — só existe
      // quando ele marcou a coordenada dele no mapa (RF-25.5).
      if (widget.rota.trajeto.passaPelaRetirada)
        _ponto(_pontoDaLoja(tracado), _hex(context.cores.texto)),
      _ponto(tracado.last, _hex(MapaRota.corEntrega)),
    ]);
  }

  Map<String, dynamic> _geoJsonPosicao() {
    final posicao = widget.posicaoAtual;
    return _colecao([if (posicao != null) _ponto(posicao, null)]);
  }

  /// O provedor emenda as duas metades da viagem numa geometria só; o
  /// ponto da loja é a junção. Sem um índice vindo do servidor, o meio
  /// do traçado é a melhor aproximação honesta — e ela erra pouco
  /// porque as duas metades costumam ter ordem de grandeza parecida
  /// numa praça pequena.
  LatLng _pontoDaLoja(List<LatLng> tracado) => tracado[tracado.length ~/ 2];

  static Map<String, dynamic> _colecao(List<Map<String, dynamic>> features) => {
    'type': 'FeatureCollection',
    'features': features,
  };

  static Map<String, dynamic> _ponto(LatLng ponto, String? cor) => {
    'type': 'Feature',
    'properties': {'cor': ?cor},
    'geometry': {'type': 'Point', 'coordinates': _coordenada(ponto)},
  };

  /// GeoJSON é longitude primeiro.
  static List<double> _coordenada(LatLng p) => [p.longitude, p.latitude];

  static ml.LatLng _paraMl(LatLng p) => ml.LatLng(p.latitude, p.longitude);

  static String _hex(Color cor) =>
      '#${(cor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// Mesma legenda de RF-A14.2, em cartão translúcido: no modo tela
  /// cheia não há margem branca onde escrever, e texto solto sobre
  /// mapa não se lê.
  Widget _legendaFlutuante() {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .93),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _legenda(),
      ),
    );
  }

  /// RF-A14.7 — a atribuição é condição de licença: acompanha o mapa
  /// também quando ele vira a tela inteira.
  Widget _atribuicaoFlutuante() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        widget.rota.atribuicao!,
        style: TextStyle(fontSize: 10, color: context.cores.texto),
      ),
    );
  }

  /// RF-A14.2 — a legenda descreve o trajeto, nunca ordena ("agora vá
  /// até..."): dizer qual etapa é a atual exigiria um estado de
  /// retirada que o contrato não tem.
  Widget _legenda() {
    final trajeto = widget.rota.trajeto;
    if (!trajeto.temTracado) return const SizedBox.shrink();

    return _itemLegenda(
      MapaRota.corEntrega,
      trajeto.passaPelaRetirada
          ? 'Pelo estabelecimento até a entrega'
          : 'Direto até a entrega',
      trajeto,
    );
  }

  Widget _itemLegenda(Color cor, String rotulo, Trajeto perna) {
    final detalhes = [
      if (perna.distanciaPorViaKm != null)
        '${perna.distanciaPorViaKm!.toStringAsFixed(1)} km por via',
      if (perna.duracaoMinutos != null) '${perna.duracaoMinutos} min',
    ].join(' · ');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 5,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          detalhes.isEmpty ? rotulo : '$rotulo — $detalhes',
          style: TextStyle(fontSize: 12, color: context.cores.texto),
        ),
      ],
    );
  }
}

/// Reserva quando o backend não entrega o estilo vetorial: raster do
/// OpenStreetMap, sem 3D. Serve para não deixar o entregador sem mapa,
/// não como caminho normal — a política de uso dos servidores do OSM
/// não comporta o tráfego de produção.
final String _estiloDeReserva = jsonEncode({
  'version': 8,
  'sources': {
    'osm': {
      'type': 'raster',
      'tiles': ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
      'tileSize': 256,
      'maxzoom': 19,
      'attribution': '© OpenStreetMap contributors',
    },
  },
  'layers': [
    {'id': 'osm', 'type': 'raster', 'source': 'osm'},
  ],
});
