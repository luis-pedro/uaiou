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
    // O gerador deriva estes do laranja: sai um cinza amarronzado e
    // lavado que o Material usa em rótulo de campo, subtítulo, aba não
    // selecionada, ícone de lista e alça de folha. Fixar nos tokens do
    // app mantém o texto secundário legível e igual nos dois temas.
    onSurfaceVariant: cores.textoSuave,
    outline: cores.borda,
    outlineVariant: cores.borda,
    surfaceContainerLowest: cores.superficie,
    surfaceContainerLow: cores.superficie,
    surfaceContainer: cores.superficie,
    surfaceContainerHigh: cores.superficieSuave,
    surfaceContainerHighest: cores.superficieSuave,
    surfaceTint: Colors.transparent,
    error: cores.perigo,
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
    dialogTheme: DialogThemeData(
      backgroundColor: cores.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: cores.texto,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: cores.superficie),
    cardTheme: CardThemeData(color: cores.superficie),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cores.superficie,
      hintStyle: TextStyle(color: cores.textoSuave),
      labelStyle: TextStyle(color: cores.textoSuave),
      floatingLabelStyle: const TextStyle(color: CoresUaiou.principal),
      helperStyle: TextStyle(color: cores.textoSuave),
      errorStyle: TextStyle(color: cores.perigo),
      prefixStyle: TextStyle(color: cores.texto),
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
