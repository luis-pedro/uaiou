import 'package:flutter/material.dart';

import 'cores.dart';

/// ===============================================================
/// TEMAS CLARO E ESCURO
/// ===============================================================
///
/// As telas escreviam `Colors.white` como fundo e cinza como texto, o que
/// funcionava num tema só. Aqui ficam as decisões que valem para o app inteiro
/// — fundo, cartão, campo de texto, barra — para que a tela não precise repetir
/// nenhuma delas.
ThemeData temaClaro(PageTransitionsTheme transicoes) =>
    _tema(Brightness.light, CoresApp.claro, transicoes);

ThemeData temaEscuro(PageTransitionsTheme transicoes) =>
    _tema(Brightness.dark, CoresApp.escuro, transicoes);

ThemeData _tema(
  Brightness brilho,
  CoresApp cores,
  PageTransitionsTheme transicoes,
) {
  final esquema = ColorScheme.fromSeed(
    seedColor: CoresUaiou.principal,
    brightness: brilho,
    // A marca é laranja e continua laranja nos dois temas; o gerador só decide
    // os tons de apoio.
    primary: CoresUaiou.principal,
    onPrimary: CoresUaiou.sobrePrincipal,
    surface: cores.superficie,
    onSurface: cores.texto,
    error: CoresUaiou.perigo,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brilho,
    colorScheme: esquema,
    scaffoldBackgroundColor: cores.fundo,
    canvasColor: cores.superficie,
    dividerColor: cores.borda,
    pageTransitionsTheme: transicoes,
    extensions: [cores],
    appBarTheme: const AppBarTheme(
      backgroundColor: CoresUaiou.principal,
      foregroundColor: CoresUaiou.sobrePrincipal,
      elevation: 0,
    ),
    // Fundo do campo e da folha seguem a superfície do tema; no escuro, um
    // branco fixo aqui seria uma lanterna na cara de quem usa à noite.
    dialogTheme: DialogThemeData(backgroundColor: cores.superficie),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: cores.superficie),
    cardTheme: CardThemeData(color: cores.superficie),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cores.superficie,
      hintStyle: TextStyle(color: cores.textoSuave),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cores.borda),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cores.borda),
      ),
    ),
    textTheme: Typography.material2021(platform: TargetPlatform.android).black
        .apply(bodyColor: cores.texto, displayColor: cores.texto)
        .apply(bodyColor: cores.texto, displayColor: cores.texto),
    iconTheme: IconThemeData(color: cores.texto),
    listTileTheme: ListTileThemeData(
      textColor: cores.texto,
      iconColor: cores.textoSuave,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: CoresUaiou.principal,
    ),
  );
}
