import 'package:flutter/material.dart';

import 'package:uaiou/core/tema/cores.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/financeiro/creditos.dart';
import 'package:uaiou/core/financeiro/repositorio_creditos.dart';
import 'package:uaiou/core/gamificacao/controlador_score.dart';
import 'package:uaiou/core/perfil/controlador_perfil.dart';
import 'package:uaiou/core/rede/cliente_api.dart';
import 'package:uaiou/core/uploads/repositorio_uploads.dart';
import 'package:uaiou/screens/widgets/avatar_rede.dart';
import 'package:uaiou/core/tema/controlador_tema.dart';
import 'package:uaiou/screens/widgets/rodape_versao.dart';
import 'package:uaiou/screens/widgets/seletor_de_tema.dart';
import 'package:uaiou/others/estabelecimento_service.dart';
import 'package:uaiou/screens/widgets/acao_sair.dart';

class TelaPerfilEstabelecimento extends StatefulWidget {
  const TelaPerfilEstabelecimento({super.key});

  @override
  State<TelaPerfilEstabelecimento> createState() =>
      _TelaPerfilEstabelecimentoState();
}

class _TelaPerfilEstabelecimentoState extends State<TelaPerfilEstabelecimento> {
  /// Página selecionada do menu
  int paginaAtual = 3;

  /// Cor principal do aplicativo
  static const Color corPrincipal = CoresUaiou.principal;

