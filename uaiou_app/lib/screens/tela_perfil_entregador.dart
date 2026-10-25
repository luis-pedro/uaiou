import 'package:flutter/material.dart';

import 'package:uaiou/core/tema/cores.dart';
import 'package:uaiou/screens/widgets/ui.dart';
import 'package:uaiou/screens/casca_principal.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/gamificacao/controlador_score.dart';
import 'package:uaiou/core/perfil/controlador_perfil.dart';
import 'package:uaiou/core/perfil/perfil.dart';
import 'package:uaiou/core/perfil/repositorio_perfil.dart';
import 'package:uaiou/core/uploads/repositorio_uploads.dart';
import 'package:uaiou/screens/widgets/avatar_rede.dart';
import 'package:uaiou/screens/widgets/aviso_flutuante.dart';
import 'package:uaiou/core/tema/controlador_tema.dart';
import 'package:uaiou/screens/widgets/rodape_versao.dart';
import 'package:uaiou/screens/widgets/seletor_de_tema.dart';
import 'package:uaiou/others/entregador_service.dart';
import 'package:uaiou/screens/widgets/acao_sair.dart';

class TelaPerfilEntregador extends StatefulWidget {
  const TelaPerfilEntregador({super.key});

  @override
  State<TelaPerfilEntregador> createState() => _TelaPerfilEntregadorState();
}

class _TelaPerfilEntregadorState extends State<TelaPerfilEntregador> {
  /// Cor principal do aplicativo
  static const Color corPrincipal = CoresUaiou.principal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<ControladorPerfil>().carregar();
      if (!mounted) return;
      // RF-A12.4 — mesma loja de `GET /me/score` que o cabeçalho da
      // principal usa; sem nota ainda (entregador novo) não é erro de
      // tela, ver `ControladorScore.carregar`.
      context.read<ControladorScore>().carregar();
    });
  }

  /// Nome vem da sessão (A-02) como reserva; `GET /me` (RF-A05.1) é a
  /// fonte de verdade quando já carregou.
  String get nomeEntregador {
    final perfil = context.watch<ControladorPerfil>().estado.valorOuNulo;
    return perfil?.nomeExibicao ?? context.watch<EstadoEntregador>().nome;
  }

  /// ⚠️ O DTO real de `GET /me` (`MeProfile`) não traz cidade para o
  /// entregador — só o estabelecimento tem endereço. A tela mostra o
  /// texto de ausência de propósito.
  String get cidadeEntregador => '';

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
            children: [_buildCabecalho(), _buildScore()],
          ),
        ),
        const SizedBox(height: 12),
        const TituloSecao('Trabalho'),
        GrupoOpcoes(
          opcoes: [
            LinhaOpcao(
              icone: Icons.payments_outlined,
              texto: 'Formas de pagamento',
              detalhe: _textoFormaPagamento,
              aoTocar: _escolherFormaPagamento,
            ),
            LinhaOpcao(
              icone: Icons.bar_chart_rounded,
              texto: 'Atividade',
              detalhe: 'Histórico e estatísticas',
              aoTocar: () => CascaPrincipal.irPara(context, 2),
            ),
            LinhaOpcao(
              icone: Icons.star_outline_rounded,
              texto: 'Avaliações',
              aoTocar: () => Navigator.pushNamed(context, '/avaliacoes'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const TituloSecao('Conta'),
        GrupoOpcoes(
          opcoes: [
            LinhaOpcao(
              icone: Icons.person_outline_rounded,
              texto: 'Informações pessoais',
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
  /// FORMA DE PAGAMENTO
  /// ============================================================

  String get _textoFormaPagamento {
    final formas =
        context
            .watch<ControladorPerfil>()
            .estado
            .valorOuNulo
            ?.detalhes
            ?.formasPagamento ??
        const <FormaPagamento>[];
    return formas.isEmpty
        ? "Nenhuma selecionada"
        : formas.map((f) => f.rotulo).join(', ');
  }

  Future<void> _escolherFormaPagamento() async {
    final controlador = context.read<ControladorPerfil>();
    final atuais = {
      ...?controlador.estado.valorOuNulo?.detalhes?.formasPagamento,
    };

    // `null` = fechou sem salvar.
    final escolhidas = await showModalBottomSheet<Set<FormaPagamento>>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (contexto) {
        final marcadas = {...atuais};
        return StatefulBuilder(
          builder: (contexto, atualizar) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 18, 18, 4),
                  child: Text(
                    "Formas de pagamento",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  "Marque todas que você aceita",
                  style: TextStyle(
                    fontSize: 13,
                    color: context.cores.textoSuave,
                  ),
                ),
                const SizedBox(height: 8),
                for (final forma in FormaPagamento.values)
                  CheckboxListTile(
                    value: marcadas.contains(forma),
                    activeColor: corPrincipal,
                    title: Text(forma.rotulo),
                    onChanged: (marcada) => atualizar(() {
                      marcada == true
                          ? marcadas.add(forma)
                          : marcadas.remove(forma);
                    }),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: corPrincipal,
                      ),
                      onPressed: () => Navigator.pop(contexto, marcadas),
                      child: const Text("Salvar"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (escolhidas == null || !mounted) return;
    if (escolhidas.length == atuais.length && escolhidas.containsAll(atuais)) {
      return;
    }

    final salvou = await controlador.salvar(
      EdicaoDePerfil(
        // Ordem do enum: a mesma que o backend devolve.
        formasPagamento: FormaPagamento.values
            .where(escolhidas.contains)
            .toList(),
      ),
    );
    if (!mounted) return;
    mostrarAviso(
      context,
      salvou
          ? "Formas de pagamento atualizadas."
          : controlador.ultimoErro ?? "Não foi possível salvar.",
      erro: !salvou,
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
                  // "Nome do entregador" parecia dado real; é só o `GET /me` que
                  // ainda não voltou.
                  nomeEntregador.isEmpty ? "Carregando…" : nomeEntregador,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.cores.texto,
                  ),
                ),
                // A cidade não existe no perfil do entregador (`MeProfile` só tem
                // endereço para estabelecimento), então a linha era um "não
                // informada" permanente. Some enquanto não houver o dado.
                const SizedBox(height: 2),
                Text(
                  'Entregador parceiro',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.cores.textoSuave,
                  ),
                ),
                if (cidadeEntregador.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    cidadeEntregador,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.cores.textoSuave,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFotoPerfil() {
    return const AvatarPerfilEditavel(
      icone: Icons.person,
      proposito: PropositoUpload.fotoEntregador,
    );
  }

  /// RF-A05.4/RF-A12.4/RF-A12.5 — nota e componentes vêm de
  /// `GET /me/score`, o app não calcula média. RF-A12.6 — os
  /// componentes já ficam sempre visíveis aqui (não escondidos atrás
  /// de um toque), o que cumpre "tocar mostra a composição" com folga:
  /// mostra mais do que pede, não menos.
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
  /// OPÇÃO DO PERFIL (Informações, Segurança, Atividade...)
  /// ============================================================
}
