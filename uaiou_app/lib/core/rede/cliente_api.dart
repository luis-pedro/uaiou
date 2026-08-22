import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/ambiente.dart';
import 'erros_api.dart';
import 'provedor_de_credencial.dart';

/// ===============================================================
/// CLIENTE HTTP ÚNICO — RF-A01.3
/// ===============================================================
///
/// Concentra URL base, cabeçalhos, tempo limite, injeção de token e
/// tradução de erro. **Nenhuma tela faz requisição direta**: a tela
/// chama repositório, o repositório chama este cliente.
///
/// É o que permite trocar autenticação, instrumentar rede ou mudar a
/// política de repetição em um lugar só.
///
/// Todo método devolve o corpo já decodificado (`Map`, `List` ou
/// `null` em 204) e **lança [ErroApi]** — nunca `DioException`. Quem
/// converte JSON em modelo é o repositório (RNF-A01.2).
class ClienteApi {
  final Dio _dio;

  ProvedorDeCredencial _credencial;

  /// RF-A13.6 — chamado quando o servidor responde 426 (versão do
  /// cliente não é mais aceita). Não existe hoje no backend real; é
  /// o ponto de extensão para quando existir, ver [AtualizacaoObrigatoria].
  final void Function()? aoExigirAtualizacao;

  /// [baseUrl] só é passada em teste; em produção vem de [Ambiente],
  /// que é a única fonte permitida por RF-A01.4.
  ClienteApi({
    Dio? dio,
    String? baseUrl,
    ProvedorDeCredencial credencial = const SemCredencial(),
    this.aoExigirAtualizacao,
  }) : _dio = dio ?? Dio(),
       _credencial = credencial {
    _dio.options
      ..baseUrl = baseUrl ?? Ambiente.baseUrl
      ..connectTimeout = Ambiente.tempoLimiteConexao
      ..receiveTimeout = Ambiente.tempoLimiteResposta
      ..sendTimeout = Ambiente.tempoLimiteResposta
      ..contentType = Headers.jsonContentType
      ..responseType = ResponseType.json
      // Erro de status é tratado aqui, não pelo Dio: precisamos do
      // corpo do envelope para classificar.
      ..validateStatus = (_) => true;

    if (Ambiente.modoDesenvolvedor) {
      _dio.interceptors.add(_RegistroDeRede());
    }
  }

  /// Trocado por A-02 assim que a sessão existir.
  set credencial(ProvedorDeCredencial provedor) => _credencial = provedor;

  Future<Object?> obter(String caminho, {Map<String, dynamic>? query}) =>
      _enviar('GET', caminho, query: query);

  Future<Object?> criar(
    String caminho, {
    Object? corpo,
    Map<String, dynamic>? query,
    String? chaveIdempotencia,
  }) => _enviar(
    'POST',
    caminho,
    corpo: corpo,
    query: query,
    chaveIdempotencia: chaveIdempotencia,
  );

  Future<Object?> substituir(
    String caminho, {
    Object? corpo,
    String? chaveIdempotencia,
  }) => _enviar(
    'PUT',
    caminho,
    corpo: corpo,
    chaveIdempotencia: chaveIdempotencia,
  );

  Future<Object?> alterar(String caminho, {Object? corpo}) =>
      _enviar('PATCH', caminho, corpo: corpo);

  Future<Object?> remover(String caminho, {Object? corpo}) =>
      _enviar('DELETE', caminho, corpo: corpo);

  /// Busca uma URL que o próprio servidor ofereceu em `_links`
  /// (tipicamente `next` da paginação).
  ///
  /// O href do contrato vem absoluto no caminho (`/api/v1/orders?page=2`),
  /// e a base do Dio já inclui `/api/v1` — por isso o prefixo é
  /// removido antes de compor.
  Future<Object?> seguir(String href) {
    const prefixo = '/api/v1';
    final caminho = href.startsWith(prefixo)
        ? href.substring(prefixo.length)
        : href;
    return _enviar('GET', caminho);
  }

