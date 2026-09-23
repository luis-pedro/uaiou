import '../rede/cliente_api.dart';
import '../sessao/sessao.dart';
import 'modelos_feira.dart';

/// ===============================================================
/// REPOSITÓRIO DO MODO FEIRA — `docs/feira/01-fluxos.md`
/// ===============================================================
///
/// Rotas próprias (`/feira/...`), não as do produto: o desvio da feira
/// entra por aqui e nenhum repositório existente ganha um `if`.
class RepositorioFeira {
  final ClienteApi _api;

  const RepositorioFeira(this._api);

  /// Entrada do jogador: nome e nome de usuário, sem senha. A sessão
  /// vem na mesma resposta, porque não existe login separado quando
  /// não há segredo a provar.
  Future<Sessao> entrar({
    required String nome,
    required String username,
  }) async {
    final resposta = await _api.criar(
      '/feira/jogadores',
      corpo: {'nome': nome, 'username': username},
    );
    if (resposta is! Map) {
      throw StateError('Resposta de entrada fora do contrato.');
    }
    final sessao = resposta['sessao'];
    if (sessao is! Map) {
      throw StateError('Resposta de entrada sem sessão.');
    }
    return Sessao.doJson(Map<String, dynamic>.from(sessao));
  }

  Future<List<PedidoFeira>> pedidos() async {
    final resposta = await _api.obter('/feira/pedidos');
    if (resposta is! List) return const [];
    return resposta
        .whereType<Map>()
        .map((item) => PedidoFeira.doJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<CapturaFeira> capturar(String pedidoId) async {
    final resposta = await _api.criar('/feira/pedidos/$pedidoId/capturas');
    if (resposta is! Map) {
      throw StateError('Resposta de captura fora do contrato.');
    }
    return CapturaFeira.doJson(Map<String, dynamic>.from(resposta));
  }

  /// Finalização no ponto: sem código, porque não há destinatário no salão
  /// para ditar um. Chegar é a prova — o servidor confere o geofence.
  Future<CapturaFeira> finalizar(String pedidoId) async {
    final resposta = await _api.criar('/feira/pedidos/$pedidoId/finalizacao');
    if (resposta is! Map) {
      throw StateError('Resposta de finalização fora do contrato.');
    }
    return CapturaFeira.doJson(Map<String, dynamic>.from(resposta));
  }

  Future<EstandeFeira> estande() async {
    final resposta = await _api.obter('/feira/estande');
    if (resposta is! Map) return const EstandeFeira();
    return EstandeFeira.doJson(Map<String, dynamic>.from(resposta));
  }

  Future<List<CapturaFeira>> minhasCapturas() async {
    final resposta = await _api.obter('/feira/capturas');
    if (resposta is! List) return const [];
    return resposta
        .whereType<Map>()
        .map((item) => CapturaFeira.doJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
