import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/feira/controlador_feira.dart';
import 'package:uaiou/core/feira/modelos_feira.dart';
import 'package:uaiou/core/sessao/controlador_sessao.dart';
import 'package:uaiou/core/tema/cores.dart';
import 'package:uaiou/screens/widgets/camada_mapa_base.dart';

/// ===============================================================
/// VITRINE DO MODO FEIRA — `docs/feira/01-fluxos.md`
/// ===============================================================
///
/// Mapa dos pontos em cima, lista de prêmios embaixo. **Sem rota**: o
/// evento acontece num salão só, então o mapa marca onde estão os
/// pontos e não traça caminho nem navega — a pessoa anda até lá e
/// pega.
class TelaFeiraPedidos extends StatefulWidget {
  const TelaFeiraPedidos({super.key});

  @override
  State<TelaFeiraPedidos> createState() => _TelaFeiraPedidosState();
}

class _TelaFeiraPedidosState extends State<TelaFeiraPedidos> {
  static const _centroPadrao = LatLng(-22.2526, -45.7033);

  @override
  void initState() {
    super.initState();
    // Depois do primeiro quadro: `carregarPedidos` notifica ouvintes, e
    // notificar durante o build é erro de framework.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ControladorFeira>().carregarPedidos();
    });
  }

  Future<void> _capturar(PedidoFeira pedido) async {
    final feira = context.read<ControladorFeira>();
    await feira.capturar(pedido.id);
    if (!mounted) return;

    final captura = feira.ultimaCaptura;
    if (captura != null) {
      feira.comprovanteExibido();
      await _mostrarComprovante(captura);
    }
  }

  /// O comprovante é a tela que o visitante mostra no balcão, então
  /// ocupa a tela inteira e não some sozinho.
  Future<void> _mostrarComprovante(CapturaFeira captura) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (contexto) => AlertDialog(
      icon: const Icon(Icons.celebration, size: 40),
      title: const Text('Você pegou!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            captura.recompensa,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Mostre esta tela no balcão do UaiOu para retirar.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final feira = context.watch<ControladorFeira>();
    final pedidos = feira.pedidos;
    final comPonto = pedidos.where((p) => p.lat != 0 || p.longitude != 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prêmios no salão'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: feira.carregando
                ? null
                : () => context.read<ControladorFeira>().carregarPedidos(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: () => context.read<ControladorSessao>().sair(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 260,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: comPonto.isEmpty
                    ? _centroPadrao
                    : LatLng(comPonto.first.lat, comPonto.first.longitude),
                initialZoom: 17,
              ),
              children: [
                const CamadaMapaBase(),
                MarkerLayer(
                  markers: [
                    for (final pedido in comPonto)
                      Marker(
                        point: LatLng(pedido.lat, pedido.longitude),
                        width: 40,
                        height: 40,
                        child: Icon(
                          pedido.capturado
                              ? Icons.check_circle
                              : Icons.card_giftcard,
                          size: 36,
                          color: pedido.capturado
                              ? context.cores.positivo
                              : const Color.fromRGBO(254, 98, 29, 1),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (feira.erro != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                feira.erro!,
                style: TextStyle(color: context.cores.perigo),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  context.read<ControladorFeira>().carregarPedidos(),
              child: pedidos.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('Nenhum prêmio disponível agora.')),
                      ],
                    )
                  : ListView.separated(
                      itemCount: pedidos.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, indice) => _LinhaPedido(
                        pedido: pedidos[indice],
                        capturando: feira.capturando == pedidos[indice].id,
                        aoCapturar: () => _capturar(pedidos[indice]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaPedido extends StatelessWidget {
  const _LinhaPedido({
    required this.pedido,
    required this.capturando,
    required this.aoCapturar,
  });

  final PedidoFeira pedido;
  final bool capturando;
  final VoidCallback aoCapturar;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        pedido.capturado ? Icons.check_circle : Icons.card_giftcard,
        color: pedido.capturado
            ? context.cores.positivo
            : const Color.fromRGBO(254, 98, 29, 1),
      ),
      title: Text(
        pedido.recompensa,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        pedido.capturado
            ? 'Você já pegou este'
            : pedido.encerrado
            ? 'Encerrado'
            : '${pedido.rotulo ?? 'Ponto no salão'} · restam ${pedido.restantes}',
      ),
      trailing: pedido.capturavel
          ? FilledButton(
              onPressed: capturando ? null : aoCapturar,
              child: Text(capturando ? '…' : 'Pegar'),
            )
          : null,
    );
  }
}
