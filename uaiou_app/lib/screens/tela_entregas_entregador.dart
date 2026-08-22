import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/pedidos/lista_de_pedidos.dart';
import 'package:uaiou/others/pedido.dart';
import 'package:uaiou/others/entregador_service.dart';
import 'package:uaiou/screens/widgets/badge_status.dart';
import 'package:uaiou/screens/widgets/visao_carregavel.dart';

class TelaEntregasEntregador extends StatefulWidget {
  const TelaEntregasEntregador({super.key});

  @override
  State<TelaEntregasEntregador> createState() => _TelaEntregasEntregadorState();
}

class _TelaEntregasEntregadorState extends State<TelaEntregasEntregador> {
  /// Página selecionada do menu
  int paginaAtual = 1;

  /// Cor principal do aplicativo
  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  @override
  void initState() {
    super.initState();
    // RNF-A03.1 — carga tem ciclo de vida próprio; `build` roda
    // muitas vezes e não pode disparar requisição.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EstadoEntregador>().carregar();
    });
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

  /// Duas listas independentes, cada uma com o próprio recorte no
  /// servidor e o próprio estado de carga (RF-A03.3/RF-A03.5).
  Widget _buildLista() {
    final estado = context.watch<EstadoEntregador>();

    return RefreshIndicator(
      // RF-A03.6
      color: corPrincipal,
      onRefresh: () => Future.wait([
        estado.emAndamento.recarregar(),
        estado.concluidas.recarregar(),
      ]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 25, 20, 95),
        // Sem isto, puxar não funciona quando a lista é curta demais
        // para rolar — que é justamente o caso do estado vazio.
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildTituloSecao("Entregas pendentes"),
          const SizedBox(height: 10),
          _buildSecao(estado.emAndamento, vazio: "Nenhuma entrega pendente"),

          const SizedBox(height: 20),
          const Divider(color: Color.fromRGBO(94, 94, 94, 1), height: 1),
          const SizedBox(height: 20),

          _buildTituloSecao("Entregas concluídas"),
          const SizedBox(height: 10),
          _buildSecao(
            estado.concluidas,
            vazio: "Nenhuma entrega concluída ainda",
          ),
        ],
      ),
    );
  }

  /// Observa a **própria lista**, não a loja que a contém.
  ///
  /// Depender do repasse da loja é frágil — e foi exatamente o que
  /// deixou esta tela girando para sempre com a requisição já
  /// respondida. Aqui, quem muda é quem avisa, e só esta seção
  /// reconstrói.
  Widget _buildSecao(ListaDePedidos lista, {required String vazio}) {
    return ListenableBuilder(
      listenable: lista,
      builder: (context, _) => VisaoCarregavel<List<Pedido>>(
        estado: lista.estado,
        aoTentarNovamente: lista.carregar,
        textoVazio: vazio,
        iconeVazio: Icons.local_shipping_outlined,
        construir: (entregas) => Column(
          children: [
            ...entregas.map((entrega) => _buildCardEntrega(context, entrega)),
            if (lista.temMais) _buildCarregarMais(lista),
          ],
        ),
      ),
    );
  }

  /// RF-A03.7 — a próxima página vem do `_links.next` do servidor.
  Widget _buildCarregarMais(ListaDePedidos lista) {
    if (lista.carregandoMais) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: CircularProgressIndicator(color: corPrincipal),
      );
    }

    return TextButton(
      onPressed: lista.carregarMais,
      child: const Text("Carregar mais", style: TextStyle(color: corPrincipal)),
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

  /// ============================================================
  /// CARD DA ENTREGA
  /// ============================================================

  Widget _buildCardEntrega(BuildContext context, Pedido entrega) {
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
                  entrega.nomeEstabelecimento?.isNotEmpty == true
                      ? entrega.nomeEstabelecimento!
                      : "Pedido ${entrega.rotuloCurto}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(34, 34, 34, 1),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              BadgeStatus(entrega.status),
            ],
          ),

          const SizedBox(height: 10),

          // O endereço vem no detalhe que o servidor permitiu: na
          // vitrine, só o bairro (RF-11.6).
          Text(
            entrega.enderecoResumido,
            style: const TextStyle(
              fontSize: 13,
              color: Color.fromRGBO(94, 94, 94, 1),
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              if (entrega.minutosDesdeAceite != null) ...[
                _buildChipTempo(entrega.minutosDesdeAceite!),
                const Spacer(),
              ] else
                const Spacer(),
              InkWell(
                // RF-A08.2 — pedido aceito abre a execução da entrega;
                // demais estados não têm ação aqui ainda.
                onTap: entrega.status == StatusPedido.aceito
                    ? () => Navigator.pushNamed(
                        context,
                        '/entrega_em_andamento',
                        arguments: entrega.id,
                      )
                    : null,
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
        "há $minutos min",
        style: const TextStyle(
          fontSize: 13,
          color: Color.fromRGBO(34, 34, 34, 1),
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
              _buildItemMenu(index: 0, icone: Icons.home, texto: "Principal"),
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
