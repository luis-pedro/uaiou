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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          // MAPA
          Positioned.fill(
            child: FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(-22.2526, -45.7033), // Santa Rita do Sapucaí
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
          ),

          // CAMPO LOCALIZAÇÃO
          Positioned(
            top: 45,
            left: 15,
            right: 15,
            child: TextField(
              decoration: InputDecoration(
                hintText: "Sua localização",
                prefixIcon: const Icon(Icons.location_on),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // CAMPO DESTINO
          Positioned(
            top: 105,
            left: 15,
            right: 15,
            child: TextField(
              decoration: InputDecoration(
                hintText: "Para onde?",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // PIN DA LOCALIZAÇÃO
          //Center(
            //child: Icon(
              //Icons.location_on,
              //size: 55,
              //color: Color.fromRGBO(254, 98, 29, 1),
            //),
          //),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: paginaAtual,
        selectedItemColor: const Color.fromRGBO(254, 98, 29, 1),
        unselectedItemColor: Colors.grey,

        onTap: (index) {
          setState(() {
            paginaAtual = index;
          });

          switch (index) {
            case 0:
              break;

            case 1:
              // Navigator.pushNamed(context, '/pedidos_estabelecimento');
              break;

            case 2:
              // Navigator.pushNamed(context, '/atividades_estabelecimento');
              break;

            case 3:
              // Navigator.pushNamed(context, '/perfil_estabelecimento');
              break;
          }
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Principal",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: "Pedidos",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: "Atividades",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Perfil",
          ),
        ],
      ),
    );
  }
}