  Creditos? _creditos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<ControladorPerfil>().carregar();
      if (!mounted) return;
      try {
        final creditos = await RepositorioCreditos(
          context.read<ClienteApi>(),
        ).obter();
        if (mounted) setState(() => _creditos = creditos);
      } on Exception {
        // Sem crédito ainda não é erro de tela.
      }
      // RF-A12.4 — `GET /me/score` também serve o estabelecimento
      // (componentes diferentes: `codeContingencyRate`,
      // `activeReviewsAverage`, `counterofferResponseTimeMin`), mesma
      // loja compartilhada com o cabeçalho do entregador.
      if (mounted) context.read<ControladorScore>().carregar();
    });
  }

  /// Nome vem da sessão (A-02) como reserva; `GET /me` (RF-A05.1) é a
  /// fonte de verdade quando já carregou.
  String get nomeRestaurante {
    final perfil = context.watch<ControladorPerfil>().estado.valorOuNulo;
    return perfil?.nomeExibicao ?? context.watch<EstadoEstabelecimento>().nome;
  }

  String get cidadeRestaurante {
    final perfil = context.watch<ControladorPerfil>().estado.valorOuNulo;
    return perfil?.detalhes?.endereco?.cidade ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corPrincipal,
      // O recuo da barra do sistema é aplicado pelo menu inferior.
      body: SafeArea(
        bottom: false,
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
        decoration: BoxDecoration(
          color: context.cores.superficie,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
        ),
        child: SingleChildScrollView(
          // padding inferior reserva o espaço do menu fixo (85px)
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),

              _buildCabecalho(),

              const SizedBox(height: 20),

              _buildCreditos(),

              const SizedBox(height: 20),

              _buildScore(),

              const SizedBox(height: 20),

              _buildOpcao(
                icone: Icons.receipt_long,
                texto: "Atividade",
                onTap: () =>
                    Navigator.pushNamed(context, '/atividades_estabelecimento'),
              ),

              const SizedBox(height: 15),

              _buildOpcao(
                icone: Icons.star_outline,
                texto: "Avaliações",
                onTap: () => Navigator.pushNamed(context, '/avaliacoes'),
              ),

              const SizedBox(height: 15),

              _buildOpcao(
                icone: Icons.person_outline,
                texto: "Informações pessoais",
                onTap: () => Navigator.pushNamed(context, '/editar_perfil'),
              ),

              const SizedBox(height: 15),

              _buildOpcao(
                icone: Icons.storefront_outlined,
                texto: "Documentos",
                onTap: () => Navigator.pushNamed(context, '/documentos'),
              ),

              const SizedBox(height: 15),

              _buildOpcao(
                icone: Icons.block,
                texto: "Entregadores bloqueados",
                onTap: () => Navigator.pushNamed(context, '/bloqueios'),
              ),

              const SizedBox(height: 15),

              _buildOpcao(
                icone: Icons.notifications_outlined,
                texto: "Preferências de notificação",
                onTap: () =>
                    Navigator.pushNamed(context, '/preferencias_notificacao'),
              ),

              const SizedBox(height: 15),

              _buildOpcao(
                icone: context.watch<ControladorTema>().modo == ThemeMode.dark
                    ? Icons.dark_mode
                    : Icons.light_mode,
                texto: context.watch<ControladorTema>().rotulo,
                onTap: () => escolherTema(context),
              ),

              const SizedBox(height: 30),

              const AcaoSair(),

              const RodapeVersao(),
            ],
          ),
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
                // Placeholder que parecia nome real enquanto `GET /me` não
                // voltava.
                nomeRestaurante.isEmpty ? "Carregando…" : nomeRestaurante,
                style: TextStyle(fontSize: 20, color: context.cores.texto),
              ),
              const SizedBox(height: 5),
              Text(
                cidadeRestaurante.isEmpty
                    ? "Cidade não cadastrada — toque em Informações pessoais"
                    : cidadeRestaurante,
                style: TextStyle(fontSize: 13, color: context.cores.textoSuave),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFotoPerfil() {
    return const AvatarPerfilEditavel(
      icone: Icons.store,
      proposito: PropositoUpload.logoEstabelecimento,
    );
  }

  /// RF-A05.5 — cota e consumo, **sem** botão de compra: a v1 não
  /// vende crédito no app (plano atribuído pelo admin).
  Widget _buildCreditos() {
    final creditos = _creditos;
    if (creditos == null) return const SizedBox.shrink();
    final assinatura = creditos.assinatura;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(254, 98, 29, .08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              color: corPrincipal,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${creditos.saldo} créditos disponíveis',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (assinatura != null)
                    Text(
                      '${assinatura.consumidosNoCiclo}/${assinatura.creditosMensais} usados neste ciclo',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.cores.textoSuave,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// RF-A12.4/RF-A12.5/RF-A12.6 — nota e componentes do estabelecimento
  /// (`codeContingencyRate`, `activeReviewsAverage`,
  /// `counterofferResponseTimeMin`), sempre visíveis, sem cálculo no
  /// cliente. Sem nota ainda, o card simplesmente some — nunca mostra
  /// "0,0" como se fosse ruim.
  Widget _buildScore() {
    final score = context.watch<ControladorScore>().score;
    if (score == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(254, 98, 29, .08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: corPrincipal),
                const SizedBox(width: 10),
                // "Janela: all_time" era vocabulário do contrato vazando para a
                // tela, e a segunda linha ainda deixava um vão embaixo do card.
                Expanded(
                  child: Text(
                    'Nota ${score.valor}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (score.componentes.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              // O espaço entre as linhas fica entre elas, não depois da última:
              // `bottom: 4` no último item era o branco sobrando no fim do card.
              for (final (indice, componente) in score.componentes.indexed)
                Padding(
                  padding: EdgeInsets.only(top: indice == 0 ? 0 : 4),
                  child: Text(
                    '${componente.metrica}: ${componente.valor}'
                    '${componente.contribuicao != null ? ' (${componente.contribuicao})' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.cores.textoSuave,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// ============================================================
  /// OPÇÃO DO PERFIL (Atividade, Informações, Segurança...)
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
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: context.cores.superficie,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.cores.textoSuave, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icone, size: 20, color: context.cores.texto),
              const SizedBox(width: 14),
              Text(
                texto,
                style: TextStyle(fontSize: 15, color: context.cores.texto),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: context.cores.textoSuave,
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
        height: 85 + MediaQuery.viewPaddingOf(context).bottom,
        decoration: BoxDecoration(
          color: context.cores.superficie,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
          boxShadow: [
            BoxShadow(
              color: context.cores.sombra,
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

    final Color cor = selecionado ? corPrincipal : context.cores.textoSuave;

    // `selected` faz o leitor de tela anunciar qual aba está aberta; sem isso
    // os quatro itens soavam iguais.
    return Semantics(
      button: true,
      selected: selecionado,
      label: texto,
      child: InkWell(
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
        Navigator.pushReplacementNamed(context, '/principal_estabelecimento');
        break;

      case 1:
        Navigator.pushReplacementNamed(context, '/pedidos_estabelecimento');
        break;

      case 2:
        Navigator.pushReplacementNamed(context, '/atividades_estabelecimento');
        break;

      case 3:
        break;
    }
  }
}
