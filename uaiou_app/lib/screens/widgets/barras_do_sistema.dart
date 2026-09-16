import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:uaiou/core/tema/cores.dart';

/// ===============================================================
/// BARRA DE NAVEGAÇÃO DO CELULAR
/// ===============================================================
///
/// Sem isto o Android (edge-to-edge) deixa a barra transparente e
/// decide a cor dos ícones sozinho — no tema claro saíam botões
/// brancos sobre fundo branco. Aqui a barra ganha a cor da superfície
/// do tema e os ícones o contraste oposto, nos dois temas.
///
/// Fica no `builder` do `MaterialApp`, abaixo do `Theme`: vale para
/// todas as telas, inclusive folhas e diálogos.
class BarrasDoSistema extends StatelessWidget {
  final Widget child;

  const BarrasDoSistema({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final cores = context.cores;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: cores.superficie,
        systemNavigationBarDividerColor: cores.borda,
        systemNavigationBarIconBrightness: escuro
            ? Brightness.light
            : Brightness.dark,
        // Android 15+ ignora a cor acima e mantém a barra transparente;
        // com isto o sistema aplica um véu atrás dos 3 botões.
        systemNavigationBarContrastEnforced: true,
      ),
      child: child,
    );
  }
}
