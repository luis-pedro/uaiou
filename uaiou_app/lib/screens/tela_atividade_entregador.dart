import 'package:flutter/material.dart';

import 'package:uaiou/core/formato/data.dart';
import 'package:uaiou/core/tema/cores.dart';
import 'package:uaiou/screens/widgets/ui.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/estatisticas/controlador_estatisticas.dart';
import 'package:uaiou/core/estatisticas/modelo_estatisticas.dart';
import 'package:uaiou/core/pedidos/lista_de_pedidos.dart';
import 'package:uaiou/others/pedido.dart';
import 'package:uaiou/others/entregador_service.dart';
import 'package:uaiou/screens/widgets/badge_status.dart';
import 'package:uaiou/screens/widgets/visao_carregavel.dart';

/// Filtro selecionado na lista de entregas anteriores.
enum _FiltroAtividades { todos, entregues, cancelados }

class TelaAtividadesEntregador extends StatefulWidget {
  const TelaAtividadesEntregador({super.key});

  @override
  State<TelaAtividadesEntregador> createState() =>
      _TelaAtividadesEntregadorState();
}

class _TelaAtividadesEntregadorState extends State<TelaAtividadesEntregador> {
  /// Cor principal do aplicativo
  static const Color corPrincipal = CoresUaiou.principal;

  _FiltroAtividades _filtro = _FiltroAtividades.todos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EstadoEntregador>().carregar();
      // RF-A09.7 — contagens e taxas vêm de `GET /me/stats`; dinheiro
      // continua vindo só de `GET /me/earnings` (card da tela principal).
      context.read<ControladorEstatisticas>().carregar();
    });
  }

  /// O histórico vem de `GET /orders?status=finalized`; o filtro só
  /// recorta visualmente o que já está carregado.
  ListaDePedidos get _lista => context.read<EstadoEntregador>().concluidas;

  /// Esta tela é o histórico: só entrega encerrada entra, em qualquer filtro.
  /// O que está em andamento vive na tela de Entregas.
  List<Pedido> _aplicarFiltro(List<Pedido> entregas) {
    final historico = entregas.where((e) => e.status.encerrado).toList();
    return switch (_filtro) {
      _FiltroAtividades.entregues =>
        historico.where((e) => e.status.concluido).toList(),
      _FiltroAtividades.cancelados =>
        historico.where((e) => e.status == StatusPedido.cancelado).toList(),
      _FiltroAtividades.todos => historico,
    };
  }

  @override
  Widget build(BuildContext context) {
    return PaginaAba(
      titulo: 'Atividade',
      subtitulo: 'Seu desempenho e histórico',
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
        _buildPainelEstatisticas(),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: TituloSecao('Histórico'),
        ),
        _buildFiltros(),
        const SizedBox(height: 8),
        Expanded(child: _buildListaEntregas()),
      ],
    );
  }

  /// ============================================================
  /// PAINEL DE ESTATÍSTICAS — RF-A09.7
  /// ============================================================
  ///
  /// `GET /me/stats` alimenta contagens e taxas. Números de dinheiro
  /// **não aparecem aqui** — vêm só de `GET /me/earnings`, no card da
  /// tela principal e no extrato, para não haver duas origens do
  /// mesmo valor.
  Widget _buildPainelEstatisticas() {
    final controlador = context.watch<ControladorEstatisticas>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: controlador.estado.quando(
        carregando: () => const SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
        pronto: (stats) => _buildCardsEstatisticas(stats),
        vazio: () => const SizedBox.shrink(),
        falhou: (_) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildCardsEstatisticas(EstatisticasEntregador stats) {
    return Cartao(
      preenchimento: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      filho: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _buildCardEstatistica(
                "Concluídas",
                "${stats.entregasConcluidas}",
              ),
            ),
            VerticalDivider(width: 1, color: context.cores.borda),
            Expanded(
              child: _buildCardEstatistica(
                "Sem ocorrência",
                _formatarPercentual(stats.taxaFinalizacaoLimpa),
              ),
            ),
            VerticalDivider(width: 1, color: context.cores.borda),
            Expanded(
              child: _buildCardEstatistica(
                "Contrapropostas",
                _formatarPercentual(stats.taxaSucessoContraoferta),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatarPercentual(double? taxa) =>
      taxa == null ? "—" : "${(taxa * 100).toStringAsFixed(0)}%";

  Widget _buildCardEstatistica(String rotulo, String valor) {
    return Column(
      children: [
        Text(
          valor,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: context.cores.texto,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          rotulo,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: context.cores.textoSuave),
        ),
      ],
    );
  }

  // O botão "Filtrar pedidos" saiu daqui: tinha seta, aparência de controle e
  // nenhum comportamento (era um TODO aberto). Controle que não faz nada gasta
  // o toque de quem está com pressa. Volta quando houver filtro de verdade.

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
  /// LISTA DE ENTREGAS
  /// ============================================================

  Widget _buildListaEntregas() {
    final lista = _lista;

    return ListenableBuilder(
      listenable: lista,
      builder: (context, _) => RefreshIndicator(
        color: corPrincipal,
        onRefresh: lista.recarregar,
        child: VisaoCarregavel<List<Pedido>>(
          estado: lista.estado,
          aoTentarNovamente: lista.carregar,
          textoVazio: "Nenhuma entrega encontrada",
          iconeVazio: Icons.local_shipping_outlined,
          construir: (todas) {
            final entregas = _aplicarFiltro(todas);
            if (entregas.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    "Nenhuma entrega neste filtro",
                    style: TextStyle(color: context.cores.textoSuave),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: entregas.length,
              itemBuilder: (context, index) =>
                  _buildCardEntrega(entregas[index]),
            );
          },
        ),
      ),
    );
  }

  /// ============================================================
  /// CARD DA ENTREGA
  /// ============================================================

  Widget _buildCardEntrega(Pedido entrega) {
    final cores = context.cores;
    final data = descreverData(entrega.criadoEm);
    final entregue = entrega.status != StatusPedido.cancelado;

    // Não há toque aqui: o entregador não tem tela de detalhe de entrega
    // encerrada, e um cartão tocável que não abre nada engana.
    return Cartao(
      margem: const EdgeInsets.only(bottom: 10),
      preenchimento: const EdgeInsets.all(14),
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
                  "Pedido ${entrega.rotuloCurto}",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cores.texto,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${entrega.rua}, ${entrega.numero} · ${entrega.bairro}",
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
              BadgeStatus(entrega.status),
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
