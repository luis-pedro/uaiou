import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../notificacoes/identificador_dispositivo.dart';
import '../notificacoes/repositorio_dispositivo.dart';
import '../rede/erros_api.dart';
import '../rede/provedor_de_credencial.dart';
import 'cofre_sessao.dart';
import 'identidade.dart';
import 'repositorio_auth.dart';
import 'sessao.dart';

/// Fase do ciclo de vida da sessão, para a interface saber o que
/// desenhar sem inspecionar campos soltos.
enum FaseSessao {
  /// Ainda lendo o cofre na abertura do app (RF-A02.6).
  carregando,

  /// Sem sessão: vai para o login.
  deslogado,

  /// Sessão válida.
  autenticado,
}

/// ===============================================================
/// CONTROLADOR DA SESSÃO
/// ===============================================================
///
/// Fonte única da sessão no app e implementação do
/// [ProvedorDeCredencial] que o [ClienteApi] consome — é assim que o
/// token chega em toda requisição sem nenhuma tela tocar em header.
class ControladorSessao extends ChangeNotifier implements ProvedorDeCredencial {
  final RepositorioAuth _auth;
  final CofreSessao _cofre;

  /// RF-A11.1/RF-A11.2 — registro e baixa do dispositivo. Opcionais
  /// para não quebrar quem monta o controlador sem essa dependência
  /// (testes existentes de A-02, por exemplo): sem elas, login e
  /// logout simplesmente não tocam em `/me/devices`.
  final RepositorioDispositivo? _dispositivos;
  final IdentificadorDispositivo? _identificadorDispositivo;

  ControladorSessao({
    required RepositorioAuth auth,
    required CofreSessao cofre,
    RepositorioDispositivo? dispositivos,
    IdentificadorDispositivo? identificadorDispositivo,
  }) : _auth = auth,
       _cofre = cofre,
       _dispositivos = dispositivos,
       _identificadorDispositivo = identificadorDispositivo;

  Sessao? _sessao;
  FaseSessao _fase = FaseSessao.carregando;

  /// Renovação em andamento, compartilhada por todas as requisições
  /// que tomaram 401 ao mesmo tempo (RF-A02.5, critério 6).
  Future<bool>? _renovacaoEmCurso;

  FaseSessao get fase => _fase;
  Sessao? get sessao => _sessao;
  UsuarioSessao? get usuario => _sessao?.usuario;
  Papel get papel => _sessao?.usuario.papel ?? Papel.desconhecido;
  StatusConta get status => _sessao?.usuario.status ?? StatusConta.desconhecido;

  bool get autenticado => _fase == FaseSessao.autenticado;

  /// RF-A02.9 — só conta ativa alcança as telas de operação.
  bool get podeOperar => autenticado && status.podeOperar;

  /// RF-A02.6 — chamado na abertura do app.
  ///
  /// Sessão guardada com access token expirado **não** desloga: tenta
  /// renovar, porque o refresh costuma valer bem mais tempo.
  Future<void> restaurar() async {
    final guardada = await _cofre.ler();

    if (guardada == null) {
      _definir(null, FaseSessao.deslogado);
      return;
    }

    _sessao = guardada;

    if (guardada.valido) {
      _definir(guardada, FaseSessao.autenticado);
      return;
    }

    final renovou = await renovar();
    if (!renovou) {
      await _descartar();
    }
  }

  /// RF-A02.1
  Future<void> entrarComSenha({
    required String login,
    required String senha,
    required Papel papel,
  }) async {
    final nova = await _auth.entrarComSenha(
      login: login,
      senha: senha,
      papel: papel,
    );
    await _adotar(nova);
    await _registrarDispositivo();
  }

  /// RF-A02.2
  Future<void> entrarComGoogle({
    required String idToken,
    required Papel papel,
  }) async {
    final nova = await _auth.entrarComGoogle(idToken: idToken, papel: papel);
    await _adotar(nova);
    await _registrarDispositivo();
  }

  /// RF-A02.8
  Future<void> pedirRecuperacaoDeSenha(String email) =>
      _auth.pedirRecuperacaoDeSenha(email);

