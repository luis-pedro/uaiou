import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/financeiro/creditos.dart';
import 'package:uaiou/core/financeiro/repositorio_creditos.dart';
import 'package:uaiou/core/gamificacao/controlador_score.dart';
import 'package:uaiou/core/perfil/controlador_perfil.dart';
import 'package:uaiou/core/rede/cliente_api.dart';
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
  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  Creditos? _creditos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<ControladorPerfil>().carregar();
      if (!mounted) return;
      try {
        final creditos = await RepositorioCreditos(context.read<ClienteApi>()).obter();
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

  /// ⚠️ `logoObjectKey` é uma chave interna de storage: o backend
  /// nunca devolve a URL pública correspondente em `GET /me`, e o
  /// fluxo de confirmação de upload (`PUT /uploads/{id}`) só expõe
  /// `fileUrl` de curta validade — não a chave persistente que o
  /// PATCH exige de volta. Sem uma rota que resolva isso, a troca de
  /// logo (RF-A05.3) não tem como completar o vínculo; a tela mantém
  /// o avatar padrão em vez de fingir uma foto que não persiste.
  String get fotoUrl => '';

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

              const SizedBox(height: 30),

              const AcaoSair(),
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
                nomeRestaurante.isEmpty
                    ? "Nome do restaurante"
                    : nomeRestaurante,
                style: const TextStyle(
                  fontSize: 20,
                  color: Color.fromRGBO(34, 34, 34, 1),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                cidadeRestaurante.isEmpty
                    ? "Cidade não informada"
                    : cidadeRestaurante,
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
          ? const Icon(Icons.store, color: Colors.white, size: 32)
          : null,
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
            const Icon(Icons.account_balance_wallet_outlined, color: corPrincipal),
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
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nota ${score.valor}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Janela: ${score.janela}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (score.componentes.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              for (final componente in score.componentes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${componente.metrica}: ${componente.valor}'
                    '${componente.contribuicao != null ? ' (${componente.contribuicao})' : ''}',
                    style: const TextStyle(fontSize: 12, color: Color.fromRGBO(94, 94, 94, 1)),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color.fromRGBO(94, 94, 94, 1),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icone, size: 20, color: const Color.fromRGBO(34, 34, 34, 1)),
              const SizedBox(width: 14),
              Text(
                texto,
                style: const TextStyle(
                  fontSize: 15,
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
