import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:uaiou/core/tema/cores.dart';

/// Botão "Continuar com Google" no padrão visual do app.
///
/// O ícone antigo era um PNG de 21px: borrava em tela densa e sumia no
/// tema escuro. Aqui o "G" é desenhado em vetor, na cor da marca UaiOu
/// (o app é monocromático), e fundo/borda/texto seguem cada tema.
class BotaoGoogle extends StatelessWidget {
  const BotaoGoogle({super.key, required this.aoTocar});

  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final escuro = context.temaEscuro;
    // Valores do guia de marca: fundo, borda e texto por tema.
    final fundo = escuro ? const Color(0xFF131314) : Colors.white;
    final borda = escuro ? const Color(0xFF8E918F) : const Color(0xFF747775);
    final texto = escuro ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F);

    return OutlinedButton(
      onPressed: aoTocar,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: fundo,
        foregroundColor: texto,
        side: BorderSide(color: borda),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(dimension: 20, child: CustomPaint(painter: _LogoG())),
          SizedBox(width: 12),
          Text('Continuar com Google'),
        ],
      ),
    );
  }
}

class _LogoG extends CustomPainter {
  const _LogoG();

  // Monocromático, como o resto do app: as quatro partes na cor da marca.
  static const _azul = CoresUaiou.principal;
  static const _verde = CoresUaiou.principal;
  static const _amarelo = CoresUaiou.principal;
  static const _vermelho = CoresUaiou.principal;

  @override
  void paint(Canvas canvas, Size size) {
    final lado = size.shortestSide;
    final espessura = lado * .2;
    final raio = (lado - espessura) / 2;
    final centro = Offset(size.width / 2, size.height / 2);
    final area = Rect.fromCircle(center: centro, radius: raio);
    double rad(double graus) => graus * math.pi / 180;

    Paint tinta(Color cor) => Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura;

    // Ângulos em graus, 0 = leste, sentido horário. A abertura do "G" fica
    // entre -45° e 0°, no alto à direita.
    canvas.drawArc(area, rad(-45), rad(-110), false, tinta(_vermelho));
    canvas.drawArc(area, rad(-155), rad(-55), false, tinta(_amarelo));
    canvas.drawArc(area, rad(150), rad(-105), false, tinta(_verde));
    canvas.drawArc(area, rad(45), rad(-45), false, tinta(_azul));

    // Barra horizontal do "G".
    canvas.drawRect(
      Rect.fromLTRB(
        centro.dx,
        centro.dy - espessura / 2,
        centro.dx + raio + espessura / 2,
        centro.dy + espessura / 2,
      ),
      Paint()..color = _azul,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
