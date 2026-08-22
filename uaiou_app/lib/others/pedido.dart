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
      links: Links.doJson(json['_links']),
    );
  }

  /// Valor que vale para este pedido: o acordado, se já houve
  /// negociação; senão, o proposto.
  Dinheiro get valor => freteFinal ?? freteProposto;

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
