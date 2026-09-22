import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uaiou/core/tema/controlador_tema.dart';
import 'package:uaiou/core/tema/cores.dart';
import 'package:uaiou/core/tema/tema.dart';

const PageTransitionsTheme _semTransicoes = PageTransitionsTheme(builders: {});

void main() {
  group('tema', () {
    test('o escuro não devolve superfícies claras', () {
      final escuro = temaEscuro(_semTransicoes);
      final cores = escuro.extension<CoresApp>()!;

      expect(escuro.brightness, Brightness.dark);
      // Fundo escuro e texto claro: o inverso do tema claro, não uma variação
      // dele. Um branco aqui deixaria a tela ilegível com o texto do tema.
      expect(cores.fundo.computeLuminance(), lessThan(0.1));
      expect(cores.texto.computeLuminance(), greaterThan(0.7));
      expect(escuro.scaffoldBackgroundColor, cores.fundo);
    });

    test('o claro mantém superfície clara e texto escuro', () {
      final claro = temaClaro(_semTransicoes);
      final cores = claro.extension<CoresApp>()!;

      expect(claro.brightness, Brightness.light);
      expect(cores.fundo.computeLuminance(), greaterThan(0.9));
      expect(cores.texto.computeLuminance(), lessThan(0.1));
    });

    test('a marca é a mesma nos dois temas', () {
      expect(
        temaClaro(_semTransicoes).colorScheme.primary,
        temaEscuro(_semTransicoes).colorScheme.primary,
      );
      expect(
        temaClaro(_semTransicoes).colorScheme.primary,
        CoresUaiou.principal,
      );
    });

    testWidgets('context.cores acompanha o tema em uso', (tester) async {
      late CoresApp lidas;

      await tester.pumpWidget(
        MaterialApp(
          theme: temaClaro(_semTransicoes),
          darkTheme: temaEscuro(_semTransicoes),
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              lidas = context.cores;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(lidas.fundo, CoresApp.escuro.fundo);
    });

    test('a escolha do usuário troca o modo e avisa a tela', () async {
      final controlador = ControladorTema();
      var avisos = 0;
      controlador.addListener(() => avisos++);

      expect(controlador.modo, ThemeMode.system);
      expect(controlador.rotulo, 'Tema: do sistema');

      // Sem plugin de armazenamento no ambiente de teste, gravar falha — e é
      // justamente o que se quer garantir: a tela troca mesmo assim, porque
      // não conseguir lembrar a preferência é menos grave que travar a troca.
      await controlador.definir(ThemeMode.dark);

      expect(controlador.modo, ThemeMode.dark);
      expect(controlador.rotulo, 'Tema: escuro');
      expect(avisos, 1);

      // Repetir a mesma escolha não reconstrói a árvore à toa.
      await controlador.definir(ThemeMode.dark);
      expect(avisos, 1);
    });

    test('carregar sem cofre disponível mantém o padrão do sistema', () async {
      final controlador = ControladorTema();
      await controlador.carregar();
      expect(controlador.modo, ThemeMode.system);
    });

    test('texto de apoio tem contraste legível nos dois temas', () {
      // 4,5:1 é o mínimo da WCAG para texto pequeno, que é onde este tom vive.
      expect(
        _contraste(CoresApp.claro.textoSuave, CoresApp.claro.superficie),
        greaterThan(4.5),
      );
      expect(
        _contraste(CoresApp.escuro.textoSuave, CoresApp.escuro.superficie),
        greaterThan(4.5),
      );
    });
  });
}

double _contraste(Color frente, Color fundo) {
  final a = frente.computeLuminance();
  final b = fundo.computeLuminance();
  final claro = a > b ? a : b;
  final escuro = a > b ? b : a;
  return (claro + 0.05) / (escuro + 0.05);
}
