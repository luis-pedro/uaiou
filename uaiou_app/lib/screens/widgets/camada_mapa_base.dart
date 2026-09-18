import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/mapa/repositorio_mapa.dart';
import 'package:uaiou/core/tema/cores.dart';

/// Fundo dos mapas 2D (`flutter_map`): tiles do Geoapify servidos pelo
/// backend, no mesmo tema claro/escuro do mapa de rota e do app.
///
/// Enquanto a camada não chega, o mapa fica sem fundo por um instante
/// em vez de piscar o OpenStreetMap e trocar. Se o backend não entregar
/// a camada, cai no OpenStreetMap — mapa simples é melhor que nenhum.
class CamadaMapaBase extends StatefulWidget {
  const CamadaMapaBase({super.key});

  @override
  State<CamadaMapaBase> createState() => _CamadaMapaBaseState();
}

class _CamadaMapaBaseState extends State<CamadaMapaBase> {
  static const _reserva = (
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    zoomMaximo: 19,
    atribuicao: '© OpenStreetMap contributors',
  );

  bool? _escuro;
  CamadaRaster? _camada;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final escuro = context.temaEscuro;
    if (escuro != _escuro) {
      _escuro = escuro;
      _carregar(escuro);
    }
  }

  Future<void> _carregar(bool escuro) async {
    CamadaRaster camada;
    try {
      camada = await context.read<RepositorioMapa>().camadaRaster(
        escuro: escuro,
      );
    } catch (_) {
      camada = _reserva;
    }
    if (!mounted || escuro != _escuro) return;
    setState(() => _camada = camada);
  }

  @override
  Widget build(BuildContext context) {
    final camada = _camada;
    if (camada == null) return const SizedBox.shrink();

    return Stack(
      children: [
        TileLayer(
          // A chave muda com o template: trocar de tema descarta os
          // tiles do tema anterior em vez de misturar os dois na tela.
          key: ValueKey(camada.urlTemplate),
          urlTemplate: camada.urlTemplate,
          maxNativeZoom: camada.zoomMaximo,
          retinaMode: RetinaMode.isHighDensity(context),
          userAgentPackageName: 'com.uaiou.app',
        ),
        // Exigência de licença dos tiles, não escolha de layout.
        SimpleAttributionWidget(
          source: Text(camada.atribuicao, style: const TextStyle(fontSize: 10)),
          backgroundColor: Colors.white.withValues(alpha: .8),
        ),
      ],
    );
  }
}
