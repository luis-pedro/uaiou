import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:uaiou/core/rotas/modelo_rota.dart';

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
/// O modo "seguir" recentraliza o mapa a cada nova posição (A-06) e
/// desliga sozinho ao primeiro arraste do dedo: mapa que teima em
/// voltar ao centro é mapa que não se deixa consultar.
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
  /// empurrá-lo para cima. É o desenho de qualquer app de mapa — o
  /// caminho é o conteúdo, o texto é sobreposição.
  final bool preencher;

  /// Na tela de navegação o entregador está rodando: o mapa já nasce
  /// acompanhando a posição, em vez de exigir um toque para começar.
  final bool seguirDesdeOInicio;

  const MapaRota({
    super.key,
    required this.rota,
    this.posicaoAtual,
    this.altura = 260,
    this.aoExpandir,
    this.preencher = false,
    this.seguirDesdeOInicio = false,
  });

  static const Color corRetirada = Color.fromRGBO(41, 98, 255, 1);
  static const Color corEntrega = Color.fromRGBO(254, 98, 29, 1);

  /// Santa Rita do Sapucaí — mesmo centro padrão do resto do app.
  static const LatLng centroPadrao = LatLng(-22.2526, -45.7033);

  @override
  State<MapaRota> createState() => _MapaRotaState();
}

class _MapaRotaState extends State<MapaRota> {
  final MapController _mapa = MapController();
  late bool _seguindo = widget.seguirDesdeOInicio;
  bool _pronto = false;

  @override
  void didUpdateWidget(MapaRota anterior) {
    super.didUpdateWidget(anterior);
    final posicao = widget.posicaoAtual;
    if (!_seguindo || posicao == null || posicao == anterior.posicaoAtual) {
      return;
    }
    // A câmera só existe depois do primeiro frame do mapa; antes disso
    // mover levanta exceção.
    if (!_pronto) return;
    _mapa.move(posicao, _mapa.camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final tracado = _paraLatLng(widget.rota.trajeto.geometria);
    final todos = <LatLng>[...tracado, ?widget.posicaoAtual];

    if (widget.preencher) {
      return Stack(
        children: [
          Positioned.fill(child: _buildMapa(todos, tracado)),
          Positioned(top: 12, left: 12, right: 76, child: _legendaFlutuante()),
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
            child: Stack(
              children: [
                _buildMapa(todos, tracado),
                _buildControles(),
              ],
            ),
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
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ],
    );
  }

  Widget _buildMapa(List<LatLng> todos, List<LatLng> tracado) {
    return FlutterMap(
      mapController: _mapa,
      options: MapOptions(
        initialCenter: todos.isNotEmpty ? todos.first : MapaRota.centroPadrao,
        initialZoom: todos.isEmpty ? 13 : 15,
        // Enquadra o trajeto inteiro: o entregador precisa ver onde
        // termina, não só onde começa.
        initialCameraFit: todos.length >= 2
            ? CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(todos),
                padding: const EdgeInsets.all(36),
              )
            : null,
        onMapReady: () => _pronto = true,
        // Arrastar o mapa é o entregador dizendo "quero olhar outro
        // canto" — o seguir sai de cena sem pedir confirmação.
        onPositionChanged: (_, temGesto) {
          if (temGesto && _seguindo) setState(() => _seguindo = false);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.uaiou.app',
        ),
        PolylineLayer(
          polylines: [
            if (tracado.length >= 2) _linha(tracado, MapaRota.corEntrega),
          ],
        ),
        MarkerLayer(markers: _marcadores(tracado)),
      ],
    );
  }

  /// Contorno branco por baixo do traço: sobre rua clara, uma linha
  /// chapada some. É o mesmo recurso que qualquer app de mapa usa.
  Polyline _linha(List<LatLng> pontos, Color cor) => Polyline(
    points: pontos,
    color: cor,
    strokeWidth: 7,
    borderColor: Colors.white,
    borderStrokeWidth: 2.5,
  );

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
            _botao(
              Icons.open_in_full,
              'Ampliar o mapa',
              widget.aoExpandir!,
            ),
          _botao(Icons.add, 'Aproximar', () => _zoom(1)),
          _botao(Icons.remove, 'Afastar', () => _zoom(-1)),
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
                color: destacado ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _zoom(double passo) {
    if (!_pronto) return;
    _mapa.move(_mapa.camera.center, _mapa.camera.zoom + passo);
  }

  void _alternarSeguir() {
    final posicao = widget.posicaoAtual;
    setState(() => _seguindo = !_seguindo);
    if (_seguindo && posicao != null && _pronto) {
      _mapa.move(posicao, 16.5);
    }
  }

  List<Marker> _marcadores(List<LatLng> tracado) {
    final marcadores = <Marker>[];
    final posicao = widget.posicaoAtual;

    if (posicao != null) {
      marcadores.add(_marcador(posicao, Icons.navigation, MapaRota.corRetirada));
    }
    if (tracado.isEmpty) return marcadores;

    marcadores.add(_marcador(tracado.first, Icons.trip_origin, Colors.black54));
    // O estabelecimento é o ponto onde o trajeto dobra — só existe
    // quando ele marcou a coordenada dele no mapa (RF-25.5).
    if (widget.rota.trajeto.passaPelaRetirada) {
      marcadores.add(_marcador(_pontoDaLoja(tracado), Icons.storefront, Colors.black87));
    }
    marcadores.add(_marcador(tracado.last, Icons.location_on, MapaRota.corEntrega));
    return marcadores;
  }

  /// O provedor emenda as duas metades da viagem numa geometria só; o
  /// ponto da loja é a junção. Sem um índice vindo do servidor, o meio
  /// do traçado é a melhor aproximação honesta — e ela erra pouco
  /// porque as duas metades costumam ter ordem de grandeza parecida
  /// numa praça pequena.
  LatLng _pontoDaLoja(List<LatLng> tracado) => tracado[tracado.length ~/ 2];

  Marker _marcador(LatLng ponto, IconData icone, Color cor) => Marker(
    point: ponto,
    width: 44,
    height: 44,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icone, color: cor, size: 26),
    ),
  );

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
        style: const TextStyle(fontSize: 10, color: Colors.black87),
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
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ],
    );
  }

  static List<LatLng> _paraLatLng(List<PontoGeo> pontos) =>
      pontos.map((p) => LatLng(p.lat, p.lng)).toList(growable: false);
}
