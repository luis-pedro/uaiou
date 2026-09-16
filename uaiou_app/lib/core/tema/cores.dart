import 'package:flutter/material.dart';

/// ===============================================================
/// CORES DA MARCA
/// ===============================================================
///
/// A cor principal estava declarada em 26 telas, cada uma com o próprio
/// `static const corPrincipal`. Trocar a marca virava uma varredura, e bastava
/// esquecer um arquivo para a interface ficar com dois laranjas.
///
/// As telas continuam declarando `corPrincipal`, mas apontando para cá: a
/// mudança é de origem do valor, não de estilo de escrita.
class CoresUaiou {
  const CoresUaiou._();

  static const Color principal = Color.fromRGBO(254, 98, 29, 1);
  static const Color sucesso = Color.fromRGBO(108, 201, 80, 1);

  /// Texto principal.
  static const Color texto = Color.fromRGBO(34, 34, 34, 1);

  /// Texto de apoio (datas, legendas, dicas).
  ///
  /// `Colors.grey` (#9E9E9E) sobre branco dá ~2,8:1 de contraste — abaixo dos
  /// 4,5:1 que a WCAG pede para texto pequeno, que é justamente onde ele era
  /// usado. Este tom resolve sem mudar a aparência de "secundário".
  static const Color textoSecundario = Color.fromRGBO(94, 94, 94, 1);

  /// Bordas e divisórias.
  static const Color borda = Color.fromRGBO(217, 217, 217, 1);
}
