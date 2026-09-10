/// ===============================================================
/// ENDEREÇO RESOLVIDO POR COORDENADA
/// ===============================================================
///
/// Resultado do fluxo `lat/lng -> CEP -> endereço completo`
/// (ver [RepositorioEnderecoPublico]). Dart puro, sem `latlong2` e sem
/// `dio`: o núcleo não sabe qual pacote de mapa ou de rede a tela usa.
library;

class EnderecoPublico {
  /// Só dígitos — `31170000`, nunca `31170-000`. A máscara é
  /// decisão de apresentação, e o backend recebe o CEP como texto
  /// livre; guardar sem máscara evita duas grafias do mesmo dado.
  final String cep;
  final String? rua;
  final String? bairro;
  final String? cidade;
  final String? uf;

  const EnderecoPublico({
    required this.cep,
    this.rua,
    this.bairro,
    this.cidade,
    this.uf,
  });

  /// `viacep.com.br/ws/{cep}/json/`. Devolve `null` quando o corpo é
  /// o `{"erro": true}` que o ViaCEP responde **com HTTP 200** para
  /// CEP inexistente — o status não serve para decidir aqui.
  static EnderecoPublico? doJsonViaCep(Object? json) {
    if (json is! Map) return null;
    if (json['erro'] == true || json['erro'] == 'true') return null;

    final cep = apenasDigitos('${json['cep'] ?? ''}');
    if (cep.length != 8) return null;

    return EnderecoPublico(
      cep: cep,
      rua: _texto(json['logradouro']),
      bairro: _texto(json['bairro']),
      cidade: _texto(json['localidade']),
      uf: _texto(json['uf']),
    );
  }

  static String apenasDigitos(String valor) =>
      valor.replaceAll(RegExp(r'\D'), '');

  static String? _texto(Object? valor) {
    if (valor is! String) return null;
    final limpo = valor.trim();
    return limpo.isEmpty ? null : limpo;
  }

  String get cepFormatado => '${cep.substring(0, 5)}-${cep.substring(5)}';

  /// Uma linha legível para confirmar visualmente o ponto marcado.
  String get resumo => [
    if (rua != null) rua,
    if (bairro != null) bairro,
    if (cidade != null) [cidade, if (uf != null) uf].join('/'),
    cepFormatado,
  ].join(' · ');
}
