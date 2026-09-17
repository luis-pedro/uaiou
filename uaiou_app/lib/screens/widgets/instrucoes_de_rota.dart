import 'package:flutter/material.dart';

import 'package:uaiou/core/rotas/modelo_rota.dart';
import 'package:uaiou/core/tema/cores.dart';

/// ===============================================================
/// INSTRUÇÕES DE ROTA — A-14
/// ===============================================================
///
/// Peças da navegação compartilhadas entre a tela de navegação e a de
/// entrega em andamento: a manobra seguinte, grande, e a lista de
/// passos. Uma forma só de mostrar a curva, esteja o entregador só
/// rodando ou já prestes a finalizar.

String formatarDistancia(double metros) => metros >= 1000
    ? '${(metros / 1000).toStringAsFixed(1)} km'
    : '${metros.round()} m';

/// A manobra que vem a seguir e a distância até ela — RNF-A14.2:
/// precisa ser lida de relance, com o capacete na cabeça.
class CartaoDaManobra extends StatelessWidget {
  final Trajeto trajeto;
  final PontoGeo? posicao;

  const CartaoDaManobra({super.key, required this.trajeto, this.posicao});

  @override
  Widget build(BuildContext context) {
    final passo = trajeto.proximoPassoDe(posicao);
    if (passo == null) return const SizedBox.shrink();

    final metros = trajeto.metrosAte(passo, posicao);

    return Material(
      color: CoresUaiou.principal,
      borderRadius: BorderRadius.circular(18),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(_iconeDa(passo.instrucao), color: Colors.white, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (metros != null)
                    Text(
                      formatarDistancia(metros),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    passo.instrucao,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// O provedor só manda texto; o ícone é uma leitura aproximada dele.
  static IconData _iconeDa(String instrucao) {
    final texto = instrucao.toLowerCase();
    if (texto.contains('retorno')) return Icons.u_turn_left;
    if (texto.contains('rotatória') || texto.contains('rotatoria')) {
      return Icons.roundabout_right;
    }
    if (texto.contains('esquerda')) return Icons.turn_left;
    if (texto.contains('direita')) return Icons.turn_right;
    if (texto.contains('chegou') || texto.contains('destino')) {
      return Icons.flag;
    }
    return Icons.straight;
  }
}

void mostrarPassosDaRota(BuildContext context, Trajeto trajeto) {
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
            subtitle: Text(formatarDistancia(passo.distanciaMetros.toDouble())),
          );
        },
      ),
    ),
  );
}
