import 'package:flutter/foundation.dart';

import 'package:uaiou/main.dart' show feiraNestaBranch;

import '../estado/carregavel.dart';
import '../rede/erros_api.dart';
import 'modelo_rota.dart';
import 'repositorio_rotas.dart';

/// Afastamento do traçado, em metros, a partir do qual o entregador é
/// considerado fora da rota planejada. Maior que o erro típico de GPS
/// urbano para não recalcular por ruído.
const double desvioParaRecalcularMetros = 80;

/// Intervalo mínimo entre dois recálculos automáticos — é o teto de
/// consumo do provedor (RNF-A14.1): no pior caso, uma chamada por
/// intervalo enquanto o entregador estiver fora do caminho.
const Duration intervaloMinimoEntreRecalculos = Duration(seconds: 45);

/// ===============================================================
/// ROTA DA ENTREGA — A-14
/// ===============================================================
///
/// **RNF-A14.1 — consumo com teto.** [carregar] é idempotente por
/// pedido: chamada de novo com o mesmo id enquanto o resultado já está
/// em mãos, não vai à rede. O traçado não pega carona no polling de 10s
/// da entrega (A-08).
///
/// **A origem é o GPS do aparelho.** Toda consulta leva a posição lida
/// agora, quando existe; a posição salva no servidor só é usada como
/// último recurso. [acompanhar] recalcula sozinho quando o entregador
/// sai do traçado ou quando a rota não pôde ser feita por falta de
/// posição — sempre limitado por [intervaloMinimoEntreRecalculos].
///
/// **RF-A14.6 — falha não contamina a tela.** Erro aqui vira "sem
/// rota", e a tela de entrega continua com mapa, código e finalização.
class ControladorRota extends ChangeNotifier {
  final RepositorioRotas _repositorio;
  final DateTime Function() _agora;

  /// Modo feira (docs/feira/): desligado, o controlador vira inerte e nenhuma
  /// consulta de roteamento sai do app. Injetável para os testes do produto
  /// continuarem exercitando o cálculo de verdade nesta branch.
  final bool calculaRota;

  ControladorRota({
    required RepositorioRotas repositorio,
    DateTime Function()? agora,
    this.calculaRota = !feiraNestaBranch,
  }) : _repositorio = repositorio,
       _agora = agora ?? DateTime.now;

  String? _pedidoId;
  String? get pedidoId => _pedidoId;

  Carregavel<RotaDoPedido> _estado = const Carregando();
  Carregavel<RotaDoPedido> get estado => _estado;
  RotaDoPedido? get rota => _estado.valorOuNulo;

  /// Quantas vezes o servidor foi consultado — existe para o teste do
  /// critério de aceite 9 poder afirmar que reabrir a tela não dispara
  /// chamada por ciclo de polling.
  int get consultasFeitas => _consultas;
  int _consultas = 0;

  bool _buscando = false;
  bool get buscando => _buscando;

  PontoGeo? _ultimaOrigem;
  DateTime? _ultimaBusca;

  Future<void> carregar(String pedidoId, {PontoGeo? origem}) async {
    if (_pedidoId == pedidoId && _estado.temConteudo) return;
    if (_pedidoId != pedidoId) {
      _estado = const Carregando();
      notifyListeners();
    }
    _pedidoId = pedidoId;
    await _buscar(origem ?? _ultimaOrigem);
  }

  /// Recarga explícita (gesto do usuário ou mudança de fase da entrega).
  Future<void> recarregar({PontoGeo? origem}) async {
    if (_pedidoId == null) return;
    await _buscar(origem ?? _ultimaOrigem);
  }

  /// Chamado a cada nova leitura de GPS. Guarda a posição para as
  /// próximas consultas e decide, com teto, se vale recalcular.
  Future<void> acompanhar(PontoGeo posicao) async {
    _ultimaOrigem = posicao;
    if (_pedidoId == null || _buscando || !_precisaRecalcular(posicao)) return;

    final ultima = _ultimaBusca;
    if (ultima != null &&
        _agora().difference(ultima) < intervaloMinimoEntreRecalculos) {
      return;
    }
    await _buscar(posicao);
  }

  bool _precisaRecalcular(PontoGeo posicao) {
    return switch (_estado) {
      // Rota falhou ou saiu sem traçado por falta de posição: agora há.
      Falhou() => true,
      Pronto(:final valor) when !valor.temTracado =>
        valor.trajeto.motivoIndisponivel == 'COURIER_LOCATION_UNKNOWN',
      Pronto(:final valor) => _foraDoTracado(valor.trajeto, posicao),
      _ => false,
    };
  }

  bool _foraDoTracado(Trajeto trajeto, PontoGeo posicao) {
    final indice = trajeto.indiceMaisProximoDe(posicao);
    return posicao.metrosAte(trajeto.geometria[indice]) >
        desvioParaRecalcularMetros;
  }

  Future<void> _buscar(PontoGeo? origem) async {
    // Modo feira (docs/feira/): ninguém pede rota. O evento inteiro cabe num
    // salão, onde o traçado seria um rabisco de dez metros e as instruções de
    // navegação ("siga 15 m e vire à direita") beiram o cômico — e cada
    // consulta ainda custa uma chamada ao provedor de roteamento. O mapa
    // continua mostrando a posição ao vivo e o ponto; é disso que a
    // demonstração precisa.
    //
    // Barrado aqui, no único ponto por onde toda consulta passa, em vez de em
    // cada chamador: `carregar`, `recarregar` e `acompanhar` desembocam todos
    // neste método.
    // Termina em "sem rota", nunca em "carregando": quem desenha o painel
    // mostraria um spinner eterno se o estado ficasse pendurado.
    if (!calculaRota) {
      if (_estado is! Vazio<RotaDoPedido>) {
        _estado = const Vazio();
        notifyListeners();
      }
      return;
    }

    final id = _pedidoId;
    if (id == null) return;
    _consultas++;
    _buscando = true;
    _ultimaBusca = _agora();
    notifyListeners();
    try {
      final nova = await _repositorio.obter(id, origem: origem);
      // Recálculo que falhou não apaga um traçado bom já em mãos.
      if (nova.temTracado || !_estado.temConteudo) _estado = Pronto(nova);
    } on ErroApi catch (erro) {
      if (!_estado.temConteudo) _estado = Falhou(erro);
    } finally {
      _buscando = false;
      notifyListeners();
    }
  }

  /// RF-A03.9 — troca de conta não herda a rota da conta anterior.
  void limpar() {
    _pedidoId = null;
    _estado = const Carregando();
    _consultas = 0;
    _ultimaOrigem = null;
    _ultimaBusca = null;
  }
}
