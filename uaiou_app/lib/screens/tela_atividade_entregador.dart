import 'package:flutter/material.dart';

import 'package:uaiou/others/pedido.dart';
import 'package:uaiou/others/entregador_service.dart';

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
  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  /// Entregas anteriores vêm do EntregadorService, compartilhado com
  /// a Tela Principal e a Tela de Entregas.
  final EntregadorService _service = EntregadorService.instance;

  _FiltroAtividades _filtro = _FiltroAtividades.todos;

  /// Lista de entregas já respeitando o filtro selecionado.
  List<Pedido> get _entregasFiltradas {
    switch (_filtro) {
      case _FiltroAtividades.entregues:
        return _service.entregasConcluidas;
      case _FiltroAtividades.cancelados:
        return _service.entregasCanceladas;
      case _FiltroAtividades.todos:
        return _service.entregas;
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
                "Entregas anteriores",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 20),

            _buildBotaoFiltrarPedidos(),

            const SizedBox(height: 15),

            _buildFiltros(),

            const SizedBox(height: 10),

            const Divider(height: 1, color: Color.fromRGBO(217, 217, 217, 1)),

            Expanded(
              child: _buildListaEntregas(),
            ),

            const SizedBox(height: 95),
          ],
        ),
      ),
    );
  }

  /// ============================================================
  /// "FILTRAR PEDIDOS" — abre filtros mais avançados no futuro
  /// (ex: por data, por bairro). Por enquanto é só um indicador visual.
  /// ============================================================

  Widget _buildBotaoFiltrarPedidos() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: () {
          // TODO: abrir filtros avançados (ex: por data).
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: const Color.fromRGBO(94, 94, 94, 1),
              width: 1.5,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Filtrar pedidos",
                style: TextStyle(
                  fontSize: 15,
                  color: Color.fromRGBO(94, 94, 94, 1),
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: Color.fromRGBO(94, 94, 94, 1),
              ),
            ],
          ),
        ),
      ),
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
  /// LISTA DE ENTREGAS
  /// ============================================================

  Widget _buildListaEntregas() {
    final entregas = _entregasFiltradas;

    if (entregas.isEmpty) {
      return const Center(
        child: Text(
          "Nenhuma entrega encontrada",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: entregas.length,
      itemBuilder: (context, index) {
        return _buildCardEntrega(entregas[index]);
      },
    );
  }

  /// ============================================================
  /// CARD DA ENTREGA
  /// ============================================================

  Widget _buildCardEntrega(Pedido entrega) {
    final data =
        "${entrega.data.day.toString().padLeft(2, '0')}/${entrega.data.month.toString().padLeft(2, '0')}/${entrega.data.year.toString().substring(2)}";

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
                "Pedido ${entrega.numeroPedido}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _buildBadgeStatus(entrega.status),
            ],
          ),

          const SizedBox(height: 15),

          Text(
            "Bairro: ${entrega.bairro}",
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),

          const SizedBox(height: 5),

          Row(
            children: [
              Text(
                "Rua: ${entrega.rua}",
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(width: 20),
              Text(
                "Número: ${entrega.numero}",
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Center(
            child: InkWell(
              onTap: () {
                // TODO:
                // Abrir tela com informações completas da entrega.
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
                icone: Icons.local_shipping,
                texto: "Entregas",
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