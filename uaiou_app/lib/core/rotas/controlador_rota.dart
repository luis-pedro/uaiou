import 'package:flutter/foundation.dart';

import '../estado/carregavel.dart';
import '../rede/erros_api.dart';
import 'modelo_rota.dart';
import 'repositorio_rotas.dart';

/// ===============================================================
/// ROTA DA ENTREGA — A-14
/// ===============================================================
///
/// **RNF-A14.1 — uma rota por abertura de tela.** [carregar] é
/// idempotente por pedido: chamada de novo com o mesmo id enquanto o
/// resultado já está em mãos, não vai à rede. É isso que impede o
/// traçado de pegar carona no polling de 10s da entrega (A-08) e
/// queimar cota do provedor sem informar nada novo — rota é dado
/// estável, estado de entrega é que muda.
///
/// **RF-A14.6 — falha não contamina a tela.** Erro aqui vira "sem
/// rota", e a tela de entrega continua com mapa, código e finalização.
/// Por isso o controlador guarda o erro para consulta e nunca o
/// propaga como exceção.
class ControladorRota extends ChangeNotifier {
  final RepositorioRotas _repositorio;

  ControladorRota({required RepositorioRotas repositorio})
    : _repositorio = repositorio;

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

  Future<void> carregar(String pedidoId) async {
    if (_pedidoId == pedidoId && _estado.temConteudo) return;
    if (_pedidoId != pedidoId) {
      _estado = const Carregando();
      notifyListeners();
    }
    _pedidoId = pedidoId;
    await _buscar();
  }

  /// Recarga explícita (gesto do usuário) — a única forma de ir à rede
  /// de novo para o mesmo pedido.
  Future<void> recarregar() async {
    if (_pedidoId == null) return;
    await _buscar();
  }

  Future<void> _buscar() async {
    final id = _pedidoId;
    if (id == null) return;
    _consultas++;
    try {
      _estado = Pronto(await _repositorio.obter(id));
    } on ErroApi catch (erro) {
      _estado = Falhou(erro);
    } finally {
      notifyListeners();
    }
  }

  /// RF-A03.9 — troca de conta não herda a rota da conta anterior.
  void limpar() {
    _pedidoId = null;
    _estado = const Carregando();
    _consultas = 0;
  }
}
