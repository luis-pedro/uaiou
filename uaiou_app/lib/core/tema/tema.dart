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
    // Barra neutra, título forte à esquerda: o laranja fica reservado para o
    // que é ação, em vez de ocupar o topo de toda tela.
    appBarTheme: AppBarTheme(
      backgroundColor: cores.fundo,
      foregroundColor: cores.texto,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: cores.texto,
        letterSpacing: -0.2,
      ),
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
    cardTheme: CardThemeData(
      color: cores.superficie,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cores.borda),
      ),
    ),
    // Botões grandes em pílula: alvo de toque confortável para quem usa o app
    // de capacete ou com uma mão só.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CoresUaiou.principal,
        foregroundColor: CoresUaiou.sobrePrincipal,
        disabledBackgroundColor: CoresUaiou.principal.withValues(alpha: .45),
        disabledForegroundColor: CoresUaiou.sobrePrincipal,
        elevation: 0,
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: const StadiumBorder(),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CoresUaiou.principal,
        foregroundColor: CoresUaiou.sobrePrincipal,
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: cores.texto,
        minimumSize: const Size(64, 52),
        side: BorderSide(color: cores.borda, width: 1.5),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CoresUaiou.principal,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      labelTextStyle: WidgetStateProperty.resolveWith(
        (estados) => TextStyle(
          fontSize: 12,
          fontWeight: estados.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: estados.contains(WidgetState.selected)
              ? CoresUaiou.principal
              : cores.textoSuave,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: cores.superficieSuave,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: TextStyle(color: cores.texto, fontWeight: FontWeight.w600),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cores.superficieSuave,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: TextStyle(color: cores.textoSuave),
      labelStyle: TextStyle(color: cores.textoSuave),
      floatingLabelStyle: const TextStyle(color: CoresUaiou.principal),
      helperStyle: TextStyle(color: cores.textoSuave),
      errorStyle: TextStyle(color: cores.perigo),
      prefixStyle: TextStyle(color: cores.texto),
      prefixIconColor: cores.textoSuave,
      suffixIconColor: cores.textoSuave,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cores.superficieSuave),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cores.superficieSuave),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CoresUaiou.principal, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cores.perigo),
      ),
    ),
    textTheme: Typography.material2021(platform: TargetPlatform.android).black
        .copyWith(
          headlineMedium: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        )
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
