import 'package:flutter/material.dart';
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
  /// Página selecionada do menu
  int paginaAtual = 2;

  /// Cor principal do aplicativo
  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  _FiltroAtividades _filtro = _FiltroAtividades.todos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EstadoEstabelecimento>().carregar();
    });
  }

  ListaDePedidos get _lista => context.read<EstadoEstabelecimento>().pedidos;

  List<Pedido> _aplicarFiltro(List<Pedido> pedidos) {
    return switch (_filtro) {
      _FiltroAtividades.entregues =>
        pedidos.where((p) => p.status.concluido).toList(),
      _FiltroAtividades.cancelados =>
        pedidos.where((p) => p.status == StatusPedido.cancelado).toList(),
      _FiltroAtividades.todos => pedidos,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corPrincipal,
      body: SafeArea(
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Pedidos anteriores",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 15),

            _buildCardFaturamento(),

            const SizedBox(height: 12),

            _buildBotaoAPagar(),

            const SizedBox(height: 15),

            _buildContadores(),

            const SizedBox(height: 15),

            _buildFiltros(),

            const SizedBox(height: 10),

            const Divider(height: 1, color: Color.fromRGBO(217, 217, 217, 1)),

            Expanded(child: _buildListaPedidos()),

            const SizedBox(height: 95),
          ],
        ),
      ),
    );
  }

  /// ============================================================
  /// CARD DE FATURAMENTO
  /// ============================================================

  Widget _buildCardFaturamento() {
    // ⚠️ A-10 (RF-A10.10): o agregado vem de `GET /me/stats` e
    // `GET /me/payables`. Somar dinheiro no cliente e inferir "hoje"
    // pelo relógio do aparelho eram as duas coisas que a task proíbe.
    final faturamento = context.watch<EstadoEstabelecimento>().faturamentoHoje;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: corPrincipal,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Faturamento de hoje",
              style: TextStyle(
                color: Color.fromRGBO(218, 218, 218, 1),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              faturamento?.formatarBRL() ?? "—",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ============================================================
  /// BOTÃO "A PAGAR" — RF-A10.9
  /// ============================================================

  Widget _buildBotaoAPagar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TelaAPagar()),
        ),
        icon: const Icon(Icons.payments_outlined, color: corPrincipal),
        label: const Text(
          "A pagar aos entregadores",
          style: TextStyle(color: corPrincipal, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: corPrincipal),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  /// ============================================================
  /// CONTADORES (Entregues / Cancelados)
  /// ============================================================

  Widget _buildContadores() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildContador(
            "Entregues",
            context.watch<EstadoEstabelecimento>().concluidos.length,
          ),
          const Spacer(),
          _buildContador(
            "Cancelados",
            context.watch<EstadoEstabelecimento>().cancelados.length,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildContador(String titulo, int quantidade) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Text(
          "$quantidade",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado ? corPrincipal : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: selecionado ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w500,
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
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    "Nenhum pedido neste filtro",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
    final data =
        "${pedido.criadoEm.day.toString().padLeft(2, '0')}/${pedido.criadoEm.month.toString().padLeft(2, '0')}/${pedido.criadoEm.year.toString().substring(2)}";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data, style: const TextStyle(fontSize: 12, color: Colors.grey)),

          const SizedBox(height: 8),

          Row(
            children: [
              Text(
                "Pedido ${pedido.rotuloCurto}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              BadgeStatus(pedido.status, comIcone: true),
            ],
          ),

          const SizedBox(height: 15),

          Text(
            "Bairro: ${pedido.bairro}",
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),

          const SizedBox(height: 5),

          Row(
            children: [
              Text(
                "Rua: ${pedido.rua}",
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(width: 20),
              Text(
                "Número: ${pedido.numero}",
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Center(
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TelaDetalhePedido(pedidoId: pedido.id),
                ),
              ),
              child: const Text(
                "Visualizar pedido",
                style: TextStyle(
                  color: corPrincipal,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
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
        height: 85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
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
                icone: Icons.shopping_bag,
                texto: "Pedidos",
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

    final Color cor = selecionado ? corPrincipal : Colors.grey;

    return InkWell(
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
        Navigator.pushReplacementNamed(context, '/principal_estabelecimento');
        break;

      case 1:
        Navigator.pushReplacementNamed(context, '/pedidos_estabelecimento');
        break;

      case 2:
        break;

      case 3:
        Navigator.pushReplacementNamed(context, '/perfil_estabelecimento');
        break;
    }
  }
}
