import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// ===============================================================
/// MARCADORES DO MAPA DE ROTA
/// ===============================================================
///
/// Desenhados em código e entregues ao MapLibre como imagem: o mapa
/// vetorial não desenha widget, só ícone registrado no estilo.
///
/// Tudo sai em [escala]x e a camada usa `iconSize: 1 / escala` — assim
/// o ícone fica nítido em tela de alta densidade sem depender de quantos
/// pixels físicos o aparelho tem.
class MarcadoresMapa {
  const MarcadoresMapa._();

  static const double escala = 3;

  /// Ponteiro do entregador: seta de navegação dentro de um disco
  /// branco, com halo translúcido. A seta aponta para cima (norte); a
  /// camada gira o ícone pelo rumo.
  static Future<Uint8List> ponteiro(Color cor) {
    const lado = 56.0;
    return _desenhar(lado, lado, (canvas) {
      const centro = Offset(lado / 2, lado / 2);

      canvas.drawCircle(
        centro,
        lado / 2,
        Paint()..color = cor.withValues(alpha: .18),
      );
      canvas.drawCircle(
        centro.translate(0, 1.5),
        17,
        Paint()
          ..color = Colors.black.withValues(alpha: .28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(centro, 17, Paint()..color = Colors.white);
      canvas.drawCircle(centro, 14, Paint()..color = cor);

      // Seta em "V" fechado, como a dos apps de GPS: ponta para cima e
      // um entalhe na base que deixa a direção legível mesmo pequena.
      final seta = Path()
        ..moveTo(centro.dx, centro.dy - 9)
        ..lineTo(centro.dx + 7, centro.dy + 8)
        ..lineTo(centro.dx, centro.dy + 4)
        ..lineTo(centro.dx - 7, centro.dy + 8)
        ..close();
      canvas.drawPath(seta, Paint()..color = Colors.white);
    });
  }

  /// Pino em gota com um ícone dentro. A ponta fica no ponto exato — a
  /// camada ancora o ícone pela base.
  static Future<Uint8List> pino(Color cor, IconData icone) {
    const largura = 40.0;
    const altura = 52.0;
    return _desenhar(largura, altura, (canvas) {
      const raio = 17.0;
      const centro = Offset(largura / 2, raio + 2);
      const ponta = Offset(largura / 2, altura - 3);

      // Sombra no chão: dá a leitura de "pino fincado" com a câmera
      // inclinada.
      canvas.drawOval(
        Rect.fromCenter(center: ponta, width: 12, height: 4),
        Paint()
          ..color = Colors.black.withValues(alpha: .3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );

      final gota = _gota(centro, raio, ponta);
      canvas.drawPath(
        gota.shift(const Offset(0, 1.5)),
        Paint()
          ..color = Colors.black.withValues(alpha: .25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawPath(gota, Paint()..color = cor);
      canvas.drawPath(
        gota,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );

      _icone(canvas, icone, centro, 19, Colors.white);
    });
  }

  /// Círculo de cabeça [raio] com a ponta em [ponta], as laterais
  /// tangentes ao círculo.
  static Path _gota(Offset centro, double raio, Offset ponta) {
    final distancia = ponta.dy - centro.dy;
    final angulo = math.acos(raio / distancia);
    final inicio = math.pi / 2 + angulo;
    final varredura = 2 * math.pi - 2 * angulo;

    return Path()
      ..moveTo(ponta.dx, ponta.dy)
      ..lineTo(
        centro.dx + raio * math.cos(math.pi / 2 - angulo),
        centro.dy + raio * math.sin(math.pi / 2 - angulo),
      )
      ..arcTo(
        Rect.fromCircle(center: centro, radius: raio),
        math.pi / 2 - angulo,
        -varredura,
        false,
      )
      ..lineTo(
        centro.dx + raio * math.cos(inicio),
        centro.dy + raio * math.sin(inicio),
      )
      ..close();
  }

  static void _icone(
    Canvas canvas,
    IconData icone,
    Offset centro,
    double tamanho,
    Color cor,
  ) {
    final texto = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icone.codePoint),
        style: TextStyle(
          fontSize: tamanho,
          fontFamily: icone.fontFamily,
          package: icone.fontPackage,
          color: cor,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    texto.paint(canvas, centro - Offset(texto.width / 2, texto.height / 2));
  }

  static Future<Uint8List> _desenhar(
    double largura,
    double altura,
    void Function(Canvas canvas) pintar,
  ) async {
    final gravador = ui.PictureRecorder();
    final canvas = Canvas(gravador)..scale(escala);
    pintar(canvas);
    final imagem = await gravador.endRecording().toImage(
      (largura * escala).ceil(),
      (altura * escala).ceil(),
    );
    final bytes = await imagem.toByteData(format: ui.ImageByteFormat.png);
    imagem.dispose();
    return bytes!.buffer.asUint8List();
  }
}
