import 'package:flutter/material.dart';

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
    final cor = _cor;

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

  Color get _cor => switch (status) {
    StatusPedido.criado || StatusPedido.pendente => Colors.orange,
    StatusPedido.emNegociacao => Colors.purple,
    StatusPedido.aceito => Colors.blue,
    StatusPedido.entregue || StatusPedido.entregueContestavel => Colors.green,
    StatusPedido.cancelado => Colors.red,
    StatusPedido.desconhecido => Colors.grey,
  };

  IconData get _icone => switch (status) {
    StatusPedido.criado || StatusPedido.pendente => Icons.hourglass_bottom,
    StatusPedido.emNegociacao => Icons.swap_horiz,
    StatusPedido.aceito => Icons.check_circle_outline,
    StatusPedido.entregue ||
    StatusPedido.entregueContestavel => Icons.check_circle,
    StatusPedido.cancelado => Icons.info,
    StatusPedido.desconhecido => Icons.help_outline,
  };
}