  Future<Object?> _enviar(
    String metodo,
    String caminho, {
    Object? corpo,
    Map<String, dynamic>? query,
    String? chaveIdempotencia,
    bool jaRenovou = false,
  }) async {
    final cabecalhos = <String, String>{};

    final token = await _credencial.tokenAtual();
    if (token != null) cabecalhos['Authorization'] = 'Bearer $token';
    if (chaveIdempotencia != null) {
      cabecalhos['Idempotency-Key'] = chaveIdempotencia;
    }

    final Response<dynamic> resposta;
    try {
      resposta = await _dio.request<dynamic>(
        caminho,
        data: corpo,
        queryParameters: query,
        options: Options(method: metodo, headers: cabecalhos),
      );
    } on DioException catch (falha) {
      throw _traduzirFalhaDeTransporte(falha);
    } on Object catch (falha) {
      throw ErroInesperado(mensagem: 'Falha inesperada: $falha');
    }

    final status = resposta.statusCode ?? 0;

    if (status >= 200 && status < 300) {
      return status == 204 ? null : resposta.data;
    }

    // 401: uma única tentativa de renovar e repetir (RF-A02.5).
    //
    // As rotas de autenticação ficam de fora: um 401 vindo de
    // `/auth/sessions` é credencial errada ou refresh inválido, não
    // sessão expirada. Tentar renovar aqui reentra na renovação que
    // está em curso e trava a própria chamada que a produziu.
    if (status == 401 && !jaRenovou && _renovavel(caminho)) {
      if (await _credencial.renovar()) {
        return _enviar(
          metodo,
          caminho,
          corpo: corpo,
          query: query,
          chaveIdempotencia: chaveIdempotencia,
          jaRenovou: true,
        );
      }
      await _credencial.encerrarSessao();
    }

    final erro = erroDoContrato(status, resposta.data);
    if (erro is AtualizacaoObrigatoria) aoExigirAtualizacao?.call();
    throw erro;
  }

  /// `/auth/*` nunca dispara renovação — ver o 401 em [_enviar].
  static bool _renovavel(String caminho) => !caminho.startsWith('/auth/');

  ErroApi _traduzirFalhaDeTransporte(DioException falha) {
    return switch (falha.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const FalhaDeRede(
        codigo: 'TIMEOUT',
        mensagem: 'O servidor demorou para responder. Tente novamente.',
      ),
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate => const FalhaDeRede(),
      DioExceptionType.cancel => const FalhaDeRede(
        codigo: 'CANCELLED',
        mensagem: 'Operação cancelada.',
      ),
      _ => erroDoContrato(falha.response?.statusCode, falha.response?.data),
    };
  }
}

/// Registro de rede — RNF-A01.3.
///
/// Método, rota, status e tempo. **Nunca** o corpo de autenticação
/// nem o token: credencial em registro é credencial vazada.
class _RegistroDeRede extends Interceptor {
  static const _chaveInicio = '_inicio';

  @override
  void onRequest(RequestOptions opcoes, RequestInterceptorHandler proximo) {
    opcoes.extra[_chaveInicio] = DateTime.now();
    debugPrint('→ ${opcoes.method} ${opcoes.path}');
    proximo.next(opcoes);
  }

  @override
  void onResponse(
    Response<dynamic> resposta,
    ResponseInterceptorHandler proximo,
  ) {
    debugPrint(
      '← ${resposta.statusCode} ${resposta.requestOptions.path}'
      ' (${_decorrido(resposta.requestOptions)})',
    );
    proximo.next(resposta);
  }

  @override
  void onError(DioException falha, ErrorInterceptorHandler proximo) {
    debugPrint(
      '✗ ${falha.type.name} ${falha.requestOptions.path}'
      ' (${_decorrido(falha.requestOptions)})',
    );
    proximo.next(falha);
  }

  String _decorrido(RequestOptions opcoes) {
    final inicio = opcoes.extra[_chaveInicio];
    if (inicio is! DateTime) return '?';
    return '${DateTime.now().difference(inicio).inMilliseconds}ms';
  }
}
