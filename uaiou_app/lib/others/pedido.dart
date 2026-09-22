import '../core/modelos/dinheiro.dart';
import '../core/modelos/links.dart';
import '../core/modelos/status_pedido.dart';

export '../core/modelos/status_pedido.dart';

/// ===============================================================
/// MODELO DOS PEDIDOS
/// ===============================================================
///
/// Espelha `OrderSummary`/`OrderResponse` de `api/pedidos.md`.
///
/// > Corrigido em A-03: a A-01 adivinhou nomes de campo
/// > (`displayNumber`, `deliveryAddress`) que não existem no
/// > contrato. Os corretos são `number` e `destination`.
///
/// Campos anuláveis não são descuido: **a vitrine do entregador
/// devolve só o bairro** (RF-11.6). Rua, número e coordenadas só
/// aparecem no pedido já aceito — endereço completo não é dado de
/// lista pública.
class Pedido {
  /// UUID do servidor. Fonte de verdade para qualquer rota.
  final String id;

  /// Número curto de exibição, gerado pelo servidor (`number`).
  final String? numero;

  final StatusPedido status;

  /// Frete proposto pelo estabelecimento.
  final Dinheiro freteProposto;

  /// Frete efetivamente acordado. Só existe depois da negociação.
  final Dinheiro? freteFinal;

  /// Modo feira (docs/feira/): o prêmio em texto ("1 Bis"). Nulo em pedido do
  /// produto. Onde existe, é ele que a tela mostra no lugar do frete — que na
  /// feira é sempre zero e não diz nada a quem está jogando.
  final String? feiraRecompensa;

  /// Onde fica o estabelecimento — a perna 1 da entrega. No produto isso vinha
  /// da rota; no modo feira não há rota, e é daqui que sai o pino da coleta.
  final double? estabelecimentoLat;
  final double? estabelecimentoLong;

  final String? rua;
  final String? numeroEndereco;
  final String? complemento;
  final String? bairro;
  final double? latitude;
  final double? longitude;

  /// Estabelecimento que publicou. Nulo nas listas do próprio
  /// estabelecimento — ele não precisa do próprio nome em cada linha.
  final String? nomeEstabelecimento;

  /// Distância até o pedido, em km. Só o entregador recebe (RF-11.7).
  final double? distanciaKm;

  /// Criação, em fuso local.
  final DateTime criadoEm;

  /// Instante do aceite — âncora do "tempo decorrido" (RF-13.8).
  /// O servidor manda o instante, não os minutos, porque minuto
  /// congelado na resposta já nasce errado.
  final DateTime? aceitoEm;

  /// Só presente no detalhe (`GET /orders/{id}`/`POST /orders`) —
  /// `OrderResponse`, não `OrderSummary`.
  final DateTime? prazoEsperado;
  final String? recebedorNome;
  final String? recebedorTelefone;
  final String? entregadorId;
  final String? nomeEntregador;
  final int? creditosConsumidos;

  /// T-26 — entregador entrou no raio do estabelecimento.
  final DateTime? chegouEm;

  /// T-26 — estabelecimento confirmou a coleta.
  final DateTime? coletadoEm;

  /// RF-26.6 — identifica o entregador na porta da loja.
  final String? placaEntregador;

  /// URLs de leitura com validade curta — recarregar o pedido renova.
  final String? fotoEntregador;
  final String? logoEstabelecimento;

  /// RF-A15.5 — taxa que o estabelecimento pagaria cancelando agora.
  /// Vem pronta do servidor; o app não aplica percentual.
  final Dinheiro? taxaCancelamentoPendente;

  /// RF-A15.6 — sem coordenada da loja não há aviso de chegada.
  final bool localizacaoRetiradaConhecida;

  /// Código do motivo, quando cancelado.
  final String? motivoCancelamento;

  /// Transições permitidas pelo servidor neste estado, para este
  /// papel (RF-A03.8).
  final Links links;

  const Pedido({
    required this.id,
    required this.status,
    required this.criadoEm,
    this.numero,
    this.freteProposto = Dinheiro.zero,
    this.freteFinal,
    this.feiraRecompensa,
    this.estabelecimentoLat,
    this.estabelecimentoLong,
    this.rua,
    this.numeroEndereco,
    this.complemento,
    this.bairro,
    this.latitude,
    this.longitude,
    this.nomeEstabelecimento,
    this.distanciaKm,
    this.aceitoEm,
    this.prazoEsperado,
    this.recebedorNome,
    this.recebedorTelefone,
    this.entregadorId,
    this.nomeEntregador,
    this.creditosConsumidos,
    this.chegouEm,
    this.coletadoEm,
    this.placaEntregador,
    this.fotoEntregador,
    this.logoEstabelecimento,
    this.taxaCancelamentoPendente,
    this.localizacaoRetiradaConhecida = true,
    this.motivoCancelamento,
    this.links = Links.vazio,
  });

