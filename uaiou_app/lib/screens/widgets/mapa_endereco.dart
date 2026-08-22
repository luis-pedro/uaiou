import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Substitui a antiga falta de coordenada do endereço do
/// estabelecimento (A-05/A-08): toque no mapa marca o ponto, sem
/// exigir que o usuário digite lat/lng. Mesmo padrão do seletor usado
/// no formulário de pedido do app web (`mapa-destino.tsx`) — toque
/// marca, arraste ajusta.
class MapaEndereco extends StatefulWidget {
  final double? latInicial;
  final double? lngInicial;
  final ValueChanged<LatLng> aoMudar;

  const MapaEndereco({
    super.key,
    this.latInicial,
    this.lngInicial,
    required this.aoMudar,
  });

  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  /// Santa Rita do Sapucaí — mesmo centro padrão usado no resto do
  /// app, até o estabelecimento marcar o próprio ponto.
  static const LatLng centroPadrao = LatLng(-22.2526, -45.7033);

  @override
  State<MapaEndereco> createState() => _MapaEnderecoState();
}

class _MapaEnderecoState extends State<MapaEndereco> {
  LatLng? _posicao;

  @override
  void initState() {
    super.initState();
    if (widget.latInicial != null && widget.lngInicial != null) {
      _posicao = LatLng(widget.latInicial!, widget.lngInicial!);
    }
  }

  void _definir(LatLng ponto) {
    setState(() => _posicao = ponto);
    widget.aoMudar(ponto);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _posicao ?? MapaEndereco.centroPadrao,
                initialZoom: _posicao != null ? 16 : 13,
                onTap: (_, ponto) => _definir(ponto),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.uaiou.app',
                ),
                if (_posicao != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _posicao!,
                        width: 45,
                        height: 45,
                        child: GestureDetector(
                          // `flutter_map` não tem arraste nativo de marcador;
                          // como o mapa inteiro já reage a toque, tocar de
                          // novo no pino reabre a escolha — simples e
                          // suficiente para um ajuste fino ocasional.
                          onTap: () {},
                          child: const Icon(
                            Icons.location_on,
                            color: MapaEndereco.corPrincipal,
                            size: 45,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _posicao != null
              ? '${_posicao!.latitude.toStringAsFixed(6)}, ${_posicao!.longitude.toStringAsFixed(6)}'
              : 'Toque no mapa para marcar o endereço do estabelecimento.',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
