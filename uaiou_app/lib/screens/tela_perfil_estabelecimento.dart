import 'package:flutter/material.dart';

import 'package:uaiou/core/tema/cores.dart';
import 'package:uaiou/screens/widgets/ui.dart';
import 'package:uaiou/screens/casca_principal.dart';
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
    return PaginaAba(titulo: 'Perfil', filho: _buildConteudo());
  }

  /// ============================================================
  /// CONTEÚDO PRINCIPAL
  /// ============================================================

  Widget _buildConteudo() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Cartao(
          preenchimento: const EdgeInsets.all(18),
          filho: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_buildCabecalho(), _buildCreditos(), _buildScore()],
          ),
        ),
        const SizedBox(height: 12),
        const TituloSecao('Negócio'),
        GrupoOpcoes(
          opcoes: [
            LinhaOpcao(
              icone: Icons.bar_chart_rounded,
              texto: 'Atividade',
              detalhe: 'Faturamento e pedidos anteriores',
              aoTocar: () => CascaPrincipal.irPara(context, 2),
            ),
            LinhaOpcao(
              icone: Icons.star_outline_rounded,
              texto: 'Avaliações',
              aoTocar: () => Navigator.pushNamed(context, '/avaliacoes'),
            ),
            LinhaOpcao(
              icone: Icons.block_rounded,
              texto: 'Entregadores bloqueados',
              aoTocar: () => Navigator.pushNamed(context, '/bloqueios'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const TituloSecao('Conta'),
        GrupoOpcoes(
          opcoes: [
            LinhaOpcao(
              icone: Icons.storefront_outlined,
              texto: 'Dados do estabelecimento',
              aoTocar: () => Navigator.pushNamed(context, '/editar_perfil'),
            ),
            LinhaOpcao(
              icone: Icons.badge_outlined,
              texto: 'Documentos',
              aoTocar: () => Navigator.pushNamed(context, '/documentos'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const TituloSecao('Preferências'),
        GrupoOpcoes(
          opcoes: [
            LinhaOpcao(
              icone: Icons.notifications_none_rounded,
              texto: 'Notificações',
              aoTocar: () =>
                  Navigator.pushNamed(context, '/preferencias_notificacao'),
            ),
            LinhaOpcao(
              icone: context.watch<ControladorTema>().modo == ThemeMode.dark
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              texto: 'Aparência',
              detalhe: context.watch<ControladorTema>().rotulo,
              aoTocar: () => escolherTema(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const AcaoSair(),
        const RodapeVersao(),
      ],
    );
  }

  /// ============================================================
  /// CABEÇALHO (foto + nome + cidade)
  /// ============================================================

  Widget _buildCabecalho() {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildFotoPerfil(),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Placeholder que parecia nome real enquanto `GET /me` não
                  // voltava.
                  nomeRestaurante.isEmpty ? "Carregando…" : nomeRestaurante,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.cores.texto,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  cidadeRestaurante.isEmpty
                      ? "Cidade não cadastrada — toque em Informações pessoais"
                      : cidadeRestaurante,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.cores.textoSuave,
                  ),
                ),
              ],
            ),
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
    final usados = assinatura?.consumidosNoCiclo ?? 0;
    final mensais = assinatura?.creditosMensais ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Divider(height: 1, color: context.cores.borda),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${creditos.saldo}',
              style: const TextStyle(
                fontSize: 40,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: corPrincipal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'créditos disponíveis',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.cores.texto,
                    ),
                  ),
                  if (assinatura != null)
                    Text(
                      '$usados de $mensais usados neste ciclo',
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
        if (assinatura != null && mensais > 0) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usados / mensais,
              minHeight: 6,
              backgroundColor: corPrincipal.withValues(alpha: .15),
              valueColor: const AlwaysStoppedAnimation(corPrincipal),
            ),
          ),
        ],
      ],
    );
  }

  /// RF-A12.4/RF-A12.5/RF-A12.6 — nota e componentes do estabelecimento
  /// (`codeContingencyRate`, `activeReviewsAverage`,
  /// `counterofferResponseTimeMin`), sempre visíveis, sem cálculo no
  /// cliente. Sem nota ainda, o card simplesmente some — nunca mostra
  /// "0,0" como se fosse ruim.
  Widget _buildScore() {
    final score = context.watch<ControladorScore>().score;
    final valor = score?.valor ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Divider(height: 1, color: context.cores.borda),
        const SizedBox(height: 14),
        InkWell(
          onTap: () => Navigator.pushNamed(context, '/avaliacoes'),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, color: corPrincipal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nota',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.cores.texto,
                  ),
                ),
              ),
              Text(
                valor.isEmpty ? '—' : valor.replaceAll('.', ','),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: valor.isEmpty
                      ? context.cores.textoSuave
                      : corPrincipal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ============================================================
  /// OPÇÃO DO PERFIL (Atividade, Informações, Segurança...)
  /// ============================================================
}
