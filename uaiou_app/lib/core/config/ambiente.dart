import 'package:flutter/foundation.dart';

/// ===============================================================
/// CONFIGURAÇÃO POR AMBIENTE — RF-A01.4
/// ===============================================================
///
/// A URL da API vem de `--dart-define`, nunca de constante fixa no
/// código. Isso é o que permite o mesmo código-fonte virar build de
/// desenvolvimento, homologação e produção.
///
/// ```
/// flutter run --dart-define=UAIOU_API_BASE_URL=http://10.0.2.2:8080/api/v1
/// ```
///
/// Sem o define, cai no padrão da plataforma (ver [_baseUrlPadrao]),
/// que só serve para desenvolvimento local.
///
/// **Nenhum segredo entra aqui.** Chave de mapa, de push e de OAuth
/// são tratadas em A-13; esta classe só carrega endereço e modo.
class Ambiente {
  const Ambiente._();

  /// Porta padrão do backend Spring em desenvolvimento local.
  static const String _portaLocal = '8080';

  /// Caminho base do contrato — `spring.servlet.context-path` do backend.
  static const String _caminhoBase = '/api/v1';

  static const String _defineBaseUrl = String.fromEnvironment(
    'UAIOU_API_BASE_URL',
  );

  /// URL base da API.
  ///
  /// Prioriza o `--dart-define`. Sem ele, monta o padrão local — que
  /// muda por plataforma: o emulador Android não enxerga `localhost`
  /// da máquina anfitriã, ele precisa de `10.0.2.2`.
  static String get baseUrl {
    if (_defineBaseUrl.isNotEmpty) return _defineBaseUrl;
    return _baseUrlPadrao;
  }

  static String get _baseUrlPadrao {
    // No navegador, `localhost` é o certo: é ele que forma a origem
    // usada na negociação de CORS.
    if (kIsWeb) return 'http://localhost:$_portaLocal$_caminhoBase';

    return switch (defaultTargetPlatform) {
      // O emulador Android não enxerga a máquina anfitriã como
      // localhost — 10.0.2.2 é o apelido do host para ele.
      TargetPlatform.android => 'http://10.0.2.2:$_portaLocal$_caminhoBase',

      // Desktop e simulador iOS enxergam a máquina anfitriã
      // diretamente.
      _ => 'http://localhost:$_portaLocal$_caminhoBase',
    };
  }

  /// `true` quando o build **não** é de release.
  ///
  /// Governa o registro de rede (RNF-A01.3) e a exibição do `rule` da
  /// RN junto da mensagem de erro (RF-A01.5).
  static bool get modoDesenvolvedor => !kReleaseMode;

  /// Tempo máximo para estabelecer conexão.
  static const Duration tempoLimiteConexao = Duration(seconds: 15);

  /// Tempo máximo aguardando resposta depois de conectado.
  ///
  /// Generoso de propósito: o entregador usa rede móvel em movimento,
  /// e desistir cedo demais transforma lentidão em erro.
  static const Duration tempoLimiteResposta = Duration(seconds: 30);

  /// `true` se a URL em uso não é HTTPS **e** aponta para um backend
  /// fora da máquina/rede de desenvolvimento.
  ///
  /// A-13 (RF-A13.2) usa isto para recusar build de distribuição
  /// apontando para texto puro. Sem a exceção de host local, esta
  /// checagem também bloquearia `flutter run --release` contra o
  /// backend local — que é como esta própria sessão testa o app (o
  /// modo debug tem problema de handshake do dwds no navegador
  /// embutido) — mesmo sem nenhum tráfego saindo da máquina.
  static bool get usaTextoPuro {
    if (baseUrl.startsWith('https://')) return false;
    return !_hostEhLocal(baseUrl);
  }

  static bool _hostEhLocal(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
      return true;
    }
    // Faixas privadas (RFC 1918) — só alcançáveis de dentro da mesma
    // rede local, nunca da internet pública.
    return host.startsWith('192.168.') ||
        host.startsWith('10.') ||
        RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(host);
  }
}
