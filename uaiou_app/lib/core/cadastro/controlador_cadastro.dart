import 'package:flutter/foundation.dart';

import '../rede/cliente_api.dart';
import '../rede/erros_api.dart';
import '../sessao/controlador_sessao.dart';
import 'rascunho_cadastro.dart';

/// `POST /auth/registrations` — `api/auth.md`.
class RepositorioCadastro {
  final ClienteApi _api;

  const RepositorioCadastro(this._api);

  Future<void> cadastrar(Map<String, dynamic> corpo) async {
    await _api.criar('/auth/registrations', corpo: corpo);
  }
}

/// Erro do cadastro já resolvido para o passo em que deve aparecer
/// (RF-A04.4).
class FalhaDeCadastro {
  final String mensagem;

  /// Passo ao qual devolver o usuário. `null` quando o erro não é de
  /// um campo específico.
  final PassoCadastro? passo;

  /// Campo a destacar, quando dá para saber.
  final String? campo;

  const FalhaDeCadastro(this.mensagem, {this.passo, this.campo});
}

/// ===============================================================
/// CADASTRO — A-04
/// ===============================================================
///
/// Cadastrar e **entrar em seguida**, na mesma ação.
///
/// O motivo é do contrato: `POST /auth/registrations` não devolve
/// token, e enviar documento exige sessão (`POST /uploads` chama
/// `currentUserHolder.require()`). Sem o login automático, o usuário
/// terminaria o assistente e teria de digitar de novo o que acabou de
/// escolher, só para conseguir mandar os documentos.
class ControladorCadastro extends ChangeNotifier {
  final RepositorioCadastro _cadastro;
  final ControladorSessao _sessao;

  ControladorCadastro({
    required RepositorioCadastro cadastro,
    required ControladorSessao sessao,
  }) : _cadastro = cadastro,
       _sessao = sessao;

  bool _enviando = false;
  FalhaDeCadastro? _falha;

  bool get enviando => _enviando;
  FalhaDeCadastro? get falha => _falha;

  void limparFalha() {
    _falha = null;
    notifyListeners();
  }

  /// Devolve `true` quando cadastrou **e** abriu sessão.
  Future<bool> concluir(RascunhoCadastro rascunho) async {
    // Guarda contra reentrância: `notifyListeners()` só reconstrói a
    // UI no frame seguinte, então dois toques a poucos milissegundos
    // de distância (duplo toque, clique + Enter, tela lenta) passam
    // pelo `onPressed: enviando ? null : ...` antes do botão
    // desabilitar. Sem isto, dois `POST /auth/registrations`
    // concorrentes disputam o mesmo CPF: um ganha (201), o outro
    // perde (409) — e a ordem das respostas na rede não é a ordem de
    // chegada no servidor, então a tela pode acabar mostrando o erro
    // do perdedor por cima do sucesso do vencedor.
    if (_enviando) return false;

    // Última conferência local antes de gastar uma viagem.
    final passoInvalido = rascunho.primeiroPassoInvalido();
    if (passoInvalido != null) {
      final erros = rascunho.validar(passoInvalido);
      _falha = FalhaDeCadastro(
        erros.values.first,
        passo: passoInvalido,
        campo: erros.keys.first,
      );
      notifyListeners();
      return false;
    }

    _enviando = true;
    _falha = null;
    notifyListeners();

    try {
      await _cadastro.cadastrar(rascunho.paraJson());

      // A conta nasce `pending`: entra, mas cai na tela de análise.
      await _sessao.entrarComSenha(
        login: rascunho.login.trim(),
        senha: rascunho.senha,
        papel: rascunho.papel,
      );

      rascunho.limpar();
      return true;
    } on ErroApi catch (erro) {
      _falha = _traduzir(erro);
      return false;
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  /// Mapeia o erro do servidor ao passo e campo de origem — RF-A04.4.
  ///
  /// Sem isto, "e-mail já cadastrado" apareceria como falha genérica
  /// no passo 3, longe do campo que precisa mudar.
  FalhaDeCadastro _traduzir(ErroApi erro) {
    final texto = erro.mensagemParaUsuario;
    final codigo = erro.codigo.toUpperCase();
    final pista = '$codigo ${erro.mensagem}'.toLowerCase();

    if (pista.contains('email') || pista.contains('e-mail')) {
      return FalhaDeCadastro(
        texto,
        passo: PassoCadastro.dadosPessoais,
        campo: 'Email',
      );
    }
    if (pista.contains('cpf')) {
      return FalhaDeCadastro(
        texto,
        passo: PassoCadastro.dadosPessoais,
        campo: 'CPF',
      );
    }
    if (pista.contains('cnpj')) {
      return FalhaDeCadastro(texto, passo: PassoCadastro.perfil, campo: 'CNPJ');
    }
    if (pista.contains('login') || pista.contains('usuário')) {
      return FalhaDeCadastro(
        texto,
        passo: PassoCadastro.credenciais,
        campo: 'Usuário',
      );
    }

    return FalhaDeCadastro(texto);
  }
}
