import 'package:flutter/material.dart';

import 'package:uaiou/core/formato/data.dart';
import 'package:uaiou/core/tema/cores.dart';
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
  /// Página selecionada do menu
  int paginaAtual = 2;

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
    return Scaffold(
      backgroundColor: corPrincipal,
      // O recuo da barra do sistema é aplicado pelo menu inferior.
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [_buildTitulo(), _buildConteudo(), _buildMenuInferior()],
        ),
      ),
    );
  }

  // TÍTULO
  Widget _buildTitulo() {
    return const Positioned(
      top: 15,
      left: 25,
      child: Text(
        "Atividades",
        style: TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// ============================================================
  /// CONTEÚDO PRINCIPAL
  /// ============================================================

  Widget _buildConteudo() {
    return Positioned.fill(
      child: Container(
        margin: const EdgeInsets.only(top: 70),
        decoration: BoxDecoration(
          color: context.cores.superficie,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            _buildPainelEstatisticas(),

            const SizedBox(height: 20),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Entregas anteriores",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.cores.texto,
                ),
              ),
            ),

            const SizedBox(height: 20),

            _buildFiltros(),

            const SizedBox(height: 10),

            Divider(height: 1, color: context.cores.borda),

            Expanded(child: _buildListaEntregas()),

            SizedBox(height: 95 + MediaQuery.viewPaddingOf(context).bottom),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
    return Row(
      children: [
        Expanded(
          child: _buildCardEstatistica(
            "Entregas concluídas",
            "${stats.entregasConcluidas}",
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildCardEstatistica(
            "Finalização limpa",
            _formatarPercentual(stats.taxaFinalizacaoLimpa),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildCardEstatistica(
            "Contrapropostas aceitas",
            _formatarPercentual(stats.taxaSucessoContraoferta),
          ),
        ),
      ],
    );
  }

  String _formatarPercentual(double? taxa) =>
      taxa == null ? "—" : "${(taxa * 100).toStringAsFixed(0)}%";

  Widget _buildCardEstatistica(String rotulo, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(254, 98, 29, 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            valor,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: corPrincipal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rotulo,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: context.cores.textoSuave),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildChipFiltro("Todos", _FiltroAtividades.todos),
          const SizedBox(width: 10),
          _buildChipFiltro("Entregues", _FiltroAtividades.entregues),
          const SizedBox(width: 10),
          _buildChipFiltro("Cancelados", _FiltroAtividades.cancelados),
        ],
      ),
    );
  }

  Widget _buildChipFiltro(String texto, _FiltroAtividades valor) {
    final bool selecionado = _filtro == valor;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _filtro = valor),
      child: Container(
        // 12 em vez de 8: com 8 o chip ficava abaixo do alvo mínimo de toque.
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selecionado ? corPrincipal : context.cores.superficieSuave,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: selecionado ? Colors.white : context.cores.texto,
            fontSize: 13,
            fontWeight: FontWeight.w500,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
    final data = descreverData(entrega.criadoEm);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cores.superficie,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: context.cores.borda, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data,
            style: TextStyle(fontSize: 12, color: context.cores.textoSuave),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Text(
                "Pedido ${entrega.rotuloCurto}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              BadgeStatus(entrega.status, comIcone: true),
            ],
          ),

          const SizedBox(height: 15),

          Text(
            "Bairro: ${entrega.bairro}",
            style: TextStyle(fontSize: 13, color: context.cores.textoSuave),
          ),

          const SizedBox(height: 5),

          Row(
            children: [
              Text(
                "Rua: ${entrega.rua}",
                style: TextStyle(fontSize: 13, color: context.cores.textoSuave),
              ),
              const SizedBox(width: 20),
              Text(
                "Número: ${entrega.numero}",
                style: TextStyle(fontSize: 13, color: context.cores.textoSuave),
              ),
            ],
          ),

          // Não há "Visualizar pedido" aqui: o entregador não tem tela de
          // detalhe de entrega encerrada, e o botão que existia não fazia nada
          // ao ser tocado. Botão morto engana mais que ausência de botão.
        ],
      ),
    );
  }

  /// ============================================================
  /// MENU INFERIOR
  /// ============================================================

  Widget _buildMenuInferior() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        width: double.infinity,
        height: 85 + MediaQuery.viewPaddingOf(context).bottom,
        decoration: BoxDecoration(
          color: context.cores.superficie,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
          boxShadow: [
            BoxShadow(
              color: context.cores.sombra,
              blurRadius: 15,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildItemMenu(index: 0, icone: Icons.home, texto: "Principal"),
              _buildItemMenu(
                index: 1,
                icone: Icons.local_shipping,
                texto: "Entregas",
              ),
              _buildItemMenu(
                index: 2,
                icone: Icons.list_alt,
                texto: "Atividades",
              ),
              _buildItemMenu(index: 3, icone: Icons.person, texto: "Perfil"),
            ],
          ),
        ),
      ),
    );
  }

  /// ============================================================
  /// ITEM DO MENU
  /// ============================================================

  Widget _buildItemMenu({
    required int index,
    required IconData icone,
    required String texto,
  }) {
    final bool selecionado = paginaAtual == index;

    final Color cor = selecionado ? corPrincipal : context.cores.textoSuave;

    // `selected` faz o leitor de tela anunciar qual aba está aberta; sem isso
    // os quatro itens soavam iguais.
    return Semantics(
      button: true,
      selected: selecionado,
      label: texto,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _onItemMenuTap(index),
        child: SizedBox(
          width: 85,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, color: cor, size: 27),
              const SizedBox(height: 5),
              Text(texto, style: TextStyle(color: cor, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  /// ============================================================
  /// NAVEGAÇÃO
  /// ============================================================

  void _onItemMenuTap(int index) {
    if (paginaAtual == index) return;

    setState(() {
      paginaAtual = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/principal_entregador');
        break;

      case 1:
        Navigator.pushReplacementNamed(context, '/entregas_entregador');
        break;

      case 2:
        break;

      case 3:
        Navigator.pushReplacementNamed(context, '/perfil_entregador');
        break;
    }
  }
}
