import 'package:flutter/material.dart';

import 'package:uaiou/others/pedido.dart';
import 'package:uaiou/others/entregador_service.dart';

class TelaEntregasEntregador extends StatefulWidget {
  const TelaEntregasEntregador({super.key});

  @override
  State<TelaEntregasEntregador> createState() =>
      _TelaEntregasEntregadorState();
}

class _TelaEntregasEntregadorState extends State<TelaEntregasEntregador> {
  /// Página selecionada do menu
  int paginaAtual = 1;

  /// Cor principal do aplicativo
  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  /// Entregas pendentes/concluídas vêm do EntregadorService,
  /// preenchido conforme pedidos são atribuídos ao entregador.
  final EntregadorService _service = EntregadorService.instance;

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
        "Entregas",
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
        child: _buildLista(),
      ),
    );
  }

  /// ============================================================
  /// LISTA (seções: pendentes / concluídas)
  /// ============================================================

  Widget _buildLista() {
    final pendentes = _service.entregasPendentes;
    final concluidas = _service.entregasConcluidas;

    if (pendentes.isEmpty && concluidas.isEmpty) {
      return const Center(
        child: Text(
          "Nenhuma entrega no momento",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 95),
      children: [
        _buildTituloSecao("Entregas pendentes"),
        const SizedBox(height: 10),

        if (pendentes.isEmpty)
          _buildSecaoVazia("Nenhuma entrega pendente")
        else
          ...pendentes.map(_buildCardEntrega),

        const SizedBox(height: 20),
        const Divider(color: Color.fromRGBO(94, 94, 94, 1), height: 1),
        const SizedBox(height: 20),

        _buildTituloSecao("Entregas concluídas"),
        const SizedBox(height: 10),

        if (concluidas.isEmpty)
          _buildSecaoVazia("Nenhuma entrega concluída ainda")
        else
          ...concluidas.map(_buildCardEntrega),
      ],
    );
  }

  Widget _buildTituloSecao(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color.fromRGBO(34, 34, 34, 1),
      ),
    );
  }

  Widget _buildSecaoVazia(String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 13, color: Colors.grey),
      ),
    );
  }

  /// ============================================================
  /// CARD DA ENTREGA
  /// ============================================================

  Widget _buildCardEntrega(Pedido entrega) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: const Color.fromRGBO(94, 94, 94, 1),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entrega.nomeEstabelecimento.isEmpty
                      ? "Pedido ${entrega.numeroPedido}"
                      : entrega.nomeEstabelecimento,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(34, 34, 34, 1),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildBadgeStatus(entrega.status),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            "Bairro: ${entrega.bairro}",
            style: const TextStyle(fontSize: 13, color: Color.fromRGBO(94, 94, 94, 1)),
          ),

          const SizedBox(height: 5),

          Row(
            children: [
              Text(
                "Rua: ${entrega.rua}",
                style: const TextStyle(fontSize: 13, color: Color.fromRGBO(94, 94, 94, 1)),
              ),
              const SizedBox(width: 20),
              Text(
                "Número: ${entrega.numero}",
                style: const TextStyle(fontSize: 13, color: Color.fromRGBO(94, 94, 94, 1)),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              if (entrega.tempoEstimadoMinutos != null) ...[
                _buildChipTempo(entrega.tempoEstimadoMinutos!),
                const Spacer(),
              ] else
                const Spacer(),
              InkWell(
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChipTempo(int minutos) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color.fromRGBO(94, 94, 94, 1)),
      ),
      child: Text(
        "$minutos min",
        style: const TextStyle(
          fontSize: 13,
          color: Color.fromRGBO(34, 34, 34, 1),
        ),
      ),
    );
  }

  Widget _buildBadgeStatus(StatusPedido status) {
    late final Color cor;
    late final String texto;

    switch (status) {
      case StatusPedido.pendente:
        cor = Colors.orange;
        texto = "Pendente...";
        break;

      case StatusPedido.aceito:
        cor = Colors.blue;
        texto = "Aceito";
        break;

      case StatusPedido.entregue:
        cor = Colors.green;
        texto = "Entregue";
        break;

      case StatusPedido.cancelado:
        cor = Colors.red;
        texto = "Cancelado";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withOpacity(.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: cor,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
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
        break;

      case 2:
        Navigator.pushReplacementNamed(context, '/atividades_entregador');
        break;

      case 3:
        Navigator.pushReplacementNamed(context, '/perfil_entregador');
        break;
    }
  }
}