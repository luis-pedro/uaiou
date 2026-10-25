import 'package:flutter/services.dart';

/// Máscara de digitação: `#` é um dígito, qualquer outro caractere é fixo
/// e entra sozinho quando o usuário chega nele — "(35) 99999-9999".
///
/// Só dígitos são aceitos; o que o servidor recebe continua passando por
/// `somenteDigitos`, então a pontuação é só para quem lê.
class MascaraEntrada extends TextInputFormatter {
  MascaraEntrada(this.padrao) : _maxDigitos = '#'.allMatches(padrao).length;

  final String padrao;
  final int _maxDigitos;

  // Padrões usados no cadastro.
  static final telefone = MascaraEntrada('(##) #####-####');
  static final data = MascaraEntrada('##/##/####');
  static final cpf = MascaraEntrada('###.###.###-##');
  static final cnpj = MascaraEntrada('##.###.###/####-##');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue atual,
  ) {
    var digitos = atual.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.length > _maxDigitos) {
      digitos = digitos.substring(0, _maxDigitos);
    }

    final saida = StringBuffer();
    var i = 0;
    for (final caractere in padrao.split('')) {
      if (i >= digitos.length) break;
      if (caractere == '#') {
        saida.write(digitos[i++]);
      } else {
        saida.write(caractere);
      }
    }

    final texto = saida.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Placa: letras maiúsculas e dígitos, até 7 (ABC1D23 ou ABC1234).
class MascaraPlaca extends TextInputFormatter {
  const MascaraPlaca();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue atual,
  ) {
    var texto = atual.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (texto.length > 7) texto = texto.substring(0, 7);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
