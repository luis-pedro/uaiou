import 'dart:async';
import 'dart:convert';
import 'dart:math' show max, min;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:provider/provider.dart';

import 'package:uaiou/core/rotas/modelo_rota.dart';
import 'package:uaiou/core/mapa/repositorio_mapa.dart';
import 'package:uaiou/core/tema/cores.dart';
import 'package:uaiou/screens/widgets/marcadores_mapa.dart';

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

  /// Fixa, não do tema: o pino tem ícone branco e contorno branco, e
  /// precisa de fundo escuro nos dois temas do mapa.
  static const Color corLoja = Color.fromRGBO(38, 50, 56, 1);

  /// Santa Rita do Sapucaí — mesmo centro padrão do resto do app.
  static const LatLng centroPadrao = LatLng(-22.2526, -45.7033);

  /// Câmera do modo navegação: perto o bastante para ler a rua e
  /// inclinada o bastante para ver a próxima esquina.
  static const double zoomNavegacao = 17;
  static const double inclinacaoNavegacao = 60;

  @override
  State<MapaRota> createState() => _MapaRotaState();
}

class _MapaRotaState extends State<MapaRota>
    with SingleTickerProviderStateMixin {
  static const _fonteRota = 'rota';
  static const _fonteOrigem = 'rota-origem';
  static const _fontePinos = 'rota-pinos';
  static const _fontePosicao = 'rota-posicao';

  static const _iconePonteiro = 'uaiou-ponteiro';
  static const _iconeLoja = 'uaiou-loja';
  static const _iconeEntrega = 'uaiou-entrega';

  /// Abaixo disto o GPS oscila parado e o rumo calculado gira à toa.
  static const double _deslocamentoMinimoParaRumoMetros = 3;

  /// O deslize entre leituras dura o intervalo entre elas — o marcador
  /// chega no ponto novo quando a próxima leitura já está vindo, e o
  /// movimento parece contínuo. Os limites seguram leituras muito
  /// próximas (sem tempo de ver o deslize) ou muito espaçadas (deslize
  /// arrastado de um ponto velho).
  static const Duration _deslizeMinimo = Duration(milliseconds: 300);
  static const Duration _deslizeMaximo = Duration(milliseconds: 1500);

  /// Teto de quadros por segundo mandados ao mapa nativo. Cada quadro é
  /// uma chamada de plataforma; 30 é fluido e não engasga o canal.
  static const Duration _intervaloEntreQuadros = Duration(milliseconds: 33);

  ml.MapLibreMapController? _mapa;
  late bool _seguindo = widget.seguirDesdeOInicio;
  bool _camadasProntas = false;

  bool? _estiloEscuro;
  String? _estilo;

  /// Direção do movimento, em graus a partir do norte. O `PosicaoLida`
  /// não traz rumo; ele sai de duas leituras seguidas.
  double _rumo = 0;

  // Estado do deslize: de onde o marcador sai, para onde vai, e onde ele
  // está desenhado agora.
  late final AnimationController _deslize = AnimationController(vsync: this)
    ..addListener(_aoAvancarDeslize);
  LatLng? _origemDeslize;
  double _rumoOrigemDeslize = 0;
  LatLng? _exibida;
  double _rumoExibido = 0;
  DateTime? _ultimaLeitura;
  DateTime _ultimoQuadro = DateTime.fromMillisecondsSinceEpoch(0);
  bool _quadroEmVoo = false;

  @override
  void initState() {
    super.initState();
    _exibida = widget.posicaoAtual;
  }

  @override
  void dispose() {
    _deslize.dispose();
    super.dispose();
  }

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
      estilo = await context.read<RepositorioMapa>().estilo(escuro: escuro);
    } catch (_) {
      // Recurso desligado ou backend fora: melhor um mapa simples que
      // um quadro cinza no meio da entrega.
      estilo = _estiloDeReserva;
    }
    if (!mounted || escuro != _estiloEscuro) return;
    setState(() {
      _estilo = estilo;
      // Troca de estilo apaga ícones e camadas próprias; o callback de
      // estilo carregado os recria.
      _camadasProntas = false;
    });
  }

  @override
  void didUpdateWidget(MapaRota anterior) {
    super.didUpdateWidget(anterior);
    if (!identical(widget.rota, anterior.rota)) unawaited(_desenharRota());

    final posicao = widget.posicaoAtual;
    if (posicao != null && posicao != anterior.posicaoAtual) {
      _deslizarAte(posicao);
    }

    if (widget.pedidosDeSeguir != anterior.pedidosDeSeguir) {
      _seguindo = true;
      unawaited(_entrarNoSeguir());
    }
  }

  /// Nova leitura do GPS: o marcador (e a câmera, no modo seguir) sai de
  /// onde está desenhado e desliza até ela.
  void _deslizarAte(LatLng destino) {
    final exibida = _exibida;
    final agora = DateTime.now();
    final ultima = _ultimaLeitura;
    _ultimaLeitura = agora;

    if (exibida == null) {
      _exibida = destino;
      unawaited(_desenharQuadro(forcar: true));
      return;
    }

    final metros = const Distance().as(LengthUnit.Meter, exibida, destino);
    if (metros >= _deslocamentoMinimoParaRumoMetros) {
      _rumo = const Distance().bearing(exibida, destino) % 360;
    }

    final intervalo = ultima == null
        ? _deslizeMaximo
        : agora.difference(ultima);
    _origemDeslize = exibida;
    _rumoOrigemDeslize = _rumoExibido;
    _alvoDeslize = destino;
    _deslize
      ..duration = _limitar(intervalo)
      ..forward(from: 0);
  }

  LatLng? _alvoDeslize;

  static Duration _limitar(Duration intervalo) {
    if (intervalo < _deslizeMinimo) return _deslizeMinimo;
    if (intervalo > _deslizeMaximo) return _deslizeMaximo;
    return intervalo;
  }

  void _aoAvancarDeslize() {
    final origem = _origemDeslize;
    final alvo = _alvoDeslize;
    if (origem == null || alvo == null) return;

    // Linear de propósito: com leituras em sequência, qualquer curva de
    // aceleração vira um "anda-para-anda-para" a cada ponto.
    final t = _deslize.value;
    _exibida = LatLng(
      origem.latitude + (alvo.latitude - origem.latitude) * t,
      origem.longitude + (alvo.longitude - origem.longitude) * t,
    );
    _rumoExibido = _interpolarRumo(_rumoOrigemDeslize, _rumo, t);
    unawaited(_desenharQuadro(forcar: t >= 1));
  }

  /// Gira pelo caminho curto: de 350° para 10° são 20°, não 340°.
  static double _interpolarRumo(double de, double para, double t) {
    final diferenca = ((para - de + 540) % 360) - 180;
    return (de + diferenca * t) % 360;
  }

  /// Um quadro do deslize: move o marcador e, seguindo, a câmera junto —
  /// os dois pela mesma interpolação, para o ponteiro não "escorregar"
  /// para fora do centro.
  Future<void> _desenharQuadro({bool forcar = false}) async {
    final mapa = _mapa;
    final exibida = _exibida;
    if (mapa == null || exibida == null || !_camadasProntas) return;

    final agora = DateTime.now();
    if (!forcar &&
        (_quadroEmVoo ||
            agora.difference(_ultimoQuadro) < _intervaloEntreQuadros)) {
      return;
    }
    _quadroEmVoo = true;
    _ultimoQuadro = agora;
    try {
      await mapa.setGeoJsonSource(_fontePosicao, _geoJsonPosicao());
      if (_seguindo) await mapa.moveCamera(_cameraSeguindo(exibida));
    } finally {
      _quadroEmVoo = false;
    }
  }

  ml.CameraUpdate _cameraSeguindo(LatLng alvo) {
    final navegando = widget.preencher;
    return ml.CameraUpdate.newCameraPosition(
      ml.CameraPosition(
        target: _paraMl(alvo),
        // Respeita o zoom que o entregador escolheu nos botões.
        zoom:
            _mapa?.cameraPosition?.zoom ??
            (navegando ? MapaRota.zoomNavegacao : 16.5),
        tilt: navegando ? MapaRota.inclinacaoNavegacao : 0,
        bearing: navegando ? _rumoExibido : 0,
      ),
    );
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
        // Necessário para ler o zoom atual e mantê-lo no modo seguir.
        trackCameraPosition: true,
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
    final corOrigem = _hex(context.cores.textoSuave);

    await Future.wait([
      MarcadoresMapa.ponteiro(
        MapaRota.corRetirada,
      ).then((png) => mapa.addImage(_iconePonteiro, png)),
      MarcadoresMapa.pino(
        MapaRota.corLoja,
        Icons.storefront_rounded,
      ).then((png) => mapa.addImage(_iconeLoja, png)),
      MarcadoresMapa.pino(
        MapaRota.corEntrega,
        Icons.flag_rounded,
      ).then((png) => mapa.addImage(_iconeEntrega, png)),
    ]);
    if (!mounted) return;

    await mapa.addGeoJsonSource(_fonteRota, _geoJsonRota());
    await mapa.addGeoJsonSource(_fonteOrigem, _geoJsonOrigem());
    await mapa.addGeoJsonSource(_fontePinos, _geoJsonPinos());
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
    // A origem é só referência de onde o trajeto começou: ponto discreto,
    // deitado no mapa.
    await mapa.addCircleLayer(
      _fonteOrigem,
      'rota-origem',
      ml.CircleLayerProperties(
        circleRadius: 6,
        circleColor: corOrigem,
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 2.5,
        circlePitchAlignment: 'map',
      ),
      enableInteraction: false,
    );
    // Pinos em pé mesmo com a câmera inclinada — é o que os destaca dos
    // prédios em 3D.
    await mapa.addSymbolLayer(
      _fontePinos,
      'rota-pinos',
      const ml.SymbolLayerProperties(
        iconImage: ['get', 'icone'],
        iconSize: 1 / MarcadoresMapa.escala,
        iconAnchor: 'bottom',
        iconPitchAlignment: 'viewport',
        iconRotationAlignment: 'viewport',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
      enableInteraction: false,
    );
    // O ponteiro, ao contrário, deita no chão e gira com o rumo: é
    // assim que a seta aponta a rua certa com o mapa inclinado.
    await mapa.addSymbolLayer(
      _fontePosicao,
      'rota-posicao',
      const ml.SymbolLayerProperties(
        iconImage: _iconePonteiro,
        iconSize: 1 / MarcadoresMapa.escala,
        iconRotate: ['get', 'rumo'],
        iconRotationAlignment: 'map',
        iconPitchAlignment: 'map',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
      enableInteraction: false,
    );
    _camadasProntas = true;

    if (_seguindo && widget.posicaoAtual != null) {
      await _entrarNoSeguir(animar: false);
    } else {
      await _enquadrarTrajeto();
    }
  }

  Future<void> _desenharRota() async {
    final mapa = _mapa;
    if (mapa == null || !_camadasProntas) return;
    await mapa.setGeoJsonSource(_fonteRota, _geoJsonRota());
    await mapa.setGeoJsonSource(_fonteOrigem, _geoJsonOrigem());
    await mapa.setGeoJsonSource(_fontePinos, _geoJsonPinos());
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
        left: 48,
        top: 48,
        right: 48,
        bottom: 48,
      ),
    );
  }

  /// Leva a câmera ao entregador no enquadramento de navegação. Depois
  /// disso, quem move a câmera é o deslize, quadro a quadro.
  Future<void> _entrarNoSeguir({bool animar = true}) async {
    final mapa = _mapa;
    final alvo = _exibida ?? widget.posicaoAtual;
    if (mapa == null || alvo == null || !_camadasProntas) return;

    final navegando = widget.preencher;
    final camera = ml.CameraUpdate.newCameraPosition(
      ml.CameraPosition(
        target: _paraMl(alvo),
        zoom: navegando ? MapaRota.zoomNavegacao : 16.5,
        tilt: navegando ? MapaRota.inclinacaoNavegacao : 0,
        bearing: navegando ? _rumoExibido : 0,
      ),
    );
    if (animar) {
      await mapa.animateCamera(
        camera,
        duration: const Duration(milliseconds: 800),
      );
    } else {
      await mapa.moveCamera(camera);
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
              _seguindo ? Icons.navigation_rounded : Icons.navigation_outlined,
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
      unawaited(_entrarNoSeguir());
      return;
    }
    // Sair do seguir devolve o mapa de cima e com o norte para cima: é o
    // jeito de consultar o trajeto inteiro.
    final camera = _mapa?.cameraPosition;
    unawaited(
      _mapa?.animateCamera(
        ml.CameraUpdate.newCameraPosition(
          ml.CameraPosition(
            target: camera?.target ?? _paraMl(MapaRota.centroPadrao),
            zoom: camera?.zoom ?? 15,
          ),
        ),
      ),
    );
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

  Map<String, dynamic> _geoJsonOrigem() {
    final tracado = _tracado;
    return _colecao([if (tracado.isNotEmpty) _ponto(tracado.first, const {})]);
  }

  /// Loja (quando o trajeto passa por ela) e destino. O ícone vai na
  /// propriedade do ponto; a camada lê com `['get', 'icone']`.
  Map<String, dynamic> _geoJsonPinos() {
    final tracado = _tracado;
    if (tracado.isEmpty) return _colecao(const []);

    return _colecao([
      // O estabelecimento é o ponto onde o trajeto dobra — só existe
      // quando ele marcou a coordenada dele no mapa (RF-25.5).
      if (widget.rota.trajeto.passaPelaRetirada)
        _ponto(_pontoDaLoja(tracado), const {'icone': _iconeLoja}),
      _ponto(tracado.last, const {'icone': _iconeEntrega}),
    ]);
  }

  Map<String, dynamic> _geoJsonPosicao() {
    final exibida = _exibida;
    return _colecao([
      if (exibida != null) _ponto(exibida, {'rumo': _rumoExibido}),
    ]);
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

  static Map<String, dynamic> _ponto(
    LatLng ponto,
    Map<String, Object> propriedades,
  ) => {
    'type': 'Feature',
    'properties': propriedades,
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
