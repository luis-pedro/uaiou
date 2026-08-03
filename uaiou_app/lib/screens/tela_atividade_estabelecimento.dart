import 'package:flutter/material.dart';

import 'package:uaiou/others/pedido.dart';
import 'package:uaiou/others/estabelecimento_service.dart';

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

  /// Fonte dos dados: nome do estabelecimento e pedidos, compartilhados
  /// com a Tela Principal e a Tela de Pedidos.
  final EstabelecimentoService _service = EstabelecimentoService.instance;

  _FiltroAtividades _filtro = _FiltroAtividades.todos;

  /// Lista de pedidos já respeitando o filtro selecionado.
  List<Pedido> get _pedidosFiltrados {
    switch (_filtro) {
      case _FiltroAtividades.entregues:
        return _service.pedidosEntregues;
      case _FiltroAtividades.cancelados:
        return _service.pedidosCancelados;
      case _FiltroAtividades.todos:
        return _service.pedidos;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corPrincipal,
      body: SafeArea(
        child: Stack(
          children: [
            _buildTitulo(),
            _buildConteudo(),
            _buildMenuInferior(),
          ],
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

            const SizedBox(height: 15),

            _buildContadores(),

            const SizedBox(height: 15),

            _buildFiltros(),

            const SizedBox(height: 10),

            const Divider(height: 1, color: Color.fromRGBO(217, 217, 217, 1)),

            Expanded(
              child: _buildListaPedidos(),
            ),

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
    // O faturamento vem do EstabelecimentoService: soma o valor de
    // todos os pedidos entregues hoje. Nada de valor fixo aqui —
    // quando o backend existir, é só o service buscar os pedidos reais.
    final faturamento = _service.faturamentoHoje;

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
              "R\$${faturamento.toStringAsFixed(2).replaceAll('.', ',')}",
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
  /// CONTADORES (Entregues / Cancelados)
  /// ============================================================

  Widget _buildContadores() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildContador(
            "Entregues",
            _service.pedidosEntregues.length,
          ),
          const Spacer(),
          _buildContador(
            "Cancelados",
            _service.pedidosCancelados.length,
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
    final pedidos = _pedidosFiltrados;

    if (pedidos.isEmpty) {
      return const Center(
        child: Text(
          "Nenhum pedido encontrado",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: pedidos.length,
      itemBuilder: (context, index) {
        return _buildCardPedido(pedidos[index]);
      },
    );
  }

  /// ============================================================
  /// CARD DO PEDIDO
  /// ============================================================

  Widget _buildCardPedido(Pedido pedido) {
    final data =
        "${pedido.data.day.toString().padLeft(2, '0')}/${pedido.data.month.toString().padLeft(2, '0')}/${pedido.data.year.toString().substring(2)}";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.grey.shade400,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Text(
                "Pedido ${pedido.numeroPedido}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _buildBadgeStatus(pedido.status),
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
              onTap: () {
                // TODO:
                // Abrir tela com informações completas do pedido.
              },
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

  Widget _buildBadgeStatus(StatusPedido status) {
    late final Color cor;
    late final String texto;
    late final IconData icone;

    switch (status) {
      case StatusPedido.entregue:
        cor = Colors.green;
        texto = "Entregue";
        icone = Icons.check_circle;
        break;

      case StatusPedido.cancelado:
        cor = Colors.grey;
        texto = "Cancelado";
        icone = Icons.info;
        break;

      case StatusPedido.aceito:
        cor = Colors.blue;
        texto = "Aceito";
        icone = Icons.check_circle_outline;
        break;

      case StatusPedido.pendente:
        cor = Colors.orange;
        texto = "Pendente";
        icone = Icons.hourglass_bottom;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withOpacity(.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: cor),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              color: cor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
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
              _buildItemMenu(
                index: 0,
                icone: Icons.home,
                texto: "Principal",
              ),
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
              _buildItemMenu(
                index: 3,
                icone: Icons.person,
                texto: "Perfil",
              ),
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
            Icon(
              icone,
              color: cor,
              size: 27,
            ),
            const SizedBox(height: 5),
            Text(
              texto,
              style: TextStyle(
                color: cor,
                fontSize: 12,
              ),
            ),
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
        Navigator.pushReplacementNamed(
          context,
          '/principal_estabelecimento',
        );
        break;

      case 1:
        Navigator.pushReplacementNamed(
          context,
          '/pedidos_estabelecimento',
        );
        break;

      case 2:
        break;

      case 3:
        Navigator.pushReplacementNamed(
          context,
          '/perfil_estabelecimento',
        );
        break;
    }
  }
}