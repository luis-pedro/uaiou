import 'package:flutter/material.dart';

/// ===============================================================
/// CORES DA MARCA E TOKENS DE SUPERFÍCIE
/// ===============================================================
///
/// A cor principal estava declarada em 26 telas, cada uma com o próprio
/// `static const corPrincipal`. Trocar a marca virava uma varredura, e bastava
/// esquecer um arquivo para a interface ficar com dois laranjas.
///
/// O laranja e o verde são **da marca**: não mudam com o tema, porque a
/// identidade não muda de cor à noite. O que muda é tudo que descreve
/// superfície e texto — e é isso que [CoresApp] carrega, uma versão para cada
/// brilho.
class CoresUaiou {
  const CoresUaiou._();

  static const Color principal = Color.fromRGBO(254, 98, 29, 1);
  static const Color sucesso = Color.fromRGBO(108, 201, 80, 1);
  static const Color perigo = Color.fromRGBO(211, 47, 47, 1);

  /// Texto sobre o laranja da marca — branco nos dois temas, porque o fundo é
  /// o mesmo laranja nos dois.
  static const Color sobrePrincipal = Colors.white;
}

/// Tokens que dependem do tema.
///
/// Usar `colorScheme` cru espalharia decisões de aparência pelas telas
/// ("é `surface` ou `surfaceContainerHighest`?"). Aqui o nome diz o papel:
/// fundo da tela, fundo de cartão, texto principal, texto de apoio, borda.
@immutable
class CoresApp extends ThemeExtension<CoresApp> {
  const CoresApp({
    required this.fundo,
    required this.superficie,
    required this.superficieSuave,
    required this.texto,
    required this.textoSuave,
    required this.borda,
    required this.sombra,
    required this.atencao,
    required this.positivo,
    required this.perigo,
    required this.informacao,
    required this.negociacao,
    required this.coleta,
  });

  /// Fundo da tela, atrás de tudo.
  final Color fundo;

  /// Cartões, folhas e barras.
  final Color superficie;

  /// Realce discreto dentro de um cartão (chips não selecionados, listras).
  final Color superficieSuave;

  final Color texto;

  /// Datas, legendas, dicas — contraste menor, nunca abaixo do legível.
  final Color textoSuave;

  final Color borda;
  final Color sombra;

  /// "A receber", prazo correndo, atenção sem erro.
  ///
  /// Tom por tema: laranja escuro some no fundo preto, laranja claro estoura no
  /// branco. É a mesma informação com o contraste de cada lado.
  final Color atencao;

  /// "Recebido", confirmado, concluído.
  final Color positivo;

  /// Erro, cancelamento, recusa — texto e ícone. Botão cheio continua
  /// [CoresUaiou.perigo], que é igual nos dois temas.
  final Color perigo;

  /// Aceito, em andamento, informativo.
  final Color informacao;

  /// Contraoferta em negociação.
  final Color negociacao;

  /// Entregador na loja / coletado.
  final Color coleta;

  static const CoresApp claro = CoresApp(
    fundo: Colors.white,
    superficie: Colors.white,
    superficieSuave: Color(0xFFF2F2F2),
    texto: Color.fromRGBO(34, 34, 34, 1),
    // #5E5E5E sobre branco dá ~7:1. O `Colors.grey` que estava aqui dava ~2,8:1,
    // abaixo do mínimo legível para texto pequeno.
    textoSuave: Color.fromRGBO(94, 94, 94, 1),
    borda: Color.fromRGBO(217, 217, 217, 1),
    sombra: Color(0x1F000000),
    atencao: Color(0xFFEF6C00),
    positivo: Color(0xFF2E7D32),
    // Tons 700/800: passam de 4,5:1 sobre branco em texto de 13px.
    perigo: Color(0xFFC62828),
    informacao: Color(0xFF1565C0),
    negociacao: Color(0xFF6A1B9A),
    coleta: Color(0xFF00695C),
  );

  /// Cinzas quentes, não pretos puros: preto absoluto com texto branco vibra e
  /// cansa, e o laranja da marca fica estridente por cima dele.
  static const CoresApp escuro = CoresApp(
    fundo: Color(0xFF14110F),
    superficie: Color(0xFF1E1B19),
    superficieSuave: Color(0xFF2A2624),
    texto: Color(0xFFF2EFEC),
    textoSuave: Color(0xFFB5ADA7),
    borda: Color(0xFF3A3431),
    sombra: Color(0x66000000),
    atencao: Color(0xFFFFB74D),
    positivo: Color(0xFF81C784),
    // Tons 200/300: o vermelho escuro some no fundo quase preto.
    perigo: Color(0xFFEF9A9A),
    informacao: Color(0xFF90CAF9),
    negociacao: Color(0xFFCE93D8),
    coleta: Color(0xFF80CBC4),
  );

  @override
  CoresApp copyWith({
    Color? fundo,
    Color? superficie,
    Color? superficieSuave,
    Color? texto,
    Color? textoSuave,
    Color? borda,
    Color? sombra,
    Color? atencao,
    Color? positivo,
    Color? perigo,
    Color? informacao,
    Color? negociacao,
    Color? coleta,
  }) => CoresApp(
    fundo: fundo ?? this.fundo,
    superficie: superficie ?? this.superficie,
    superficieSuave: superficieSuave ?? this.superficieSuave,
    texto: texto ?? this.texto,
    textoSuave: textoSuave ?? this.textoSuave,
    borda: borda ?? this.borda,
    sombra: sombra ?? this.sombra,
    atencao: atencao ?? this.atencao,
    positivo: positivo ?? this.positivo,
    perigo: perigo ?? this.perigo,
    informacao: informacao ?? this.informacao,
    negociacao: negociacao ?? this.negociacao,
    coleta: coleta ?? this.coleta,
  );

  @override
  CoresApp lerp(ThemeExtension<CoresApp>? outro, double t) {
    if (outro is! CoresApp) return this;
    return CoresApp(
      fundo: Color.lerp(fundo, outro.fundo, t)!,
      superficie: Color.lerp(superficie, outro.superficie, t)!,
      superficieSuave: Color.lerp(superficieSuave, outro.superficieSuave, t)!,
      texto: Color.lerp(texto, outro.texto, t)!,
      textoSuave: Color.lerp(textoSuave, outro.textoSuave, t)!,
      borda: Color.lerp(borda, outro.borda, t)!,
      sombra: Color.lerp(sombra, outro.sombra, t)!,
      atencao: Color.lerp(atencao, outro.atencao, t)!,
      positivo: Color.lerp(positivo, outro.positivo, t)!,
      perigo: Color.lerp(perigo, outro.perigo, t)!,
      informacao: Color.lerp(informacao, outro.informacao, t)!,
      negociacao: Color.lerp(negociacao, outro.negociacao, t)!,
      coleta: Color.lerp(coleta, outro.coleta, t)!,
    );
  }
}

/// Atalho de leitura nas telas: `context.cores.superficie`.
extension CoresDoContexto on BuildContext {
  CoresApp get cores => Theme.of(this).extension<CoresApp>() ?? CoresApp.claro;

  bool get temaEscuro => Theme.of(this).brightness == Brightness.dark;
}
