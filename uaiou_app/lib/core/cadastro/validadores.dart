/// ===============================================================
/// VALIDAÇÃO DE FORMA — RF-A04.3
/// ===============================================================
///
/// O app valida **o que é forma**: campo obrigatório, formato de
/// e-mail, dígito verificador de CPF/CNPJ, placa. Isso poupa uma
/// viagem ao servidor e dá erro no campo certo.
///
/// **Unicidade e qualquer regra de negócio são do servidor.** Saber se
/// um e-mail já existe exige o banco; tentar adivinhar aqui produz
/// mentira. A resposta 422/409 é exibida como veio.
library;

/// Devolve a mensagem de erro, ou `null` se o valor serve.
typedef Validador = String? Function(String valor);

String? obrigatorio(String valor, String campo) =>
    valor.trim().isEmpty ? '$campo é obrigatório.' : null;

String? validarEmail(String valor) {
  final texto = valor.trim();
  if (texto.isEmpty) return 'E-mail é obrigatório.';

  // Deliberadamente permissivo: a regra completa de e-mail é
  // absurdamente complexa, e quem decide se o endereço existe é o
  // envio, não uma expressão regular.
  final formato = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
  return formato.hasMatch(texto) ? null : 'E-mail inválido.';
}

String? validarSenha(String valor) {
  if (valor.isEmpty) return 'Senha é obrigatória.';
  // O contrato exige de 8 a 255 (RegisterRequest).
  if (valor.length < 8) return 'A senha precisa de ao menos 8 caracteres.';
  if (valor.length > 255) return 'Senha longa demais.';
  return null;
}

String? validarLogin(String valor) {
  final texto = valor.trim();
  if (texto.isEmpty) return 'Usuário é obrigatório.';
  // Faixa do contrato (RegisterRequest: @Size(min = 3, max = 60)).
  if (texto.length < 3) return 'Usuário precisa de ao menos 3 caracteres.';
  if (texto.length > 60) return 'Usuário longo demais.';
  return null;
}

/// CPF com dígito verificador — RF-A04.3.
///
/// Rejeita antes de enviar o que o servidor rejeitaria de qualquer
/// forma, e ainda diz qual campo está errado.
String? validarCpf(String valor) {
  final digitos = _somenteDigitos(valor);
  if (digitos.isEmpty) return 'CPF é obrigatório.';
  if (digitos.length != 11) return 'CPF deve ter 11 dígitos.';

  // Todos iguais passam no cálculo dos dígitos, mas não são CPF.
  if (RegExp(r'^(\d)\1{10}$').hasMatch(digitos)) return 'CPF inválido.';

  for (final tamanho in [9, 10]) {
    var soma = 0;
    for (var i = 0; i < tamanho; i++) {
      soma += int.parse(digitos[i]) * (tamanho + 1 - i);
    }
    final resto = (soma * 10) % 11 % 10;
    if (resto != int.parse(digitos[tamanho])) return 'CPF inválido.';
  }
  return null;
}

/// CNPJ com dígito verificador.
String? validarCnpj(String valor) {
  final digitos = _somenteDigitos(valor);
  if (digitos.isEmpty) return 'CNPJ é obrigatório.';
  if (digitos.length != 14) return 'CNPJ deve ter 14 dígitos.';
  if (RegExp(r'^(\d)\1{13}$').hasMatch(digitos)) return 'CNPJ inválido.';

  const pesosPrimeiro = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  const pesosSegundo = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

  for (final pesos in [pesosPrimeiro, pesosSegundo]) {
    var soma = 0;
    for (var i = 0; i < pesos.length; i++) {
      soma += int.parse(digitos[i]) * pesos[i];
    }
    final resto = soma % 11;
    final esperado = resto < 2 ? 0 : 11 - resto;
    if (esperado != int.parse(digitos[pesos.length])) return 'CNPJ inválido.';
  }
  return null;
}

/// Placa nos dois formatos em circulação: `ABC1234` e Mercosul
/// `ABC1D23`. Opcional — o contrato não a exige.
String? validarPlaca(String valor) {
  final texto = valor.trim().toUpperCase().replaceAll('-', '');
  if (texto.isEmpty) return null;

  final antiga = RegExp(r'^[A-Z]{3}\d{4}$');
  final mercosul = RegExp(r'^[A-Z]{3}\d[A-Z]\d{2}$');
  return antiga.hasMatch(texto) || mercosul.hasMatch(texto)
      ? null
      : 'Placa inválida.';
}

String somenteDigitos(String valor) => _somenteDigitos(valor);

String _somenteDigitos(String valor) => valor.replaceAll(RegExp(r'\D'), '');
