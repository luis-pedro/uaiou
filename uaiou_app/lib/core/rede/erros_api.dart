import '../config/ambiente.dart';

/// ===============================================================
/// ERROS DA API — RF-A01.5
/// ===============================================================
///
/// O contrato responde erro sempre no mesmo envelope:
///
/// ```json
/// { "error": { "code": "...", "message": "...", "rule": "RN-05.1",
///              "details": { } } }
/// ```
///
/// Aqui ele vira uma família selada de erros, um por família de
/// status, para que a tela trate o caso com `switch` exaustivo em vez
/// de comparar número de status espalhado pelo app.
///
/// **`mensagem` é texto de negócio já redigido em pt-BR pelo
/// servidor.** A interface exibe; não reescreve nem troca por
/// mensagem genérica.
sealed class ErroApi implements Exception {
  /// Código estável da falha (`INSUFFICIENT_CREDITS`), para lógica.
  final String codigo;

  /// Texto para o usuário, vindo do servidor.
  final String mensagem;

  /// Regra de negócio violada (`RN-05.1`), quando houver.
  final String? regra;

  /// Contexto estruturado (`{ "required": 1, "available": 0 }`).
  final Map<String, dynamic> detalhes;

  const ErroApi({
    required this.codigo,
    required this.mensagem,
    this.regra,
    this.detalhes = const {},
  });

  /// O que mostrar na tela. Em desenvolvimento, anexa a RN — é o que
  /// permite conferir a task contra a regra sem abrir o servidor.
  String get mensagemParaUsuario {
    if (Ambiente.modoDesenvolvedor && regra != null) {
      return '$mensagem  [$regra]';
    }
    return mensagem;
  }

  @override
  String toString() =>
      '$runtimeType($codigo): $mensagem'
      '${regra != null ? ' [$regra]' : ''}';
}

/// 400 — payload malformado. Erro de programação: falhar alto em
/// desenvolvimento, mensagem genérica em produção.
class RequisicaoInvalida extends ErroApi {
  const RequisicaoInvalida({
    required super.codigo,
    required super.mensagem,
    super.regra,
    super.detalhes,
  });
}

/// 401 — sem token ou token inválido. Quem trata é A-02: renova a
/// sessão e repete, ou desloga.
class NaoAutenticado extends ErroApi {
  const NaoAutenticado({
    required super.codigo,
    required super.mensagem,
    super.regra,
    super.detalhes,
  });
}

/// 403 — papel ou `status` sem permissão (suspenso, bloqueado,
/// transição não liberada). O `status` do usuário pode ter mudado no
/// servidor desde o login.
class SemPermissao extends ErroApi {
  const SemPermissao({
    required super.codigo,
    required super.mensagem,
    super.regra,
    super.detalhes,
  });
}

/// 404 — inexistente **ou fora do escopo do usuário**. As duas coisas
/// são indistinguíveis de propósito: o contrato não confirma a
/// existência de recurso alheio.
class NaoEncontrado extends ErroApi {
  const NaoEncontrado({
    required super.codigo,
    required super.mensagem,
    super.regra,
    super.detalhes,
  });
}

/// 409 — conflito de estado por concorrência (pedido já atribuído).
///
/// **Não é falha**: é o caso normal de dois entregadores aceitarem o
/// mesmo pedido. A tela recarrega o estado em vez de mostrar erro
/// genérico (RF-A07.4).
class Conflito extends ErroApi {
  const Conflito({
    required super.codigo,
    required super.mensagem,
    super.regra,
    super.detalhes,
  });
}

/// 422 — regra de negócio violada, sempre com `rule` apontando a RN.
/// **Sempre exibir `mensagem` ao usuário.**
class RegraDeNegocio extends ErroApi {
  const RegraDeNegocio({
    required super.codigo,
    required super.mensagem,
    super.regra,
    super.detalhes,
  });
}

/// Sem conexão, tempo esgotado ou requisição cancelada. Não veio do
/// servidor — nunca tem `rule`. A tela oferece nova tentativa.
class FalhaDeRede extends ErroApi {
  const FalhaDeRede({
    super.codigo = 'NETWORK_FAILURE',
    super.mensagem =
        'Sem conexão com o servidor. Verifique a internet '
        'e tente novamente.',
    super.detalhes,
  }) : super(regra: null);
}

