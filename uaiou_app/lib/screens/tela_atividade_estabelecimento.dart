import 'package:flutter/material.dart';

import 'package:uaiou/core/formato/data.dart';
import 'package:uaiou/core/tema/cores.dart';
import 'package:uaiou/screens/widgets/ui.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/pedidos/lista_de_pedidos.dart';
import 'package:uaiou/others/pedido.dart';
import 'package:uaiou/others/estabelecimento_service.dart';
import 'package:uaiou/screens/tela_a_pagar.dart';
import 'package:uaiou/screens/tela_detalhe_pedido.dart';
import 'package:uaiou/screens/widgets/badge_status.dart';
import 'package:uaiou/screens/widgets/visao_carregavel.dart';

/// Filtro selecionado na lista de pedidos.
enum _FiltroAtividades { todos, entregues, cancelados }

class TelaAtividadesEstabelecimento extends StatefulWidget {
  const TelaAtividadesEstabelecimento({super.key});

  @override
  State<TelaAtividadesEstabelecimento> createState() =>
      _TelaAtividadesEstabelecimentoState();
}

class _TelaAtividadesEstabelecimentoState
    extends State<TelaAtividadesEstabelecimento> {
  /// Cor principal do aplicativo
  static const Color corPrincipal = CoresUaiou.principal;

  _FiltroAtividades _filtro = _FiltroAtividades.todos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EstadoEstabelecimento>().carregar();
    });
  }

  ListaDePedidos get _lista => context.read<EstadoEstabelecimento>().pedidos;

  /// Esta tela é o histórico: só pedido encerrado entra, em qualquer filtro.
  /// O que está em andamento vive na tela de Pedidos.
  List<Pedido> _aplicarFiltro(List<Pedido> pedidos) {
    final historico = pedidos.where((p) => p.status.encerrado).toList();
    return switch (_filtro) {
      _FiltroAtividades.entregues =>
        historico.where((p) => p.status.concluido).toList(),
      _FiltroAtividades.cancelados =>
        historico.where((p) => p.status == StatusPedido.cancelado).toList(),
      _FiltroAtividades.todos => historico,
    };
  }

  @override
  Widget build(BuildContext context) {
    return PaginaAba(
      titulo: 'Atividade',
      subtitulo: 'Resumo e histórico',
      filho: _buildConteudo(),
    );
  }

  /// ============================================================
  /// CONTEÚDO PRINCIPAL
  /// ============================================================

  Widget _buildConteudo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        _buildCardFaturamento(),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: TituloSecao('Pedidos anteriores'),
        ),
        _buildFiltros(),
        const SizedBox(height: 8),
        Expanded(child: _buildListaPedidos()),
      ],
    );
  }

  /// ============================================================
  /// CARD DE FATURAMENTO
  /// ============================================================

  Widget _buildCardFaturamento() {
    // ⚠️ A-10 (RF-A10.10): o agregado vem de `GET /me/stats` e
    // `GET /me/payables` — nada de somar dinheiro no cliente.
    final estado = context.watch<EstadoEstabelecimento>();
    final faturamento = estado.faturamentoHoje;
    final cores = context.cores;
    final entregues = estado.concluidos.length;
    final cancelados = estado.cancelados.length;

    return Cartao(
      margem: const EdgeInsets.symmetric(horizontal: 16),
      preenchimento: EdgeInsets.zero,
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Row(
              children: [
                MedidorAnel(
                  principal: entregues,
                  secundario: cancelados,
                  rotuloCentro: 'pedidos',
                  tamanho: 132,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Faturamento hoje',
                        style: TextStyle(fontSize: 13, color: cores.textoSuave),
                      ),
                      Text(
                        faturamento?.formatarBRL() ?? '—',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: cores.texto,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildContador(
                        'Entregues',
                        entregues,
                        CoresUaiou.principal,
                      ),
                      const SizedBox(height: 6),
                      _buildContador(
                        'Cancelados',
                        cancelados,
                        CoresUaiou.principal.withValues(alpha: .3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cores.borda),
          _buildBotaoAPagar(),
        ],
      ),
    );
  }

  /// ============================================================
  /// BOTÃO "A PAGAR" — RF-A10.9
  /// ============================================================

  Widget _buildBotaoAPagar() {
    return LinhaOpcao(
      icone: Icons.payments_outlined,
      texto: "A pagar aos entregadores",
      aoTocar: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TelaAPagar()),
      ),
    );
  }

  /// ============================================================
  /// CONTADORES (Entregues / Cancelados)
  /// ============================================================

  Widget _buildContador(String titulo, int quantidade, Color cor) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            titulo,
            style: TextStyle(fontSize: 13, color: context.cores.textoSuave),
          ),
        ),
        Text(
          '$quantidade',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: context.cores.texto,
          ),
        ),
      ],
    );
  }

  /// ============================================================
  /// FILTROS (Todos / Entregues / Cancelados)
  /// ============================================================

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildChipFiltro("Todos", _FiltroAtividades.todos),
          const SizedBox(width: 8),
          _buildChipFiltro("Entregues", _FiltroAtividades.entregues),
          const SizedBox(width: 8),
          _buildChipFiltro("Cancelados", _FiltroAtividades.cancelados),
        ],
      ),
    );
  }

  Widget _buildChipFiltro(String texto, _FiltroAtividades valor) {
    final bool selecionado = _filtro == valor;
    final cores = context.cores;

    return Semantics(
      button: true,
      selected: selecionado,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _filtro = valor),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          // 10 de altura mantém o alvo mínimo de toque.
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selecionado ? CoresUaiou.principal : cores.superficie,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selecionado ? CoresUaiou.principal : cores.borda,
            ),
          ),
          child: Text(
            texto,
            style: TextStyle(
              color: selecionado ? Colors.white : cores.texto,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// ============================================================
  /// LISTA DE PEDIDOS
  /// ============================================================

  Widget _buildListaPedidos() {
    final lista = _lista;

    return ListenableBuilder(
      listenable: lista,
      builder: (context, _) => RefreshIndicator(
        color: corPrincipal,
        onRefresh: lista.recarregar,
        child: VisaoCarregavel<List<Pedido>>(
          estado: lista.estado,
          aoTentarNovamente: lista.carregar,
          textoVazio: "Nenhum pedido encontrado",
          iconeVazio: Icons.receipt_long_outlined,
          construir: (todos) {
            final pedidos = _aplicarFiltro(todos);
            if (pedidos.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    "Nenhum pedido neste filtro",
                    style: TextStyle(color: context.cores.textoSuave),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: pedidos.length,
              itemBuilder: (context, index) => _buildCardPedido(pedidos[index]),
            );
          },
        ),
      ),
    );
  }

  /// ============================================================
  /// CARD DO PEDIDO
  /// ============================================================

  Widget _buildCardPedido(Pedido pedido) {
    final cores = context.cores;
    final data = descreverData(pedido.criadoEm);
    final entregue = pedido.status != StatusPedido.cancelado;

    return Cartao(
      margem: const EdgeInsets.only(bottom: 10),
      preenchimento: const EdgeInsets.all(14),
      aoTocar: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TelaDetalhePedido(pedidoId: pedido.id),
        ),
      ),
      filho: Row(
        children: [
          IconeTingido(
            entregue ? Icons.check_rounded : Icons.close_rounded,
            cor: entregue ? cores.positivo : cores.perigo,
            tamanho: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Pedido ${pedido.rotuloCurto}",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cores.texto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${pedido.rua}, ${pedido.numero} · ${pedido.bairro}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: cores.textoSuave),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BadgeStatus(pedido.status),
              const SizedBox(height: 6),
              Text(
                data,
                style: TextStyle(fontSize: 12, color: cores.textoSuave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
