import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TelaPrincipalEstabelecimento extends StatefulWidget {
  const TelaPrincipalEstabelecimento({super.key});

  @override
  State<TelaPrincipalEstabelecimento> createState() =>
      _TelaPrincipalEstabelecimentoState();
}

class _TelaPrincipalEstabelecimentoState
    extends State<TelaPrincipalEstabelecimento> {
  int paginaAtual = 0;

  // Cor principal do app (laranja)
  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMapa(),
          _buildCampoLocalizacao(),
          _buildCampoDestino(),
          _buildBotaoPedirEntregador(),
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

  // CAMPO LOCALIZAÇÃO
  Widget _buildCampoLocalizacao() {
    return Positioned(
      top: 45,
      left: 15,
      right: 15,
      child: TextField(
        decoration: InputDecoration(
          hintText: "Sua localização",
          prefixIcon: const Icon(Icons.location_on),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // CAMPO DESTINO
  Widget _buildCampoDestino() {
    return Positioned(
      top: 105,
      left: 15,
      right: 15,
      child: TextField(
        decoration: InputDecoration(
          hintText: "Para onde?",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // BOTÃO "PEDIR UM ENTREGADOR"
  Widget _buildBotaoPedirEntregador() {
    return Positioned(
      left: 15,
      right: 15,
      bottom: 95,
      child: ElevatedButton(
        onPressed: () {
          // TODO: lógica de pedido de entregador
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: corPrincipal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 4,
        ),
        child: const Text(
          "Pedir um entregador",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // MENU INFERIOR PERSONALIZADO
  // Fica dentro do Stack (sobre o mapa), e não em bottomNavigationBar,
  // para que o mapa apareça atrás dos cantos arredondados o tempo todo.
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

  // ITEM DO MENU INFERIOR
  Widget _buildItemMenu({
    required int index,
    required IconData icone,
    required String texto,
  }) {
    final bool selecionado = paginaAtual == index;
    final Color cor = selecionado ? corPrincipal : Colors.grey;

    return InkWell(
      onTap: () => _onItemMenuTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, color: cor),
          const SizedBox(height: 4),
          Text(
            texto,
            style: TextStyle(color: cor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // LÓGICA DE NAVEGAÇÃO (inalterada)
  void _onItemMenuTap(int index) {
    setState(() {
      paginaAtual = index;
    });

    switch (index) {
      case 0:
        break;

      case 1:
        Navigator.pushNamed(context, '/pedidos_estabelecimento');
        break;

      case 2:
        // Navigator.pushNamed(context, '/atividades_estabelecimento');
        break;

      case 3:
        // Navigator.pushNamed(context, '/perfil_estabelecimento');
        break;
    }
  }
}