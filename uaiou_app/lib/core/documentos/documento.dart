import '../uploads/repositorio_uploads.dart';

/// Estado de aprovação de um documento de cadastro (T-06/T-07).
enum StatusDocumento {
  pendente('pending', 'Em análise'),
  aprovado('approved', 'Aprovado'),
  rejeitado('rejected', 'Rejeitado'),

  /// Substituído por um reenvio — **nunca foi negado**, só deixou de
  /// ser a versão vigente. Não é erro, e a interface não deve mostrar
  /// como se fosse.
  superado('superseded', 'Substituído'),

  desconhecido('', '—');

  const StatusDocumento(this.noContrato, this.rotulo);

  final String noContrato;
  final String rotulo;

  static StatusDocumento doContrato(Object? bruto) {
    if (bruto is! String) return desconhecido;
    final valor = bruto.trim().toLowerCase();
    for (final s in values) {
      if (s.noContrato.isNotEmpty && s.noContrato == valor) return s;
    }
    return desconhecido;
  }

  bool get exigeAcao => this == rejeitado;
}

class Documento {
  final String id;
  final PropositoUpload tipo;
  final StatusDocumento status;

  /// Preenchido quando [status] é [StatusDocumento.rejeitado] — é o
  /// que RF-A04.8 exige mostrar, senão o usuário fica sem saída.
  final String? motivoDaRejeicao;

  final DateTime? enviadoEm;

  const Documento({
    required this.id,
    required this.tipo,
    required this.status,
    this.motivoDaRejeicao,
    this.enviadoEm,
  });

  factory Documento.doJson(Map<String, dynamic> json) => Documento(
    id: json['id'] as String? ?? '',
    tipo: PropositoUpload.doContrato(json['type']),
    status: StatusDocumento.doContrato(json['status']),
    motivoDaRejeicao: json['rejectionReason'] as String?,
    enviadoEm: switch (json['createdAt']) {
      final String v => DateTime.tryParse(v)?.toLocal(),
      _ => null,
    },
  );
}

/// Resposta de `GET /me/documents`.
class SituacaoDocumental {
  final List<Documento> documentos;

  /// RF-06.1 — o que ainda falta **para o papel do usuário**. É o
  /// servidor dizendo à interface o que pedir; o app não mantém a
  /// própria lista de documentos exigidos por papel.
  final List<PropositoUpload> faltando;

  const SituacaoDocumental({required this.documentos, required this.faltando});

  factory SituacaoDocumental.doJson(Map<String, dynamic> json) {
    final brutos = json['documents'];
    final ausentes = json['missingTypes'];

    return SituacaoDocumental(
      documentos: brutos is List
          ? brutos
                .whereType<Map>()
                .map((d) => Documento.doJson(Map<String, dynamic>.from(d)))
                .toList()
          : const [],
      faltando: ausentes is List
          ? ausentes
                .map(PropositoUpload.doContrato)
                .where((p) => p != PropositoUpload.desconhecido)
                .toList()
          : const [],
    );
  }

  /// Versões vigentes: o que foi substituído não interessa à tela.
  List<Documento> get vigentes =>
      documentos.where((d) => d.status != StatusDocumento.superado).toList();

  List<Documento> get rejeitados =>
      vigentes.where((d) => d.status == StatusDocumento.rejeitado).toList();

  /// Nada faltando e nada rejeitado — só resta a moderação decidir.
  bool get completo => faltando.isEmpty && rejeitados.isEmpty;

  /// O que a tela precisa pedir agora: o que falta mais o que voltou
  /// rejeitado.
  List<PropositoUpload> get aEnviar => [
    ...faltando,
    ...rejeitados.map((d) => d.tipo),
  ];
}
