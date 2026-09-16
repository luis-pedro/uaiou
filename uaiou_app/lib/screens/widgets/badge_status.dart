import 'package:flutter/material.dart';

import 'package:uaiou/core/tema/cores.dart';

import 'package:uaiou/core/modelos/status_pedido.dart';

/// Selo de status do pedido.
///
/// Existia repetido em quatro telas, cada uma com o próprio `switch`
/// sobre [StatusPedido] — o que fazia todo estado novo do contrato
/// virar quatro erros de compilação e quatro chances de divergir.
/// Aqui a aparência de cada estado é decidida **num lugar só**.
class BadgeStatus extends StatelessWidget {
  final StatusPedido status;

  /// As telas de atividades mostram ícone; as de lista, não.
  final bool comIcone;

  const BadgeStatus(this.status, {super.key, this.comIcone = false});

  @override
  Widget build(BuildContext context) {
    final cor = _cor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (comIcone) ...[
            Icon(_icone, size: 16, color: cor),
            const SizedBox(width: 6),
          ],
          Text(
            status.rotulo,
            style: TextStyle(
              color: cor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // Recebe o contexto porque a cor de "desconhecido" vem do tema.
  Color _cor(BuildContext context) => switch (status) {
    StatusPedido.criado || StatusPedido.pendente => context.cores.atencao,
    StatusPedido.emNegociacao => context.cores.negociacao,
    StatusPedido.aceito => context.cores.informacao,
    StatusPedido.coletado => context.cores.coleta,
    StatusPedido.entregue ||
    StatusPedido.entregueContestavel => context.cores.positivo,
    StatusPedido.cancelado => context.cores.perigo,
    StatusPedido.desconhecido => context.cores.textoSuave,
  };

  IconData get _icone => switch (status) {
    StatusPedido.criado || StatusPedido.pendente => Icons.hourglass_bottom,
    StatusPedido.emNegociacao => Icons.swap_horiz,
    StatusPedido.aceito => Icons.check_circle_outline,
    StatusPedido.coletado => Icons.delivery_dining,
    StatusPedido.entregue ||
    StatusPedido.entregueContestavel => Icons.check_circle,
    StatusPedido.cancelado => Icons.info,
    StatusPedido.desconhecido => Icons.help_outline,
  };
}
