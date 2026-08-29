import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:uaiou/core/notificacoes/controlador_notificacoes.dart';
import 'package:uaiou/core/perfil/controlador_perfil.dart';
import 'package:uaiou/others/estabelecimento_service.dart';
import 'package:uaiou/screens/tela_publicar_pedido.dart';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Carrega `GET /me` para exibir o endereço de retirada real —
      // RF-A10.2: a origem do pedido é sempre o endereço do próprio
      // estabelecimento, não há campo de origem no contrato.
      context.read<ControladorPerfil>().carregar();
      // RF-A11.7 — contador de não lidas no menu.
      context.read<ControladorNotificacoes>().carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMapa(),
          _buildCampoLocalizacao(),
          _buildAvisos(),
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
        ],
      ),
    );
  }

  // CAMPO LOCALIZAÇÃO — informativo, lê `GET /me` (A-05). Não é
  // enviado ao servidor: `POST /orders` não tem campo de origem
  // (RF-A10.2), a retirada é sempre o endereço do próprio
  // estabelecimento.
  Widget _buildCampoLocalizacao() {
    return Positioned(
      top: 45,
      left: 15,
      // Abre espaço para o botão de avisos, que agora divide esta faixa.
      right: 75,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.storefront, color: corPrincipal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _enderecoDeRetirada(context),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _enderecoDeRetirada(BuildContext context) {
    final perfil = context.watch<ControladorPerfil>().estado.valorOuNulo;
    final endereco = perfil?.detalhes?.endereco;
    if (endereco == null || endereco.estaVazio) {
      return 'Endereço de retirada: cadastre no seu perfil.';
    }
    final partes = <String>[
      if (endereco.rua != null && endereco.rua!.isNotEmpty)
        [endereco.rua, endereco.numero].whereType<String>().join(', '),
      if (endereco.bairro != null && endereco.bairro!.isNotEmpty)
        endereco.bairro!,
    ];
    return partes.isEmpty
        ? 'Endereço de retirada: cadastre no seu perfil.'
        : 'Retirada: ${partes.join(' — ')}';
  }

  /// RF-A11.7 — avisos no canto superior direito, em vez de item da
  /// barra inferior: os quatro itens que sobraram lá são **lugares onde
  /// se fica** (principal, pedidos, atividades, perfil), e avisos é uma
  /// consulta rápida da qual se volta. Mesmo tratamento já dado à tela
  /// do entregador. O contador continua vindo de `meta.unread` do
  /// servidor, nunca somado aqui.
  Widget _buildAvisos() {
    final naoLidas = context.watch<ControladorNotificacoes>().naoLidas;

    return Positioned(
      top: 45,
      right: 15,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () => Navigator.pushNamed(context, '/notificacoes'),
          child: Padding(
            // RNF-A14.2 — alvo grande: mesmo uso de rua do resto da tela.
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  color: corPrincipal,
                  size: 22,
                ),
                if (naoLidas > 0)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        naoLidas > 99 ? "99+" : "$naoLidas",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
        onPressed: _abrirFormularioPedido,
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
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // RF-A10.1 — `POST /orders` real, na tela dedicada.
  Future<void> _abrirFormularioPedido() async {
    final publicado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TelaPublicarPedido()),
    );

    if (publicado == true && mounted) {
      // RF-A10.5 — a lista de pedidos passa a refletir o novo pedido
      // na próxima visita à tela de pedidos.
      unawaited(context.read<EstadoEstabelecimento>().carregar());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pedido publicado.')));
    }
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
              _buildItemMenu(index: 4, icone: Icons.person, texto: "Perfil"),
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
        break;

      case 1:
        Navigator.pushReplacementNamed(context, '/pedidos_estabelecimento');
        break;

      case 2:
        Navigator.pushReplacementNamed(context, '/atividades_estabelecimento');
        break;

      case 4:
        Navigator.pushReplacementNamed(context, '/perfil_estabelecimento');
        break;
    }
  }
}
