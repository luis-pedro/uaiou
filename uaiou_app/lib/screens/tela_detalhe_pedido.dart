import 'package:flutter/material.dart';

import 'package:uaiou/core/tema/cores.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/pedidos/contraoferta.dart';
import 'package:uaiou/core/pedidos/controlador_detalhe_pedido.dart';
import 'package:uaiou/core/pedidos/motivos.dart';
import 'package:uaiou/screens/widgets/avatar_rede.dart';
import 'package:uaiou/screens/widgets/aviso_flutuante.dart';
import 'package:uaiou/screens/widgets/dialogo_motivo.dart';
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
  static const Color corPrincipal = CoresUaiou.principal;

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
    mostrarAviso(context, aviso);
    _controlador.limparAviso();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewPaddingOf(context).bottom,
      ),
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
            child: Text(
              [
                pedido.nomeEntregador!,
                if (pedido.placaEntregador != null)
                  'placa ${pedido.placaEntregador}',
              ].join(' — '),
            ),
          ),

        // RF-A15.6 — sem coordenada da loja o servidor não detecta a
        // chegada; o estabelecimento precisa saber por que não é avisado.
        if (pedido.status == StatusPedido.aceito &&
            !pedido.localizacaoRetiradaConhecida) ...[
          const SizedBox(height: 14),
          _buildAvisoSemLocalizacao(),
        ],

        // RF-A15.1/RF-A15.2 — coleta confirmável aqui, não só no aviso.
        if (_controlador.podeConfirmarColeta) ...[
          const SizedBox(height: 14),
          _buildConfirmarColeta(pedido),
        ],

        // RF-A10.7 — código de entrega, grande e fácil de achar: é
        // consultado com o entregador esperando na porta.
        if (pedido.status == StatusPedido.aceito ||
            pedido.status == StatusPedido.coletado) ...[
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

        // RF-A15.4 — só quando o servidor oferece `cancellation`.
        if (_controlador.podeCancelar) ...[
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _controlador.executandoAcao
                  ? null
                  : () => _cancelar(pedido),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar pedido'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.cores.perigo,
                side: BorderSide(color: context.cores.perigo),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvisoSemLocalizacao() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cores.atencao.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cores.atencao),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off, color: context.cores.atencao),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Marque a localização do estabelecimento no perfil para ser '
              'avisado quando o entregador chegar.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmarColeta(Pedido pedido) {
    final chegou = pedido.entregadorAguardandoNaLoja;
    final entregador = [
      pedido.nomeEntregador ?? 'O entregador',
      if (pedido.placaEntregador != null) '(placa ${pedido.placaEntregador})',
    ].join(' ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cores.coleta.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cores.coleta, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarRede(
                url: pedido.fotoEntregador,
                icone: Icons.delivery_dining,
                raio: 28,
                corFundo: Colors.teal,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  chegou ? '$entregador chegou' : 'Coleta do pedido',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Entregue o pacote ao entregador e confirme a coleta.'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _controlador.executandoAcao
                  ? null
                  : _controlador.confirmarColeta,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Confirmar coleta'),
            ),
          ),
        ],
      ),
    );
  }

  /// RF-A15.5 — a taxa aparece antes da confirmação, com o valor vindo
  /// do servidor (`pendingCancellationFee`).
  Future<void> _cancelar(Pedido pedido) async {
    final taxa = pedido.taxaCancelamentoPendente;
    final escolha = await escolherMotivo<MotivoCancelamento>(
      context,
      titulo: 'Cancelar pedido ${pedido.rotuloCurto}',
      opcoes: MotivoCancelamento.values,
      rotulo: (m) => m.rotulo,
      exigeObservacao: (m) => m.exigeObservacao,
      textoConfirmar: 'Cancelar pedido',
      aviso: taxa == null
          ? null
          : 'O entregador já chegou. Cancelar agora gera taxa de '
                '${taxa.formatarBRL()} (50% do frete) a pagar a ele.',
    );
    if (escolha == null || !mounted) return;
    await _controlador.cancelar(escolha.motivo, observacao: escolha.observacao);
  }

  Widget _cartao({required String titulo, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cores.superficieSuave,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cores.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(fontSize: 13, color: context.cores.textoSuave),
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
            Text(
              'Código de entrega',
              style: TextStyle(fontSize: 13, color: context.cores.textoSuave),
            ),
            const SizedBox(height: 10),
            if (_controlador.erroCodigo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _controlador.erroCodigo!,
                  style: TextStyle(color: context.cores.perigo, fontSize: 13),
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
        color: context.cores.negociacao.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.cores.negociacao.withValues(alpha: .24),
        ),
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
                      : () => _controlador.decidir(
                          contraoferta.id,
                          aceitar: false,
                        ),
                  child: const Text('Recusar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: decidindo
                      ? null
                      : () => _controlador.decidir(
                          contraoferta.id,
                          aceitar: true,
                        ),
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
