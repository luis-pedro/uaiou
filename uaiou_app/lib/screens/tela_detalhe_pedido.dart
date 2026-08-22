import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/pedidos/contraoferta.dart';
import 'package:uaiou/core/pedidos/controlador_detalhe_pedido.dart';
import 'package:uaiou/core/pedidos/repositorio_pedidos.dart';
import 'package:uaiou/others/pedido.dart';
import 'package:uaiou/screens/widgets/badge_status.dart';
import 'package:uaiou/screens/widgets/visao_carregavel.dart';

/// ===============================================================
/// DETALHE DO PEDIDO — RF-A10.6/RF-A10.7/RF-A10.8
/// ===============================================================
class TelaDetalhePedido extends StatefulWidget {
  final String pedidoId;

  const TelaDetalhePedido({super.key, required this.pedidoId});

  @override
  State<TelaDetalhePedido> createState() => _TelaDetalhePedidoState();
}

class _TelaDetalhePedidoState extends State<TelaDetalhePedido> {
  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  late final ControladorDetalhePedido _controlador;

  @override
  void initState() {
    super.initState();
    _controlador = ControladorDetalhePedido(
      context.read<RepositorioPedidos>(),
      pedidoId: widget.pedidoId,
    );
    _controlador.carregar();
    _controlador.addListener(_mostrarAviso);
  }

  @override
  void dispose() {
    _controlador.removeListener(_mostrarAviso);
    _controlador.dispose();
    super.dispose();
  }

  void _mostrarAviso() {
    final aviso = _controlador.aviso;
    if (aviso == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aviso)));
    _controlador.limparAviso();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
        title: const Text('Pedido'),
      ),
      body: ListenableBuilder(
        listenable: _controlador,
        builder: (context, _) => RefreshIndicator(
          onRefresh: _controlador.recarregar,
          color: corPrincipal,
          child: VisaoCarregavel<Pedido>(
            estado: _controlador.estado,
            aoTentarNovamente: _controlador.carregar,
            construir: _buildConteudo,
          ),
        ),
      ),
    );
  }

  Widget _buildConteudo(Pedido pedido) {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Row(
          children: [
            Text(
              'Pedido ${pedido.rotuloCurto}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            BadgeStatus(pedido.status, comIcone: true),
          ],
        ),
        const SizedBox(height: 18),

        _cartao(
          titulo: 'Frete',
          child: Text(
            pedido.valor.formatarBRL(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 14),

        _cartao(
          titulo: 'Endereço de entrega',
          child: Text(pedido.enderecoResumido),
        ),
        const SizedBox(height: 14),

        if (pedido.recebedorNome != null)
          _cartao(
            titulo: 'Recebedor',
            child: Text(
              [
                pedido.recebedorNome,
                if (pedido.recebedorTelefone != null) pedido.recebedorTelefone,
              ].join(' — '),
            ),
          ),
        const SizedBox(height: 14),

        if (pedido.nomeEntregador != null)
          _cartao(
            titulo: 'Entregador',
            child: Text(pedido.nomeEntregador!),
          ),

        // RF-A10.7 — código de entrega, grande e fácil de achar: é
        // consultado com o entregador esperando na porta.
        if (pedido.status == StatusPedido.aceito) ...[
          const SizedBox(height: 14),
          _buildCodigoEntrega(),
        ],

        // RF-A10.6 — decidir contraoferta recebida.
        if (_controlador.contraofertasPendentes.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Contraofertas recebidas',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ..._controlador.contraofertasPendentes.map(_buildContraoferta),
        ],
      ],
    );
  }

  Widget _cartao({required String titulo, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _buildCodigoEntrega() {
    final codigo = _controlador.codigo;

    if (codigo == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: corPrincipal.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Código de entrega',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            if (_controlador.erroCodigo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _controlador.erroCodigo!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ElevatedButton.icon(
              onPressed: _controlador.carregandoCodigo
                  ? null
                  : _controlador.carregarCodigo,
              icon: _controlador.carregandoCodigo
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.pin),
              label: const Text('Ver código de entrega'),
              style: ElevatedButton.styleFrom(
                backgroundColor: corPrincipal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // RNF equivalente ao RNF-A08.1 do lado do entregador: bem visível,
    // o entregador está esperando na porta.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: corPrincipal,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Código de entrega — repasse ao recebedor',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Text(
            codigo.codigo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContraoferta(Contraoferta contraoferta) {
    final decidindo = _controlador.decidindo(contraoferta.id);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contraoferta.nomeEntregador,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Propôs ${contraoferta.valorProposto.formatarBRL()}',
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: decidindo
                      ? null
                      : () => _controlador.decidir(contraoferta.id, aceitar: false),
                  child: const Text('Recusar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: decidindo
                      ? null
                      : () => _controlador.decidir(contraoferta.id, aceitar: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: corPrincipal,
                    foregroundColor: Colors.white,
                  ),
                  child: decidindo
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Aceitar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
