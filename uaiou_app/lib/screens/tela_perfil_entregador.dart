import 'package:flutter/material.dart';

import 'package:uaiou/others/entregador_service.dart';

class TelaPerfilEntregador extends StatefulWidget {
  const TelaPerfilEntregador({super.key});

  @override
  State<TelaPerfilEntregador> createState() => _TelaPerfilEntregadorState();
}

class _TelaPerfilEntregadorState extends State<TelaPerfilEntregador> {
  /// Página selecionada do menu
  int paginaAtual = 3;

  /// Cor principal do aplicativo
  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  /// Foto, nome e cidade vêm do EntregadorService — preenchidos no
  /// login/cadastro do entregador, e compartilhados com as demais telas.
  final EntregadorService _service = EntregadorService.instance;

  String get nomeEntregador => _service.nomeEntregador;
  String get cidadeEntregador => _service.cidadeEntregador;
  String get fotoUrl => _service.fotoUrl;

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
        "Perfil",
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
            const SizedBox(height: 30),

            _buildCabecalho(),

            const SizedBox(height: 30),

            _buildOpcao(
              icone: Icons.person_outline,
              texto: "Informações pessoais",
              onTap: () {
                // TODO: Navigator.pushNamed(context, '/informacoes_pessoais_entregador');
              },
            ),

            const SizedBox(height: 15),

            _buildOpcao(
              icone: Icons.badge_outlined,
              texto: "Informações do entregador",
              onTap: () {
                // TODO: Navigator.pushNamed(context, '/informacoes_entregador');
              },
            ),

            const SizedBox(height: 15),

            _buildOpcao(
              icone: Icons.settings_outlined,
              texto: "Segurança",
              onTap: () {
                // TODO: Navigator.pushNamed(context, '/seguranca_entregador');
              },
            ),

            const SizedBox(height: 15),

            _buildOpcao(
              icone: Icons.receipt_long,
              texto: "Atividade",
              onTap: () => Navigator.pushNamed(
                context,
                '/atividades_entregador',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ============================================================
  /// CABEÇALHO (foto + nome + cidade)
  /// ============================================================

  Widget _buildCabecalho() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildFotoPerfil(),

          const SizedBox(width: 20),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nomeEntregador.isEmpty ? "Nome do entregador" : nomeEntregador,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(34, 34, 34, 1),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                cidadeEntregador.isEmpty
                    ? "Cidade não informada"
                    : cidadeEntregador,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color.fromRGBO(94, 94, 94, 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFotoPerfil() {
    return CircleAvatar(
      radius: 40,
      backgroundColor: const Color.fromRGBO(217, 217, 217, 1),
      backgroundImage: fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
      child: fotoUrl.isEmpty
          ? const Icon(Icons.person, color: Colors.white, size: 32)
          : null,
    );
  }

  /// ============================================================
  /// OPÇÃO DO PERFIL (Informações, Segurança, Atividade...)
  /// ============================================================

  Widget _buildOpcao({
    required IconData icone,
    required String texto,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(230, 230, 230, 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(94, 94, 94, 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icone, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Text(
                texto,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color.fromRGBO(34, 34, 34, 1),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color.fromRGBO(94, 94, 94, 1),
              ),
            ],
          ),
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
        Navigator.pushReplacementNamed(context, '/entregas_entregador');
        break;

      case 2:
        Navigator.pushReplacementNamed(context, '/atividades_entregador');
        break;

      case 3:
        break;
    }
  }
}