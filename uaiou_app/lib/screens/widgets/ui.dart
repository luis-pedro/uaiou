import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:uaiou/core/tema/cores.dart';

/// ===============================================================
/// BLOCOS DE LAYOUT COMPARTILHADOS
/// ===============================================================
///
/// As abas repetiam o mesmo esqueleto (fundo laranja, título branco
/// posicionado à mão, folha branca com cantos de 40px). Aqui o esqueleto
/// vira peça única: título grande sobre fundo neutro e o conteúdo logo
/// abaixo, sem moldura — o laranja fica para o que é ação.

/// Página de aba: título grande à esquerda, ações à direita.
class PaginaAba extends StatelessWidget {
  const PaginaAba({
    super.key,
    required this.titulo,
    required this.filho,
    this.subtitulo,
    this.acoes = const [],
  });

  final String titulo;
  final String? subtitulo;
  final List<Widget> acoes;
  final Widget filho;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: context.cores.texto,
                          ),
                        ),
                        if (subtitulo != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitulo!,
                              style: TextStyle(
                                fontSize: 14,
                                color: context.cores.textoSuave,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...acoes,
                ],
              ),
            ),
            Expanded(child: filho),
          ],
        ),
      ),
    );
  }
}

/// Cartão de superfície com contorno fino: a unidade visual de todas as
/// listas do app.
class Cartao extends StatelessWidget {
  const Cartao({
    super.key,
    required this.filho,
    this.aoTocar,
    this.preenchimento = const EdgeInsets.all(16),
    this.margem = EdgeInsets.zero,
    this.cor,
  });

  final Widget filho;
  final VoidCallback? aoTocar;
  final EdgeInsetsGeometry preenchimento;
  final EdgeInsetsGeometry margem;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(20);
    return Padding(
      padding: margem,
      child: Material(
        color: cor ?? context.cores.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: raio,
          side: BorderSide(color: context.cores.borda),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: Padding(padding: preenchimento, child: filho),
        ),
      ),
    );
  }
}

/// Rótulo de seção em caixa-alta discreta, acima de um grupo.
class TituloSecao extends StatelessWidget {
  const TituloSecao(this.texto, {super.key, this.acao});

  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.cores.texto,
              ),
            ),
          ),
          ?acao,
        ],
      ),
    );
  }
}

/// Ícone dentro de um quadrado arredondado tingido.
class IconeTingido extends StatelessWidget {
  const IconeTingido(
    this.icone, {
    super.key,
    this.cor = CoresUaiou.principal,
    this.tamanho = 40,
  });

  final IconData icone;
  final Color cor;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: cor.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(tamanho * .32),
      ),
      child: Icon(icone, color: cor, size: tamanho * .52),
    );
  }
}

/// Grupo de opções estilo ajustes: várias linhas num único cartão,
/// separadas por filete.
class GrupoOpcoes extends StatelessWidget {
  const GrupoOpcoes({super.key, required this.opcoes});

  final List<LinhaOpcao> opcoes;

  @override
  Widget build(BuildContext context) {
    return Cartao(
      preenchimento: EdgeInsets.zero,
      filho: Column(
        children: [
          for (final (i, opcao) in opcoes.indexed) ...[
            if (i > 0)
              Divider(height: 1, indent: 52, color: context.cores.borda),
            opcao,
          ],
        ],
      ),
    );
  }
}

class LinhaOpcao extends StatelessWidget {
  const LinhaOpcao({
    super.key,
    required this.icone,
    required this.texto,
    required this.aoTocar,
    this.detalhe,
    this.cor = CoresUaiou.principal,
  });

  final IconData icone;
  final String texto;
  final String? detalhe;
  final VoidCallback aoTocar;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(icone, color: cor, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texto,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.cores.texto,
                    ),
                  ),
                  if (detalhe != null)
                    Text(
                      detalhe!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.cores.textoSuave,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.cores.textoSuave),
          ],
        ),
      ),
    );
  }
}

/// Sino de avisos com contador de não lidas (RF-A11.7). O número vem de
/// `meta.unread` do servidor — quem chama só repassa.
class BotaoAvisos extends StatelessWidget {
  const BotaoAvisos({
    super.key,
    required this.naoLidas,
    this.flutuante = false,
  });

  final int naoLidas;

  /// Sobre o mapa ganha fundo e sombra; no cabeçalho fica liso.
  final bool flutuante;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Material(
      color: flutuante ? cores.superficie : Colors.transparent,
      shape: const CircleBorder(),
      elevation: flutuante ? 3 : 0,
      shadowColor: cores.sombra,
      child: IconButton(
        tooltip: 'Avisos',
        onPressed: () => Navigator.pushNamed(context, '/notificacoes'),
        icon: Badge(
          isLabelVisible: naoLidas > 0,
          backgroundColor: CoresUaiou.perigo,
          label: Text(naoLidas > 99 ? '99+' : '$naoLidas'),
          child: Icon(Icons.notifications_none_rounded, color: cores.texto),
        ),
      ),
    );
  }
}

/// Anel de duas fatias (laranja cheio × laranja claro) com o total no meio.
/// Uma leitura só da "situação", no lugar de números soltos em linha.
class MedidorAnel extends StatelessWidget {
  const MedidorAnel({
    super.key,
    required this.principal,
    required this.secundario,
    required this.rotuloCentro,
    this.tamanho = 150,
  });

  final int principal;
  final int secundario;
  final String rotuloCentro;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final total = principal + secundario;
    return SizedBox.square(
      dimension: tamanho,
      child: CustomPaint(
        painter: _PintorAnel(
          fracao: total == 0 ? 0 : principal / total,
          vazio: total == 0,
          trilho: CoresUaiou.principal.withValues(alpha: .22),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$total',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: context.cores.texto,
                ),
              ),
              Text(
                rotuloCentro,
                style: TextStyle(fontSize: 13, color: context.cores.textoSuave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PintorAnel extends CustomPainter {
  const _PintorAnel({
    required this.fracao,
    required this.vazio,
    required this.trilho,
  });

  final double fracao;
  final bool vazio;
  final Color trilho;

  @override
  void paint(Canvas canvas, Size size) {
    const espessura = 16.0;
    final area = (Offset.zero & size).deflate(espessura / 2);
    Paint tinta(Color cor) => Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(area, 0, math.pi * 2, false, tinta(trilho));
    if (!vazio && fracao > 0) {
      canvas.drawArc(
        area,
        -math.pi / 2,
        math.pi * 2 * fracao,
        false,
        tinta(CoresUaiou.principal),
      );
    }
  }

  @override
  bool shouldRepaint(_PintorAnel antigo) =>
      antigo.fracao != fracao || antigo.vazio != vazio;
}
