import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/presenca/controlador_presenca.dart';
import 'package:uaiou/core/rotas/controlador_rota.dart';
import 'package:uaiou/core/rotas/modelo_rota.dart';
import 'package:uaiou/screens/widgets/mapa_rota.dart';

/// ===============================================================
/// NAVEGAÇÃO NO PRÓPRIO APP — A-14 (revisão de 2026-08-16)
/// ===============================================================
///
/// Substitui a entrega do ponto ao Waze/Google Maps: agora o trajeto é
/// percorrido dentro do app, com o traçado do Geoapify e as instruções
/// que ele já devolve em português.
///
/// **O que esta tela faz:** mapa que acompanha a posição, manobra atual
/// em destaque, distância até ela, distância restante e a lista de
/// passos seguintes.
///
/// **O que ela deliberadamente não faz** — e o dono aceitou ao pedir a
/// troca ("mesmo que fique um pouco pior"):
///
/// * **não fala** — sem voz, o entregador precisa olhar a tela;
/// * **não recalcula sozinho** ao errar a curva. Recalcular a cada
///   desvio significaria uma chamada ao provedor por desvio, sem teto,
///   e a cota é finita (RNF-A14.1). Errou o caminho: o botão
///   "Recalcular" refaz a rota a partir de onde ele está — decisão
///   dele, uma chamada, visível.
/// * **não conhece trânsito** — o provedor não oferece.
class TelaNavegacao extends StatelessWidget {
  final String pedidoId;

  const TelaNavegacao({super.key, required this.pedidoId});

  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  @override
  Widget build(BuildContext context) {
    final controlador = context.watch<ControladorRota>();
    final posicaoLida = context.watch<ControladorPresenca>().posicaoAtual;
    final rota = controlador.rota;
    final posicao = posicaoLida == null
        ? null
        : PontoGeo(posicaoLida.lat, posicaoLida.lng);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
        title: const Text('Navegação'),
        actions: [
          IconButton(
            tooltip: 'Recalcular a partir daqui',
            onPressed: controlador.estado.carregando
                ? null
                : controlador.recarregar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: rota == null || !rota.temTracado
          ? _semTracado(context, rota)
          : Stack(
              children: [
                Positioned.fill(
                  child: MapaRota(
                    rota: rota,
                    posicaoAtual: posicao == null
                        ? null
                        : LatLng(posicao.lat, posicao.lng),
                    preencher: true,
                    seguirDesdeOInicio: true,
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: _cartaoDaManobra(rota.trajeto, posicao),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _rodape(context, rota.trajeto, posicao),
                ),
              ],
            ),
    );
  }

  /// A manobra que vem a seguir, grande e com a distância até ela —
  /// RNF-A14.2: precisa ser lida de relance, com o capacete na cabeça.
  Widget _cartaoDaManobra(Trajeto trajeto, PontoGeo? posicao) {
    final passo = trajeto.proximoPassoDe(posicao);
    if (passo == null) return const SizedBox.shrink();

    final metros = trajeto.metrosAte(passo, posicao);

    return Material(
      color: corPrincipal,
      borderRadius: BorderRadius.circular(18),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.turn_slight_right, color: Colors.white, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (metros != null)
                    Text(
                      _distancia(metros),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    passo.instrucao,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rodape(BuildContext context, Trajeto trajeto, PontoGeo? posicao) {
    final restante = trajeto.metrosRestantes(posicao);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (restante != null)
                  Text(
                    'Faltam ${_distancia(restante)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const Spacer(),
                if (trajeto.duracaoMinutos != null)
                  Text(
                    '${trajeto.duracaoMinutos} min no total',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // RF-A14.2 — a tela mostra que a loja está no caminho, sem
            // afirmar que a encomenda já foi (ou não) apanhada: esse
            // estado não existe no contrato.
            Text(
              trajeto.passaPelaRetirada
                  ? 'Trajeto passando pelo estabelecimento antes da entrega.'
                  : 'Trajeto direto ao destino — o estabelecimento não marcou o ponto dele.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (trajeto.passos.length > 1) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _mostrarPassos(context, trajeto),
                icon: const Icon(Icons.list, size: 18),
                label: const Text('Ver todas as instruções'),
                style: TextButton.styleFrom(foregroundColor: corPrincipal),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _mostrarPassos(BuildContext context, Trajeto trajeto) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (contexto) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          itemCount: trajeto.passos.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, indice) {
            final passo = trajeto.passos[indice];
            return ListTile(
              leading: const Icon(Icons.arrow_forward),
              title: Text(passo.instrucao),
              subtitle: Text(_distancia(passo.distanciaMetros.toDouble())),
            );
          },
        ),
      ),
    );
  }

  Widget _semTracado(BuildContext context, RotaDoPedido? rota) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 44, color: Colors.grey.shade500),
            const SizedBox(height: 14),
            Text(
              rota?.trajeto.explicacao ?? 'Carregando o trajeto…',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text(
              'Você continua podendo entregar e finalizar normalmente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: context.read<ControladorRota>().recarregar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }

  String _distancia(double metros) => metros >= 1000
      ? '${(metros / 1000).toStringAsFixed(1)} km'
      : '${metros.round()} m';
}