/// 426 — versão do cliente não é mais aceita pelo servidor (RF-A13.6).
///
/// **O backend ainda não implementa isto** — não há hoje nenhum
/// endpoint nem código de erro de "versão mínima" no contrato real.
/// Este tipo existe como ponto de extensão defensivo: 426 é o status
/// HTTP correto para "upgrade required", então se o servidor um dia
/// passar a responder assim, o cliente já sabe tratar em vez de cair
/// no [ErroInesperado] genérico.
class AtualizacaoObrigatoria extends ErroApi {
  const AtualizacaoObrigatoria({
    super.codigo = 'UPGRADE_REQUIRED',
    super.mensagem =
        'Esta versão do UaiOu não é mais compatível com o servidor. '
        'Atualize o aplicativo para continuar.',
    super.detalhes,
  }) : super(regra: null);
}

/// 5xx ou resposta que não casa com o contrato. O usuário não tem o
/// que fazer além de tentar de novo.
class ErroInesperado extends ErroApi {
  /// Status HTTP, quando houve resposta.
  final int? status;

  const ErroInesperado({
    super.codigo = 'UNEXPECTED',
    super.mensagem = 'Algo deu errado. Tente novamente em instantes.',
    this.status,
    super.detalhes,
  }) : super(regra: null);
}

/// Converte o envelope do contrato no erro tipado correspondente.
///
/// Corpo ausente ou fora do formato não impede a classificação: o
/// status ainda diz o que aconteceu, e é melhor um erro certo com
/// texto genérico do que um [ErroInesperado] por causa do corpo.
ErroApi erroDoContrato(int? status, Object? corpo) {
  final envelope = _envelope(corpo);

  final codigo = envelope['code'] as String? ?? 'HTTP_${status ?? 0}';
  final regra = envelope['rule'] as String?;
  final detalhes = envelope['details'] is Map
      ? Map<String, dynamic>.from(envelope['details'] as Map)
      : const <String, dynamic>{};
  final mensagem = envelope['message'] as String? ?? _mensagemPadrao(status);

  return switch (status) {
    400 => RequisicaoInvalida(
      codigo: codigo,
      mensagem: mensagem,
      regra: regra,
      detalhes: detalhes,
    ),
    401 => NaoAutenticado(
      codigo: codigo,
      mensagem: mensagem,
      regra: regra,
      detalhes: detalhes,
    ),
    403 => SemPermissao(
      codigo: codigo,
      mensagem: mensagem,
      regra: regra,
      detalhes: detalhes,
    ),
    404 => NaoEncontrado(
      codigo: codigo,
      mensagem: mensagem,
      regra: regra,
      detalhes: detalhes,
    ),
    409 => Conflito(
      codigo: codigo,
      mensagem: mensagem,
      regra: regra,
      detalhes: detalhes,
    ),
    422 => RegraDeNegocio(
      codigo: codigo,
      mensagem: mensagem,
      regra: regra,
      detalhes: detalhes,
    ),
    // RF-A13.6 — ver comentário de AtualizacaoObrigatoria: sem
    // contraparte real no backend hoje, mas o status é padrão HTTP.
    426 => AtualizacaoObrigatoria(
      codigo: codigo,
      mensagem: mensagem,
      detalhes: detalhes,
    ),
    _ => ErroInesperado(
      codigo: codigo,
      mensagem: mensagem,
      status: status,
      detalhes: detalhes,
    ),
  };
}

Map<String, dynamic> _envelope(Object? corpo) {
  if (corpo is Map && corpo['error'] is Map) {
    return Map<String, dynamic>.from(corpo['error'] as Map);
  }
  return const {};
}

String _mensagemPadrao(int? status) => switch (status) {
  400 => 'Não foi possível enviar os dados.',
  401 => 'Sua sessão expirou. Entre novamente.',
  403 => 'Você não tem permissão para esta ação.',
  404 => 'Não encontramos o que você procura.',
  409 => 'Isso mudou enquanto você olhava. Atualize e tente de novo.',
  422 => 'Não foi possível concluir a operação.',
  426 => 'Esta versão do UaiOu não é mais compatível com o servidor. '
      'Atualize o aplicativo para continuar.',
  _ => 'Algo deu errado. Tente novamente em instantes.',
};
