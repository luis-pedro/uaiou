import 'package:flutter/material.dart';

import 'package:uaiou/core/tema/cores.dart';
import 'package:uaiou/screens/widgets/ui.dart';
import 'package:uaiou/screens/casca_principal.dart';
import 'package:uaiou/screens/tela_publicar_pedido.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/pedidos/lista_de_pedidos.dart';
import 'package:uaiou/others/pedido.dart';
import 'package:uaiou/others/estabelecimento_service.dart';
import 'package:uaiou/screens/tela_detalhe_pedido.dart';
import 'package:uaiou/screens/widgets/visao_carregavel.dart';

class TelaPedidosEstabelecimento extends StatefulWidget {
  const TelaPedidosEstabelecimento({super.key});

  @override
  State<TelaPedidosEstabelecimento> createState() =>
      _TelaPedidosEstabelecimentoState();
}

class _TelaPedidosEstabelecimentoState
    extends State<TelaPedidosEstabelecimento> {
  /// Cor principal do aplicativo
  static const Color corPrincipal = CoresUaiou.principal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EstadoEstabelecimento>().carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PaginaAba(
      titulo: 'Pedidos',
      subtitulo: 'Em andamento agora',
      filho: _buildConteudo(),
    );
  }

  /// ============================================================
  /// CONTEÚDO PRINCIPAL
  /// ============================================================

  Widget _buildConteudo() => _buildListaPedidos();

  /// ============================================================
  /// CABEÇALHO
  /// ============================================================

  /// ============================================================
  /// LISTA DE PEDIDOS
  /// ============================================================

  Widget _buildListaPedidos() {
    final lista = context.read<EstadoEstabelecimento>().pedidos;

    return ListenableBuilder(
      listenable: lista,
      builder: (context, _) => RefreshIndicator(
        // RF-A03.6
        color: corPrincipal,
        onRefresh: lista.recarregar,
        child: VisaoCarregavel<List<Pedido>>(
          estado: lista.estado,
          aoTentarNovamente: lista.carregar,
          textoVazio: "Nenhum pedido em andamento",
          iconeVazio: Icons.receipt_long_outlined,
          construirVazio: _buildVazio,
          // Entregues e cancelados saem daqui: esta tela é o que está
          // acontecendo agora. O histórico fica em Atividades.
          construir: (todos) => _buildLista(
            todos.where((pedido) => !pedido.status.encerrado).toList(),
            lista,
          ),
        ),
      ),
    );
  }

  Widget _buildLista(List<Pedido> pedidos, ListaDePedidos lista) {
    // Vazio aqui não é "nenhum pedido": é "nenhum em andamento". A página pode
    // estar cheia de entregas concluídas, e dizer o contrário confundiria.
    if (pedidos.isEmpty) return _buildVazio();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      // RF-A03.7 — a última linha vira o gatilho da próxima página, seguindo o
      // `_links.next` do servidor.
      itemCount: pedidos.length + (lista.temMais ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= pedidos.length) {
          if (!lista.carregandoMais) lista.carregarMais();
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(color: corPrincipal),
            ),
          );
        }
        return _buildCardPedido(pedidos[index]);
      },
    );
  }

  /// ============================================================
  /// CARD DO PEDIDO
  /// ============================================================

  Widget _buildVazio() {
    final cores = context.cores;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          'Nenhuma entrega rodando agora',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: cores.texto,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Quando você chamar um entregador, o pedido aparece aqui e '
          'avança sozinho por estas etapas:',
          style: TextStyle(fontSize: 14, color: cores.textoSuave),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 2; i++)
          _buildCartaoFantasma(opacidade: 1 - i * .45),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _chamarEntregador,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
          icon: const Icon(Icons.two_wheeler_rounded),
          label: const Text('Chamar entregador'),
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: () => CascaPrincipal.irPara(context, 2),
            child: const Text('Ver entregas finalizadas'),
          ),
        ),
      ],
    );
  }

  Future<void> _chamarEntregador() async {
    final publicado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TelaPublicarPedido()),
    );
    if (publicado == true && mounted) {
      context.read<EstadoEstabelecimento>().carregar();
    }
  }

  /// Esqueleto no formato exato do cartão real, com a trilha de etapas.
  Widget _buildCartaoFantasma({required double opacidade}) {
    final cores = context.cores;
    Widget barra(double largura) => Container(
      height: 10,
      width: largura,
      decoration: BoxDecoration(
        color: cores.superficieSuave,
        borderRadius: BorderRadius.circular(5),
      ),
    );
    return Opacity(
      opacity: opacidade,
      child: _CartaoComFaixa(
        margem: const EdgeInsets.only(bottom: 12),
        filho: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final icone in const [
              Icons.place_outlined,
              Icons.two_wheeler_rounded,
              Icons.person_outline_rounded,
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(icone, size: 18, color: cores.textoSuave),
                    const SizedBox(width: 10),
                    barra(icone == Icons.place_outlined ? 180 : 110),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            const _TrilhaDeEtapas(etapa: 0),
          ],
        ),
      ),
    );
  }

  /// Etapa na trilha: publicado → aceito → chegou → coletado → entregue.
  int _etapa(Pedido pedido) => switch (pedido.status) {
    StatusPedido.aceito => pedido.chegouEm != null ? 2 : 1,
    StatusPedido.coletado => 3,
    StatusPedido.entregue || StatusPedido.entregueContestavel => 4,
    _ => 0,
  };

  Widget _buildCardPedido(Pedido pedido) {
    final cores = context.cores;
    void abrir() => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TelaDetalhePedido(pedidoId: pedido.id)),
    );

    Widget linha(IconData icone, String texto, {bool forte = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icone, size: 18, color: CoresUaiou.principal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: forte ? FontWeight.w700 : FontWeight.w500,
                color: forte ? cores.texto : cores.textoSuave,
              ),
            ),
          ),
        ],
      ),
    );

    return _CartaoComFaixa(
      margem: const EdgeInsets.only(bottom: 12),
      aoTocar: abrir,
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Pedido ${pedido.rotuloCurto}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: cores.texto,
                  ),
                ),
              ),
              Text(
                pedido.valor.formatarBRL(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: CoresUaiou.principal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          linha(Icons.place_outlined, pedido.enderecoResumido, forte: true),
          linha(
            Icons.two_wheeler_rounded,
            pedido.nomeEntregador?.isNotEmpty == true
                ? pedido.nomeEntregador!
                : pedido.status == StatusPedido.emNegociacao
                ? 'Entregador propôs outro valor'
                : 'Procurando entregador…',
          ),
          if (pedido.recebedorNome?.isNotEmpty == true)
            linha(Icons.person_outline_rounded, pedido.recebedorNome!),
          const SizedBox(height: 6),
          _TrilhaDeEtapas(etapa: _etapa(pedido)),
        ],
      ),
    );
  }
}