  factory Pedido.doJson(Map<String, dynamic> json) {
    final destino = json['destination'] is Map
        ? Map<String, dynamic>.from(json['destination'] as Map)
        : const <String, dynamic>{};

    final estabelecimento = json['merchant'] is Map
        ? Map<String, dynamic>.from(json['merchant'] as Map)
        : const <String, dynamic>{};

    final recebedor = json['receiver'] is Map
        ? Map<String, dynamic>.from(json['receiver'] as Map)
        : const <String, dynamic>{};

    final entregador = json['courier'] is Map
        ? Map<String, dynamic>.from(json['courier'] as Map)
        : const <String, dynamic>{};

    return Pedido(
      id: json['id'] as String,
      numero: json['number'] as String?,
      status: StatusPedido.doContrato(json['status']),
      freteProposto:
          Dinheiro.tentarDeString(json['proposedFee']?.toString()) ??
          Dinheiro.zero,
      freteFinal: Dinheiro.tentarDeString(json['finalFee']?.toString()),
      feiraRecompensa: json['feiraRecompensa'] as String?,
      estabelecimentoLat: _decimal(estabelecimento['lat']),
      estabelecimentoLong: _decimal(estabelecimento['lng']),
      rua: destino['street'] as String?,
      numeroEndereco: destino['number']?.toString(),
      complemento: destino['complement'] as String?,
      bairro: destino['district'] as String?,
      latitude: _decimal(destino['lat']),
      longitude: _decimal(destino['lng']),
      nomeEstabelecimento: estabelecimento['name'] as String?,
      distanciaKm: _decimal(json['distanceKm']),
      criadoEm: _dataLocal(json['createdAt']) ?? DateTime.now(),
      aceitoEm: _dataLocal(json['acceptedAt']),
      prazoEsperado: _dataLocal(json['expectedDeliveryAt']),
      recebedorNome: recebedor['name'] as String?,
      recebedorTelefone: recebedor['phone'] as String?,
      entregadorId: entregador['id'] as String?,
      nomeEntregador: entregador['name'] as String?,
      creditosConsumidos: (json['creditsConsumed'] as num?)?.toInt(),
      chegouEm: _dataLocal(json['arrivedAt']),
      coletadoEm: _dataLocal(json['pickedUpAt']),
      placaEntregador: entregador['vehiclePlate'] as String?,
      fotoEntregador: entregador['photoUrl'] as String?,
      logoEstabelecimento: estabelecimento['logoUrl'] as String?,
      taxaCancelamentoPendente: Dinheiro.tentarDeString(
        json['pendingCancellationFee']?.toString(),
      ),
      // Ausente na listagem (`OrderSummary`): assume conhecida para não
      // exibir aviso falso fora do detalhe.
      localizacaoRetiradaConhecida: json['pickupLocationKnown'] != false,
      motivoCancelamento: json['cancellation'] is Map
          ? (json['cancellation'] as Map)['reason'] as String?
          : null,
      links: Links.doJson(json['_links']),
    );
  }

  /// T-26 — entregador na porta e pedido ainda sem coleta.
  bool get entregadorAguardandoNaLoja =>
      status == StatusPedido.aceito && chegouEm != null;

  /// Valor que vale para este pedido: o acordado, se já houve
  /// negociação; senão, o proposto.
  Dinheiro get valor => freteFinal ?? freteProposto;

  /// O que a tela deve mostrar como "quanto vale": prêmio na feira, frete no
  /// produto.
  String get valorExibido => feiraRecompensa ?? valor.formatarBRL();

  /// O que a tela mostra como "Pedido X".
  ///
  /// UUID inteiro não cabe na interface nem ajuda a identificar a
  /// entrega; sem número do servidor, usa os últimos caracteres.
  String get rotuloCurto {
    final doServidor = numero;
    if (doServidor != null && doServidor.isNotEmpty) return doServidor;

    final limpo = id.replaceAll('-', '');
    return limpo.length <= 6
        ? limpo.toUpperCase()
        : limpo.substring(limpo.length - 6).toUpperCase();
  }

  /// Endereço no maior detalhe que o servidor entregou.
  ///
  /// Na vitrine isso é só o bairro, de propósito — ver doc da classe.
  String get enderecoResumido {
    final partes = <String>[
      if (rua != null && rua!.isNotEmpty)
        [rua, numeroEndereco].whereType<String>().join(', '),
      if (bairro != null && bairro!.isNotEmpty) bairro!,
    ];
    return partes.isEmpty ? 'Endereço não informado' : partes.join(' — ');
  }

  bool get temEnderecoCompleto => rua != null && rua!.isNotEmpty;

  /// Minutos desde o aceite, calculados na leitura (RF-13.8).
  int? get minutosDesdeAceite {
    final aceite = aceitoEm;
    if (aceite == null) return null;
    return DateTime.now().difference(aceite).inMinutes;
  }

  static double? _decimal(Object? bruto) => switch (bruto) {
    final num v => v.toDouble(),
    final String v => double.tryParse(v),
    _ => null,
  };

  static DateTime? _dataLocal(Object? bruto) {
    if (bruto is! String) return null;
    return DateTime.tryParse(bruto)?.toLocal();
  }
}
