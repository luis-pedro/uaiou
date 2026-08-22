import 'package:flutter/foundation.dart';

import '../sessao/identidade.dart';
import 'validadores.dart';

/// Em qual passo do assistente um erro deve ser mostrado (RF-A04.4).
enum PassoCadastro { dadosPessoais, perfil, credenciais }

/// ===============================================================
/// RASCUNHO DO CADASTRO — RF-A04.1
/// ===============================================================
///
/// Os três passos coletam aqui e **só enviam na confirmação final**.
/// Antes de A-04, cada `TextField` das seis telas era anônimo: sair da
/// tela perdia o que tinha sido digitado, e nada era enviado.
///
/// Guardado em memória e descartado ao concluir — RNF-A04.1: dado de
/// cadastro não é persistido em texto puro entre passos.
class RascunhoCadastro extends ChangeNotifier {
  Papel papel = Papel.entregador;

  // Passo 1 — dados pessoais
  String nome = '';
  String email = '';
  String telefone = '';
  String dataNascimento = '';
  String cpf = '';

  // Passo 2 — perfil do papel
  String placa = '';
  String cnpj = '';
  String rua = '';
  String enderecoComplemento = '';
  String numero = '';
  String cidade = '';

  // Passo 3 — credenciais
  String login = '';
  String senha = '';
  String confirmacaoDeSenha = '';

  void definirPapel(Papel novo) {
    papel = novo;
    notifyListeners();
  }

  void limpar() {
    nome = email = telefone = dataNascimento = cpf = '';
    placa = cnpj = rua = enderecoComplemento = numero = cidade = '';
    login = senha = confirmacaoDeSenha = '';
    notifyListeners();
  }

  // ----------------------------------------------------------------
  // Validação por passo — RF-A04.3
  // ----------------------------------------------------------------

  /// Erros do passo, por rótulo do campo. Vazio = passo válido.
  Map<String, String> validar(PassoCadastro passo) => switch (passo) {
    PassoCadastro.dadosPessoais => _erros({
      'Nome': obrigatorio(nome, 'Nome'),
      'Email': validarEmail(email),
      'CPF': validarCpf(cpf),
    }),
    PassoCadastro.perfil => _erros({
      if (papel == Papel.estabelecimento) 'CNPJ': validarCnpj(cnpj),
      if (papel == Papel.entregador) 'Placa do veículo': validarPlaca(placa),
    }),
    PassoCadastro.credenciais => _erros({
      'Usuário': validarLogin(login),
      'Senha': validarSenha(senha),
      'Confirme a senha': senha != confirmacaoDeSenha
          ? 'As senhas não conferem.'
          : null,
    }),
  };

  bool passoValido(PassoCadastro passo) => validar(passo).isEmpty;

  /// Primeiro passo que ainda tem erro — para RF-A04.4 devolver o
  /// usuário ao lugar certo quando o servidor recusar.
  PassoCadastro? primeiroPassoInvalido() {
    for (final passo in PassoCadastro.values) {
      if (!passoValido(passo)) return passo;
    }
    return null;
  }

  Map<String, String> _erros(Map<String, String?> candidatos) {
    final erros = <String, String>{};
    candidatos.forEach((campo, erro) {
      if (erro != null) erros[campo] = erro;
    });
    return erros;
  }

  // ----------------------------------------------------------------
  // Envio
  // ----------------------------------------------------------------

  /// Corpo de `POST /auth/registrations`.
  ///
  /// ⚠️ **Telefone, data de nascimento e endereço não são enviados.**
  /// O protótipo os coleta, mas `RegisterRequest` não tem campo para
  /// eles — nem `RegisterProfile`. Enviá-los seria descartado em
  /// silêncio pelo servidor. Ver o relatório da A-04.
  Map<String, dynamic> paraJson() => {
    'role': papel.noContrato,
    'login': login.trim(),
    'email': email.trim(),
    'password': senha,
    'displayName': nome.trim(),
    'profile': {
      if (papel == Papel.entregador) ...{
        'cpf': somenteDigitos(cpf),
        if (placa.trim().isNotEmpty) 'vehiclePlate': placa.trim().toUpperCase(),
      },
      if (papel == Papel.estabelecimento) ...{
        'cnpj': somenteDigitos(cnpj),
        'businessName': nome.trim(),
      },
    },
  };
}