  /// RF-A02.7 — avisa o servidor e limpa tudo.
  ///
  /// Falha de rede **não** impede o logout local: manter o usuário
  /// logado porque o servidor não respondeu é o pior dos dois mundos.
  Future<void> sair() async {
    // RF-A11.2 — a baixa do dispositivo precisa do token AINDA válido,
    // por isso acontece antes de `_descartar()`: depois disso o
    // cliente HTTP não tem mais credencial para autenticar o DELETE.
    await _removerDispositivo();

    final refresh = _sessao?.refreshToken;
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _auth.sair(refresh);
      } on ErroApi {
        // Ignorado de propósito — ver doc acima.
      }
    }
    await _descartar();
  }

  // ----------------------------------------------------------------
  // ProvedorDeCredencial — consumido pelo ClienteApi
  // ----------------------------------------------------------------

  @override
  Future<String?> tokenAtual() async {
    final token = _sessao?.accessToken;
    if (token == null || token.isEmpty) return null;
    return token;
  }

  /// Uma renovação por vez.
  ///
  /// Três requisições simultâneas com token expirado disparam **uma**
  /// chamada e aguardam o mesmo resultado. Sem isto, cada uma faria
  /// sua própria rotação e as demais morreriam com
  /// `REFRESH_TOKEN_REUSED` — o servidor trata reuso como vazamento e
  /// revoga a família inteira, deslogando o usuário de todo lugar.
  @override
  Future<bool> renovar() {
    final emCurso = _renovacaoEmCurso;
    if (emCurso != null) return emCurso;

    final tentativa = _renovar();
    _renovacaoEmCurso = tentativa;
    return tentativa.whenComplete(() => _renovacaoEmCurso = null);
  }

  Future<bool> _renovar() async {
    final refresh = _sessao?.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final nova = await _auth.renovar(refresh);
      await _adotar(nova);
      return true;
    } on ErroApi {
      // Refresh inválido, expirado ou reusado: não há como salvar.
      return false;
    }
  }

  @override
  Future<void> encerrarSessao() => _descartar();

  // ----------------------------------------------------------------

  Future<void> _adotar(Sessao nova) async {
    await _cofre.gravar(nova);
    _definir(nova, FaseSessao.autenticado);
  }

  Future<void> _descartar() async {
    await _cofre.limpar();
    _definir(null, FaseSessao.deslogado);
  }

  void _definir(Sessao? sessao, FaseSessao fase) {
    _sessao = sessao;
    _fase = fase;
    notifyListeners();
  }

  /// RF-A11.1 — chamado após todo login bem-sucedido, nunca dentro de
  /// `_adotar`: renovação de token também passa por `_adotar` e não é
  /// login, não deveria reenviar o registro.
  ///
  /// Falha aqui **não** desfaz o login: o dispositivo pode não ter
  /// registrado (rede caiu, por exemplo), mas o usuário já está
  /// autenticado e a inbox continua acessível — é exatamente o caso
  /// que RF-A11.6 cobre.
  Future<void> _registrarDispositivo() async {
    final dispositivos = _dispositivos;
    final identificador = _identificadorDispositivo;
    if (dispositivos == null || identificador == null) return;

    try {
      final idLocal = await identificador.obterOuCriarLocal();
      // RF-A13.6 — versão real do pacote, não valor fixo: é o que
      // permite ao servidor um dia identificar cliente desatualizado.
      final appVersion = await _versaoDoPacote();
      final registrado = await dispositivos.registrar(
        pushToken: idLocal,
        platform: 'web',
        appVersion: appVersion,
      );
      await identificador.gravarRegistroAtual(registrado.id);
    } on ErroApi {
      // Ignorado de propósito — ver doc acima.
    }
  }

  /// Falha ao ler o pacote (plataforma sem suporte, por exemplo) não
  /// pode impedir o registro do dispositivo — a versão é informativa,
  /// não obrigatória.
  Future<String?> _versaoDoPacote() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } on Object {
      return null;
    }
  }

  /// RF-A11.2 — baixa do dispositivo, chamada no logout ANTES de
  /// descartar a sessão (ver `sair()`).
  Future<void> _removerDispositivo() async {
    final dispositivos = _dispositivos;
    final identificador = _identificadorDispositivo;
    if (dispositivos == null || identificador == null) return;

    try {
      final registroId = await identificador.lerRegistroAtual();
      if (registroId != null && registroId.isNotEmpty) {
        await dispositivos.remover(registroId);
      }
    } on ErroApi {
      // Vazamento de push do usuário anterior é pior que um registro
      // órfão no servidor — mas não podemos travar o logout local por
      // causa de uma falha de rede aqui.
    } finally {
      await identificador.limparRegistroAtual();
    }
  }
}
