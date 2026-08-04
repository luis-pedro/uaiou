import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:uaiou/others/entregador_service.dart';

class TelaPrincipalEntregador extends StatefulWidget {
  const TelaPrincipalEntregador({super.key});

  @override
  State<TelaPrincipalEntregador> createState() =>
      _TelaPrincipalEntregadorState();
}

class _TelaPrincipalEntregadorState extends State<TelaPrincipalEntregador> {
  int paginaAtual = 0;

  // Cor principal do app (laranja)
  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  // Dados do entregador, compartilhados via EntregadorService
  final EntregadorService _service = EntregadorService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMapa(),
          _buildAvaliacao(),
          _buildStatusDisponibilidade(),
          _buildCardGanhos(),
          _buildMenuInferior(),
        ],
      ),
    );
  }

  // MAPA
  Widget _buildMapa() {
    return Positioned.fill(
      child: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(-22.2526, -45.7033), // Santa Rita do Sapucaí
          initialZoom: 15,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.uaiou.app',
          ),

          //MarkerLayer(
          //markers: [
          //Marker(
          //point: const LatLng(-22.2526, -45.7033),
          //width: 45,
          //height: 45,
          //child: const Icon(
          //Icons.location_on,
          //color: Color.fromRGBO(254, 98, 29, 1),
          //size: 45,
          //),
          //),
          //],
          //),
        ],
      ),
    );
  }

  // AVALIAÇÃO (canto superior esquerdo)
  Widget _buildAvaliacao() {
    return Positioned(
      top: 40,
      left: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: corPrincipal, size: 18),
            const SizedBox(width: 6),
            Text(
              _service.avaliacao.toStringAsFixed(1).replaceAll('.', ','),
              style: const TextStyle(
                color: Color.fromRGBO(94, 94, 94, 1),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // STATUS DE DISPONIBILIDADE (canto superior direito, tocável)
  Widget _buildStatusDisponibilidade() {
    final bool disponivel = _service.disponivel;

    final Color corTexto = disponivel
        ? const Color.fromRGBO(108, 201, 80, 1)
        : Colors.grey.shade300;

    final Color corFundo = disponivel
        ? const Color.fromRGBO(17, 76, 0, 0.73)
        : Colors.black.withOpacity(0.55);

    final Color corBorda =
        disponivel ? const Color.fromRGBO(108, 201, 80, 1) : Colors.grey;

    return Positioned(
      top: 40,
      right: 20,
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: () {
          // Alterna a disponibilidade do entregador.
          // Futuramente, essa mudança também deve avisar o backend.
          setState(() {
            _service.disponivel = !_service.disponivel;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: corFundo,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: corBorda, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: corTexto,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                disponivel ? "Disponível" : "Indisponível",
                style: TextStyle(color: corTexto, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // CARD "GANHOS DE HOJE"
  Widget _buildCardGanhos() {
    return Positioned(
      top: 95,
      left: 15,
      right: 15,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Ganhos de Hoje",
              style: TextStyle(
                color: Color.fromRGBO(94, 94, 94, 1),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "R\$${_service.ganhosHoje.toStringAsFixed(2).replaceAll('.', ',')}",
                  style: const TextStyle(
                    color: Color.fromRGBO(34, 34, 34, 1),
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  "${_service.entregasHoje} entregas",
                  style: const TextStyle(
                    color: Color.fromRGBO(94, 94, 94, 1),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
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
        break;

      case 1:
        Navigator.pushReplacementNamed(context, '/entregas_entregador');
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