/// Cartão com a faixa laranja à esquerda — marca visual de "em andamento".
class _CartaoComFaixa extends StatelessWidget {
  const _CartaoComFaixa({
    required this.filho,
    this.aoTocar,
    this.margem = EdgeInsets.zero,
  });

  final Widget filho;
  final VoidCallback? aoTocar;
  final EdgeInsetsGeometry margem;

  @override
  Widget build(BuildContext context) {
    return Cartao(
      margem: margem,
      aoTocar: aoTocar,
      preenchimento: EdgeInsets.zero,
      filho: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: CoresUaiou.principal),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                child: filho,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trilha de cinco etapas do pedido; a atual e as anteriores em laranja.
class _TrilhaDeEtapas extends StatelessWidget {
  const _TrilhaDeEtapas({required this.etapa});

  final int etapa;

  static const _rotulos = [
    'Publicado',
    'Aceito',
    'Chegou',
    'Coletado',
    'Entregue',
  ];

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < _rotulos.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i <= etapa ? CoresUaiou.principal : cores.borda,
                  ),
                ),
              Container(
                width: i == etapa ? 12 : 8,
                height: i == etapa ? 12 : 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= etapa ? CoresUaiou.principal : cores.borda,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _rotulos[etapa],
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: CoresUaiou.principal,
          ),
        ),
      ],
    );
  }
}
