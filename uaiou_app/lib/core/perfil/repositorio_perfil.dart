import '../rede/cliente_api.dart';
import '../rede/erros_api.dart';
import 'perfil.dart';

/// Campos cosméticos editáveis por `PATCH /me` — os únicos que a
/// interface oferece (RF-A05.2). `ProfileService.applyCourierProfile`
/// e `applyMerchantProfile` recusam qualquer outro campo enviado por
/// papel errado (400 `PROFILE_FIELD_NOT_APPLICABLE`), e os campos
/// verificados (cpf, cnpj, veículo) exigem upload de comprovação que
/// esta tela não oferece — não é a interface que decide isso, é o
/// contrato: o app só espelha a decisão.
class EdicaoDePerfil {
  final String? nomeExibicao;
  final String? telefone;

  // Estabelecimento — endereço é trocado como grupo pelo backend
  // (`addressProvided`), então ou manda tudo ou nada muda.
  final String? bairro;
  final String? rua;
  final String? numero;
  final String? cidade;
  final String? cep;

  // Par: o backend rejeita um sem o outro (`INCOMPLETE_COORDINATES`).
  final double? lat;
  final double? lng;

  const EdicaoDePerfil({
    this.nomeExibicao,
    this.telefone,
    this.bairro,
    this.rua,
    this.numero,
    this.cidade,
    this.cep,
    this.lat,
    this.lng,
  });

  bool get temEndereco =>
      bairro != null ||
      rua != null ||
      numero != null ||
      cidade != null ||
      cep != null ||
      lat != null ||
      lng != null;

  bool get estaVazia => nomeExibicao == null && telefone == null && !temEndereco;

  /// Só o que mudou — nunca o valor inteiro (RF-A05.2, critério 2).
  Map<String, dynamic> paraJson() {
    final corpo = <String, dynamic>{};
    if (nomeExibicao != null) corpo['displayName'] = nomeExibicao;
    if (telefone != null) corpo['telefone'] = telefone;

    if (temEndereco) {
      corpo['profile'] = {
        if (bairro != null) 'bairro': bairro,
        if (rua != null) 'rua': rua,
        if (numero != null) 'numero': numero,
        if (cidade != null) 'cidade': cidade,
        if (cep != null) 'cep': cep,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };
    }
    return corpo;
  }
}

/// `GET`/`PATCH /me` — `api/usuarios.md`.
class RepositorioPerfil {
  final ClienteApi _api;

  const RepositorioPerfil(this._api);

  Future<Perfil> obter() async {
    final resposta = await _api.obter('/me');
    return _decodificar(resposta);
  }

  Future<Perfil> editar(EdicaoDePerfil edicao) async {
    final resposta = await _api.alterar('/me', corpo: edicao.paraJson());
    return _decodificar(resposta);
  }

  Perfil _decodificar(Object? resposta) {
    if (resposta is! Map) {
      throw const ErroInesperado(mensagem: 'Resposta de perfil fora do contrato.');
    }
    return Perfil.doJson(Map<String, dynamic>.from(resposta));
  }
}

/// Calcula o diff entre o perfil carregado e o que a tela de edição
/// tem agora — só o que mudou vira `EdicaoDePerfil` (RF-A05.2).
///
/// `null` quando nada mudou: a tela usa isso para desabilitar o
/// botão de salvar em vez de mandar um PATCH vazio.
EdicaoDePerfil? diffDeEdicao({
  required Perfil original,
  required String nomeExibicao,
  required String telefone,
  String? bairro,
  String? rua,
  String? numero,
  String? cidade,
  String? cep,
  double? lat,
  double? lng,
}) {
  final endereco = original.detalhes?.endereco;

  String? seMudou(String novo, String? antigo) =>
      novo != (antigo ?? '') ? novo : null;

  // Coordenada não é texto: manda o par inteiro sempre que o mapa foi
  // tocado, em vez de comparar ponto flutuante contra o valor salvo.
  final coordenadaMudou =
      lat != null && lng != null && (lat != endereco?.lat || lng != endereco?.lng);

  final edicao = EdicaoDePerfil(
    nomeExibicao: seMudou(nomeExibicao, original.nomeExibicao),
    telefone: seMudou(telefone, original.telefone),
    bairro: seMudou(bairro ?? '', endereco?.bairro),
    rua: seMudou(rua ?? '', endereco?.rua),
    numero: seMudou(numero ?? '', endereco?.numero),
    cidade: seMudou(cidade ?? '', endereco?.cidade),
    cep: seMudou(cep ?? '', endereco?.cep),
    lat: coordenadaMudou ? lat : null,
    lng: coordenadaMudou ? lng : null,
  );

  return edicao.estaVazia ? null : edicao;
}
