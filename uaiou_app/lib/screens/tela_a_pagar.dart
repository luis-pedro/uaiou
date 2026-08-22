import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/pagar/controlador_payables.dart';
import 'package:uaiou/core/pagar/modelo_payables.dart';
import 'package:uaiou/core/ganhos/modelo_ganhos.dart';
import 'package:uaiou/screens/widgets/visao_carregavel.dart';

/// ===============================================================
/// A PAGAR — RF-A10.9 (`GET /me/payables`)
/// ===============================================================
///
/// Espelho, do lado do estabelecimento, da tela de ganhos do
/// entregador (A-09): quanto se deve, agrupado por entregador. Só
/// leitura — a confirmação do acerto é do entregador, não daqui.
class TelaAPagar extends StatefulWidget {
  const TelaAPagar({super.key});

  @override
  State<TelaAPagar> createState() => _TelaAPagarState();
}

class _TelaAPagarState extends State<TelaAPagar> {
  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ControladorPayables>().carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controlador = context.watch<ControladorPayables>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
        title: const Text('A pagar'),
      ),
      body: RefreshIndicator(
        color: corPrincipal,
        onRefresh: controlador.recarregar,
        child: VisaoCarregavel<Payables>(
          estado: controlador.estado,
          aoTentarNovamente: controlador.carregar,
          textoVazio: 'Nada a pagar no momento',
          iconeVazio: Icons.payments_outlined,
          construir: (payables) => ListView(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: corPrincipal,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total a pagar',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    // RF-A10.10 — `total` vem pronto do servidor, nunca
                    // somado aqui.
                    Text(
                      payables.total.formatarBRL(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...payables.porEntregador.map(_buildEntregador),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntregador(APagarPorEntregador entregador) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        title: Text(
          entregador.courierName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(entregador.total.formatarBRL()),
        children: entregador.lancamentos
            .map(
              (l) => ListTile(
                dense: true,
                title: Text('Pedido ${l.orderNumber}'),
                trailing: Text(l.amount.formatarBRL()),
                subtitle: Text(
                  l.status == StatusLancamento.recebido
                      ? 'Acertado'
                      : 'A receber',
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
