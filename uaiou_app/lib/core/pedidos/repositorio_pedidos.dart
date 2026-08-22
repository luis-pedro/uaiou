import '../modelos/dinheiro.dart';
import '../modelos/pagina.dart';
import '../rede/cliente_api.dart';
import '../rede/idempotencia.dart';
import '../../others/pedido.dart';
import 'contraoferta.dart';

/// Página de pedidos + o `warning` específico desta rota.
class PaginaDePedidos {
  final Pagina<Pedido> pagina;

  /// RF-11.8 — entregador com posição obsoleta recebe **lista vazia**
  /// com `LOCATION_STALE`, em vez de um resultado calculado sobre
  /// posição velha, que pareceria correto e não seria.
  final String? aviso;

  const PaginaDePedidos(this.pagina, this.aviso);

  bool get posicaoObsoleta => aviso == 'LOCATION_STALE';

  /// Texto do estado vazio quando o servidor explicou o motivo.
  String? get motivoDoVazio => posicaoObsoleta
      ? 'Sua localização está desatualizada. Ative a localização para '
            'ver os pedidos por perto.'
      : aviso;
}

/// `GET /orders` — `api/pedidos.md`.
///
/// **O recorte é do servidor.** `status` não escolhe o escopo, só qual
/// fatia dentro do escopo do papel: o estabelecimento sempre vê os
/// próprios pedidos, o entregador sempre vê a vitrine elegível ou os
/// seus (RF-11.6). Nenhum valor de query alcança pedido de terceiro.
class RepositorioPedidos {
  final ClienteApi _api;

  const RepositorioPedidos(this._api);

  Future<PaginaDePedidos> listar({
    StatusPedido? status,
    int? pagina,
    int? porPagina,
  }) async {
    final resposta = await _api.obter(
      '/orders',
      query: {
        'status': ?status?.paraContrato,
        'page': ?pagina,
        'perPage': ?porPagina,
      },
    );
    return _converter(resposta);
  }

  /// Segue o `_links.next` que o servidor mandou — RF-A03.7.
  /// O app não monta query de página por conta própria.
  Future<PaginaDePedidos> seguir(String href) async =>
      _converter(await _api.seguir(href));

  Future<Pedido> obter(String id) async {
    final resposta = await _api.obter('/orders/$id');
    if (resposta is! Map) {
      throw StateError('Resposta de pedido fora do contrato.');
    }
    return Pedido.doJson(Map<String, dynamic>.from(resposta));
  }

  /// `POST /orders/{id}/assignment` — RF-A07.3. Corpo vazio: a
  /// identidade do entregador vem do token, nunca do payload.
  ///
  /// A resposta (`AssignmentResponse`) não traz o pedido completo
  /// (`orderId`, `courierId`, `finalFee`, `assignedAt`, `_links` —
  /// conferido em `AssignmentResponse.java`), só a confirmação da
  /// atribuição. Quem quer o pedido atualizado recarrega a lista de
  /// `status=accepted`, não lê esta resposta.
  Future<void> aceitar(String pedidoId) async {
    await _api.criar(
      '/orders/$pedidoId/assignment',
      chaveIdempotencia: gerarChaveIdempotencia('assignment-$pedidoId'),
    );
  }

  /// `POST /orders/{id}/counteroffers` — RF-A07.5.
  ///
  /// `CreateCounterofferRequest` no backend só tem `proposedFee`
  /// (conferido em `CreateCounterofferRequest.java`) — o `note` do
  /// exemplo em `api/pedidos.md` não existe no DTO real, então não é
  /// enviado.
  Future<void> contrapropor(String pedidoId, Dinheiro valor) async {
    await _api.criar(
      '/orders/$pedidoId/counteroffers',
      corpo: {'proposedFee': valor.paraJson()},
    );
  }

  /// `POST /orders` — RF-A10.1. `Idempotency-Key` é enviado por
  /// disciplina do contrato (RNF-A10.1), mas **a proteção real contra
  /// duplo toque é a guarda de reentrância do controlador**: conferido
  /// em `OrdersController.create` (backend) que a rota não lê o
  /// cabeçalho — diferente de `POST /orders/{id}/assignment`, esta
  /// criação não é idempotente no servidor hoje.
  Future<Pedido> publicar({
    required Dinheiro valorProposto,
    required String rua,
    required String numero,
    required String bairro,
    required double lat,
    required double lng,
    required String nomeRecebedor,
    String? complemento,
    String? telefoneRecebedor,
    DateTime? prazoEsperado,
  }) async {
    final resposta = await _api.criar(
      '/orders',
      chaveIdempotencia: gerarChaveIdempotencia('publicar-pedido'),
      corpo: {
        'proposedFee': valorProposto.paraJson(),
        if (prazoEsperado != null)
          'expectedDeliveryAt': prazoEsperado.toUtc().toIso8601String(),
        'destination': {
          'street': rua,
          'number': numero,
          if (complemento != null && complemento.isNotEmpty)
            'complement': complemento,
          'district': bairro,
          'lat': lat,
          'lng': lng,
        },
        'receiver': {
          'name': nomeRecebedor,
          if (telefoneRecebedor != null && telefoneRecebedor.isNotEmpty)
            'phone': telefoneRecebedor,
        },
      },
    );
    if (resposta is! Map) {
      throw StateError('Resposta de publicação de pedido fora do contrato.');
    }
    return Pedido.doJson(Map<String, dynamic>.from(resposta));
  }

  /// `GET /orders/{id}/counteroffers` — RF-A10.6, contraofertas
  /// recebidas pelo estabelecimento.
  Future<List<Contraoferta>> obterContraofertas(String pedidoId) async {
    final resposta = await _api.obter('/orders/$pedidoId/counteroffers');
    if (resposta is! List) return const [];
    return resposta
        .whereType<Map>()
        .map((item) => Contraoferta.doJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// `PUT /counteroffers/{id}/decision` — RF-A10.6.
  Future<void> decidirContraoferta(String contraofertaId, {required bool aceitar}) async {
    await _api.substituir(
      '/counteroffers/$contraofertaId/decision',
      corpo: {'outcome': aceitar ? 'accepted' : 'rejected'},
    );
  }

  /// `GET /orders/{id}/delivery/code` — RF-A10.7, exclusivo do
  /// estabelecimento dono (403 para o entregador, mesmo o atribuído).
  Future<CodigoDeEntrega> obterCodigoDeEntrega(String pedidoId) async {
    final resposta = await _api.obter('/orders/$pedidoId/delivery/code');
    if (resposta is! Map) {
      throw StateError('Resposta de código de entrega fora do contrato.');
    }
    return CodigoDeEntrega.doJson(Map<String, dynamic>.from(resposta));
  }

  PaginaDePedidos _converter(Object? resposta) {
    final mapa = resposta is Map
        ? Map<String, dynamic>.from(resposta)
        : const <String, dynamic>{};

    return PaginaDePedidos(
      Pagina<Pedido>.doJson(mapa, Pedido.doJson),
      mapa['warning'] as String?,
    );
  }
}
