import '../rede/cliente_api.dart';
import '../rede/erros_api.dart';
import 'modelo_rota.dart';

/// `GET /orders/{id}/route` — sub-recurso de rota do pedido (T-25).
///
/// Separado de [RepositorioPedidos] de propósito: a rota é a única
/// leitura do app que depende de um provedor externo, e manter a
/// fronteira visível é o que impede alguém amanhã embutir a chamada no
/// caminho da vitrine (RF-25.7).
class RepositorioRotas {
  final ClienteApi _api;

  const RepositorioRotas(this._api);

  Future<RotaDoPedido> obter(String pedidoId) async {
    final resposta = await _api.obter('/orders/$pedidoId/route');
    if (resposta is! Map) {
      throw const ErroInesperado(mensagem: 'Resposta de rota fora do contrato.');
    }
    return RotaDoPedido.doJson(Map<String, dynamic>.from(resposta));
  }
}
