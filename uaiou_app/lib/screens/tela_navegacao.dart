import 'package:flutter/material.dart';

import 'package:uaiou/core/tema/cores.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/presenca/controlador_presenca.dart';
import 'package:uaiou/core/rotas/controlador_rota.dart';
import 'package:uaiou/core/rotas/modelo_rota.dart';
import 'package:uaiou/screens/widgets/instrucoes_de_rota.dart';
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
/// * **não recalcula a cada desvio** — durante a entrega, o
///   [ControladorRota.acompanhar] recalcula a partir do GPS quando o
///   entregador sai do traçado, no máximo uma vez a cada
///   [intervaloMinimoEntreRecalculos] (RNF-A14.1). O botão
///   "Recalcular" continua refazendo na hora, a partir de onde ele está.
/// * **não conhece trânsito** — o provedor não oferece.
class TelaNavegacao extends StatelessWidget {
  final String pedidoId;

  const TelaNavegacao({super.key, required this.pedidoId});

  static const Color corPrincipal = CoresUaiou.principal;

  @override
  Widget build(BuildContext context) {
    final controlador = context.watch<ControladorRota>();
    final posicaoLida = context.watch<ControladorPresenca>().posicaoAtual;
    final rota = controlador.rota;
    final posicao = posicaoLida == null
        ? null
        : PontoGeo(posicaoLida.lat, posicaoLida.lng);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
        title: const Text('Navegação'),
        actions: [
          IconButton(
            tooltip: 'Recalcular a partir daqui',
            onPressed: controlador.estado.carregando
                ? null
                : () => controlador.recarregar(origem: posicao),
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
                  child: CartaoDaManobra(
                    trajeto: rota.trajeto,
                    posicao: posicao,
                  ),
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

  Widget _rodape(BuildContext context, Trajeto trajeto, PontoGeo? posicao) {
    final restante = trajeto.metrosRestantes(posicao);

    return Material(
      color: context.cores.superficie,
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
                    'Faltam ${formatarDistancia(restante)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const Spacer(),
                if (trajeto.duracaoMinutos != null)
                  Text(
                    '${trajeto.duracaoMinutos} min no total',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.cores.textoSuave,
                    ),
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
              style: TextStyle(fontSize: 12, color: context.cores.textoSuave),
            ),
            if (trajeto.passos.length > 1) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => mostrarPassosDaRota(context, trajeto),
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

  Widget _semTracado(BuildContext context, RotaDoPedido? rota) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 44, color: context.cores.textoSuave),
            const SizedBox(height: 14),
            Text(
              rota?.trajeto.explicacao ?? 'Carregando o trajeto…',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Você continua podendo entregar e finalizar normalmente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.cores.textoSuave),
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
}
