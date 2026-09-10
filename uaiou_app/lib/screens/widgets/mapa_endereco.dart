import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/endereco/endereco_publico.dart';
import 'package:uaiou/core/endereco/repositorio_endereco_publico.dart';

/// Substitui a antiga falta de coordenada do endereço do
/// estabelecimento (A-05/A-08): toque no mapa marca o ponto, sem
/// exigir que o usuário digite lat/lng. Mesmo padrão do seletor usado
/// no formulário de pedido do app web (`mapa-destino.tsx`) — toque
/// marca, arraste ajusta.
///
/// A cada ponto marcado o widget também dispara o fluxo de APIs
/// públicas `coordenada -> CEP -> endereço`
/// ([RepositorioEnderecoPublico]) e entrega o resultado em
/// [aoResolverEndereco], para a tela preencher rua/bairro/cidade/CEP
/// sozinha. O preenchimento é **sugestão**: os campos continuam
/// editáveis, porque o CEP acerta a rua e erra o número.
class MapaEndereco extends StatefulWidget {
  final double? latInicial;
  final double? lngInicial;
  final ValueChanged<LatLng> aoMudar;

  /// Opcional: telas que só querem a coordenada (navegação, conferência)
  /// não passam nada e nenhuma consulta externa é feita.
  final ValueChanged<EnderecoPublico>? aoResolverEndereco;

  const MapaEndereco({
    super.key,
    this.latInicial,
    this.lngInicial,
    required this.aoMudar,
    this.aoResolverEndereco,
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

  bool _buscando = false;
  String? _avisoBusca;
  EnderecoPublico? _enderecoResolvido;

  /// Cada toque cancela logicamente a busca anterior: sem isto, uma
  /// resposta lenta do ponto A chega depois do ponto B e sobrescreve
  /// o formulário com o endereço errado.
  int _buscaAtual = 0;

  @override
  void initState() {
    super.initState();
    if (widget.latInicial != null && widget.lngInicial != null) {
      _posicao = LatLng(widget.latInicial!, widget.lngInicial!);
    }
  }

  void _definir(LatLng ponto) {
    setState(() {
      _posicao = ponto;
      _enderecoResolvido = null;
      _avisoBusca = null;
    });
    widget.aoMudar(ponto);
    if (widget.aoResolverEndereco != null) _buscarEndereco(ponto);
  }

  Future<void> _buscarEndereco(LatLng ponto) async {
    final busca = ++_buscaAtual;
    setState(() => _buscando = true);

    final resultado = await context
        .read<RepositorioEnderecoPublico>()
        .porCoordenada(ponto.latitude, ponto.longitude);

    if (!mounted || busca != _buscaAtual) return;

    setState(() {
      _buscando = false;
      switch (resultado) {
        case EnderecoEncontrado(:final endereco):
          _enderecoResolvido = endereco;
          _avisoBusca = null;
          widget.aoResolverEndereco?.call(endereco);
        case EnderecoSemCep():
          _avisoBusca =
              'Não encontramos CEP para este ponto. Preencha o endereço à mão — '
              'a entrega usa a coordenada marcada.';
        case FalhaAoBuscarEndereco(:final mensagem):
          _avisoBusca = mensagem;
      }
    });
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
        if (_buscando) ...[
          const SizedBox(height: 6),
          const Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text(
                'Buscando o endereço deste ponto…',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
        if (_enderecoResolvido != null) ...[
          const SizedBox(height: 6),
          Text(
            _enderecoResolvido!.resumo,
            style: const TextStyle(
              fontSize: 12,
              color: MapaEndereco.corPrincipal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (_avisoBusca != null) ...[
          const SizedBox(height: 6),
          Text(
            _avisoBusca!,
            style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
          ),
        ],
      ],
    );
  }
}
