import 'package:flutter/material.dart';

import 'package:uaiou/others/pedido.dart';
import 'package:uaiou/others/estabelecimento_service.dart';

class TelaPedidosEstabelecimento extends StatefulWidget {
  const TelaPedidosEstabelecimento({super.key});

  @override
  State<TelaPedidosEstabelecimento> createState() =>
      _TelaPedidosEstabelecimentoState();
}

class _TelaPedidosEstabelecimentoState
    extends State<TelaPedidosEstabelecimento> {
  /// Página selecionada do menu
  int paginaAtual = 1;

  /// Cor principal do aplicativo
  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  /// Nome do restaurante e pedidos vêm do EstabelecimentoService,
  /// compartilhado com a Tela Principal e a tela de Login.
  final EstabelecimentoService _service = EstabelecimentoService.instance;

  String get nomeRestaurante => _service.nomeRestaurante;
  List<Pedido> get pedidos => _service.pedidos;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corPrincipal,
      body: SafeArea(
        child: Stack(
          children: [
            _buildConteudo(),
            _buildMenuInferior(),
          ],
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
          children: [
            const SizedBox(height: 25),
            _buildHeader(),
            const SizedBox(height: 20),
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
  /// CABEÇALHO
  /// ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nomeRestaurante.isEmpty ? "Meu restaurante" : nomeRestaurante,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Pedidos",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// LISTA DE PEDIDOS
  /// ============================================================

  Widget _buildListaPedidos() {
    if (pedidos.isEmpty) {
      return const Center(
        child: Text(
          "Nenhum pedido ainda",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15),
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
    Color corStatus;
    String textoStatus;

    switch (pedido.status) {
      case StatusPedido.pendente:
        corStatus = Colors.orange;
        textoStatus = "Pendente";
        break;

      case StatusPedido.aceito:
        corStatus = Colors.blue;
        textoStatus = "Aceito";
        break;

      case StatusPedido.entregue:
        corStatus = Colors.green;
        textoStatus = "Entregue";
        break;

      case StatusPedido.cancelado:
        corStatus = Colors.red;
        textoStatus = "Cancelado";
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.grey.shade400,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Linha superior
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: corStatus.withOpacity(.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  textoStatus,
                  style: TextStyle(
                    color: corStatus,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Text(
            "Bairro: ${pedido.bairro}",
            style: const TextStyle(fontSize: 14),
          ),

          const SizedBox(height: 5),

          Text(
            "Rua: ${pedido.rua}",
            style: const TextStyle(fontSize: 14),
          ),

          const SizedBox(height: 5),

          Text(
            "Número: ${pedido.numero}",
            style: const TextStyle(fontSize: 14),
          ),

          const SizedBox(height: 18),

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
        break;

      case 2:
        Navigator.pushReplacementNamed(
          context,
          '/atividades_estabelecimento',
        );
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