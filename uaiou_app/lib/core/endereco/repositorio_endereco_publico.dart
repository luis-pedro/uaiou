/// ===============================================================
/// BUSCA DE ENDEREÇO POR COORDENADA
/// ===============================================================
///
/// Dois saltos encadeados:
///
///  1. **`GET /geocoding/reverse` do nosso backend** traduz o ponto
///     tocado no mapa em um `postcode`. Quem fala com o Geoapify é o
///     servidor, com a mesma chave que ele já usa nas rotas de T-25 —
///     o app **não** carrega chave de provedor. Chave embarcada em
///     pacote é extraível por quem quiser, e a cota é da nossa conta.
///  2. **ViaCEP** (`viacep.com.br/ws/{cep}/json/`) troca esse CEP pelo
///     endereço canônico dos Correios — rua, bairro, cidade e UF.
///     Este é chamado direto: é anônimo, sem chave e sem cota, e
///     passar pelo backend só somaria um salto sem ganhar nada.
///
/// O segundo salto existe porque o geocodificador é bom em *localizar*
/// e fraco em *nomear*: devolve o que o mapa tem naquele ponto, que
/// varia de bairro para bairro. O ViaCEP devolve sempre a mesma grafia
/// oficial para um dado CEP — que é o que o estabelecimento espera ver
/// no formulário.
///
/// **Nada disto substitui a coordenada.** O ponto marcado continua
/// sendo a fonte de `lat`/`lng` enviados ao backend (que não
/// geocodifica texto); o endereço resolvido só preenche os campos de
/// texto para o usuário não digitar.
library;

import 'package:dio/dio.dart';

import '../rede/cliente_api.dart';
import 'endereco_publico.dart';

/// Resultado do fluxo completo. Sealed porque cada falha tem um texto
/// diferente na tela: "aqui não tem CEP" não é "a internet caiu".
sealed class ResultadoEndereco {
  const ResultadoEndereco();
}

class EnderecoEncontrado extends ResultadoEndereco {
  final EnderecoPublico endereco;
  const EnderecoEncontrado(this.endereco);
}

/// O ponto existe, mas nenhum dos dois serviços soube dar um CEP —
/// zona rural, área sem mapeamento, meio de uma rodovia. Também é o
/// caminho quando o recurso está desligado no servidor por falta de
/// chave: para quem está no formulário, dá no mesmo.
class EnderecoSemCep extends ResultadoEndereco {
  const EnderecoSemCep();
}

class FalhaAoBuscarEndereco extends ResultadoEndereco {
  final String mensagem;
  const FalhaAoBuscarEndereco(this.mensagem);
}

class RepositorioEnderecoPublico {
  /// Salto 1 fala com a nossa API, então usa o cliente de sempre —
  /// URL base, token e tradução de erro já resolvidos (RF-A01.3).
  final ClienteApi _api;

  /// Salto 2 é destino externo: Dio próprio, **fora** do [ClienteApi].
  /// O ViaCEP não tem o envelope da nossa API e não pode receber o
  /// token de sessão em hipótese nenhuma.
  final Dio _externo;

  RepositorioEnderecoPublico(this._api, {Dio? dioExterno})
    : _externo = dioExterno ?? Dio() {
    _externo.options
      ..connectTimeout = const Duration(seconds: 8)
      ..receiveTimeout = const Duration(seconds: 8)
      ..responseType = ResponseType.json
      ..validateStatus = (_) => true;
  }

  Future<ResultadoEndereco> porCoordenada(double lat, double lng) async {
    final String? cep;
    try {
      cep = await _cepPorCoordenada(lat, lng);
    } catch (_) {
      return const FalhaAoBuscarEndereco(
        'Não foi possível consultar o endereço agora. Verifique a conexão.',
      );
    }
    if (cep == null) return const EnderecoSemCep();

    try {
      final endereco = await porCep(cep);
      // CEP que o geocodificador conhece e o ViaCEP não é comum (CEP
      // novo, ou o CEP geral de cidade pequena). Ainda assim temos o
      // CEP: devolvemos ele sozinho em vez de fingir que nada foi
      // encontrado.
      return EnderecoEncontrado(endereco ?? EnderecoPublico(cep: cep));
    } catch (_) {
      return const FalhaAoBuscarEndereco(
        'Não foi possível consultar o endereço agora. Verifique a conexão.',
      );
    }
  }

  /// Exposto separado porque também serve ao caminho inverso: o
  /// usuário digita o CEP e o formulário completa o resto.
  Future<EnderecoPublico?> porCep(String cepBruto) async {
    final cep = EnderecoPublico.apenasDigitos(cepBruto);
    if (cep.length != 8) return null;

    final resposta = await _externo.get<Object?>(
      'https://viacep.com.br/ws/$cep/json/',
    );
    if (resposta.statusCode != 200) return null;
    return EnderecoPublico.doJsonViaCep(resposta.data);
  }

  /// `postalCode` nulo é resposta legítima do servidor — ponto sem CEP
  /// conhecido, ou recurso desligado por falta de chave —, não erro.
  Future<String?> _cepPorCoordenada(double lat, double lng) async {
    final corpo = await _api.obter(
      '/geocoding/reverse',
      query: {'lat': lat, 'lng': lng},
    );
    if (corpo is! Map) return null;

    final cep = EnderecoPublico.apenasDigitos('${corpo['postalCode'] ?? ''}');
    return cep.length == 8 ? cep : null;
  }
}
