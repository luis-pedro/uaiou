import '../modelos/links.dart';
import '../sessao/identidade.dart';

/// ===============================================================
/// PERFIL — `GET`/`PATCH /me` (RF-A05.1)
/// ===============================================================
///
/// Espelha `MeResponse`/`MeProfile` do backend (`users/dto`), **não**
/// o exemplo simplificado de `usuarios.md`: o DTO real trafega
/// `telefone` (fora do doc) e não trafega `fotoUrl` nem `cidade` para
/// o entregador — só o estabelecimento tem endereço e logo.
class LocalizacaoEntregador {
  final double lat;
  final double lng;
  final DateTime? atualizadoEm;

  const LocalizacaoEntregador({
    required this.lat,
    required this.lng,
    this.atualizadoEm,
  });

  factory LocalizacaoEntregador.doJson(Map<String, dynamic> json) =>
      LocalizacaoEntregador(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        atualizadoEm: switch (json['updatedAt']) {
          final String v => DateTime.tryParse(v)?.toLocal(),
          _ => null,
        },
      );
}

class EnderecoEstabelecimento {
  final String? bairro;
  final String? rua;
  final String? numero;
  final String? cidade;
  final String? cep;

  /// Diferente do destino do pedido (geocodificado na criação), o
  /// endereço do estabelecimento nunca é geocodificado pelo servidor
  /// — `null` até o próprio estabelecimento marcar no mapa.
  final double? lat;
  final double? lng;

  const EnderecoEstabelecimento({
    this.bairro,
    this.rua,
    this.numero,
    this.cidade,
    this.cep,
    this.lat,
    this.lng,
  });

  factory EnderecoEstabelecimento.doJson(Map<String, dynamic> json) =>
      EnderecoEstabelecimento(
        bairro: json['bairro'] as String?,
        rua: json['rua'] as String?,
        numero: json['numero'] as String?,
        cidade: json['cidade'] as String?,
        cep: json['cep'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
      );

  bool get estaVazio =>
      bairro == null &&
      rua == null &&
      numero == null &&
      cidade == null &&
      cep == null &&
      lat == null &&
      lng == null;

  bool get temCoordenada => lat != null && lng != null;
}

/// `profile` — os campos que não se aplicam ao papel vêm nulos do
/// contrato (um único formato para os dois papéis).
class PerfilDetalhado {
  // Entregador
  final String? cpf;
  final String? tipoDeVeiculo;
  final String? placaDoVeiculo;
  final bool? disponivel;
  final LocalizacaoEntregador? localizacao;
  final int? entregasConcluidas;

  // Estabelecimento
  final String? cnpj;
  final String? nomeDoNegocio;
  final String? logoObjectKey;
  final EnderecoEstabelecimento? endereco;

  // Comum
  final String? score;

  const PerfilDetalhado({
    this.cpf,
    this.tipoDeVeiculo,
    this.placaDoVeiculo,
    this.disponivel,
    this.localizacao,
    this.entregasConcluidas,
    this.cnpj,
    this.nomeDoNegocio,
    this.logoObjectKey,
    this.endereco,
    this.score,
  });

  factory PerfilDetalhado.doJson(Map<String, dynamic> json) => PerfilDetalhado(
    cpf: json['cpf'] as String?,
    tipoDeVeiculo: json['vehicleType'] as String?,
    placaDoVeiculo: json['vehiclePlate'] as String?,
    disponivel: json['available'] as bool?,
    localizacao: json['location'] is Map
        ? LocalizacaoEntregador.doJson(Map<String, dynamic>.from(json['location'] as Map))
        : null,
    entregasConcluidas: (json['completedDeliveries'] as num?)?.toInt(),
    cnpj: json['cnpj'] as String?,
    nomeDoNegocio: json['businessName'] as String?,
    logoObjectKey: json['logoObjectKey'] as String?,
    endereco: json['address'] is Map
        ? EnderecoEstabelecimento.doJson(Map<String, dynamic>.from(json['address'] as Map))
        : null,
    score: json['score'] as String?,
  );
}

/// Resposta de `GET /me` e `PATCH /me`.
class Perfil {
  final String id;
  final Papel papel;
  final StatusConta status;
  final String nomeExibicao;
  final String email;
  final String? telefone;
  final PerfilDetalhado? detalhes;

  /// `null` em `GET` (nunca perguntou); lista (possivelmente vazia) em
  /// `PATCH` — o servidor diz o que ficou pendente de moderação.
  final List<String>? camposPendentes;

  final Links links;

  const Perfil({
    required this.id,
    required this.papel,
    required this.status,
    required this.nomeExibicao,
    required this.email,
    this.telefone,
    this.detalhes,
    this.camposPendentes,
    this.links = Links.vazio,
  });

  factory Perfil.doJson(Map<String, dynamic> json) => Perfil(
    id: json['id'] as String? ?? '',
    papel: Papel.doContrato(json['role']),
    status: StatusConta.doContrato(json['status']),
    nomeExibicao: json['displayName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    telefone: json['telefone'] as String?,
    detalhes: json['profile'] is Map
        ? PerfilDetalhado.doJson(Map<String, dynamic>.from(json['profile'] as Map))
        : null,
    camposPendentes: json['pendingFields'] is List
        ? List<String>.from(json['pendingFields'] as List)
        : null,
    links: Links.doJson(json['_links']),
  );
}
