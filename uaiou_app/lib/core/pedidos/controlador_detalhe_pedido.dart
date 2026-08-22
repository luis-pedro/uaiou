import 'package:flutter/foundation.dart';

import '../estado/carregavel.dart';
import '../rede/erros_api.dart';
import '../../others/pedido.dart';
import 'contraoferta.dart';
import 'repositorio_pedidos.dart';

/// ===============================================================
/// DETALHE DO PEDIDO — RF-A10.6/RF-A10.7/RF-A10.8
/// ===============================================================
///
/// Junta `GET /orders/{id}` com as contraofertas recebidas
/// (`GET /orders/{id}/counteroffers`) e o código de entrega
/// (`GET /orders/{id}/delivery/code`). Estado e transições vêm do
/// pedido lido do servidor (`_links`), com recarga manual — push é
/// A-11, fora de escopo.
class ControladorDetalhePedido extends ChangeNotifier {
  final RepositorioPedidos _repositorio;
  final String pedidoId;

  ControladorDetalhePedido(this._repositorio, {required this.pedidoId});

  Carregavel<Pedido> _estado = const Carregando();
  Carregavel<Pedido> get estado => _estado;
  Pedido? get pedido => _estado.valorOuNulo;

  List<Contraoferta> _contraofertas = const [];
  List<Contraoferta> get contraofertas => _contraofertas;
  List<Contraoferta> get contraofertasPendentes =>
      _contraofertas.where((c) => c.pendente).toList();

  /// Código de entrega — só carregado sob demanda (RF-A10.7): pedir
  /// antes do pedido estar aceito só gastaria uma chamada fadada ao
  /// 403/404.
  CodigoDeEntrega? _codigo;
  CodigoDeEntrega? get codigo => _codigo;
  bool _carregandoCodigo = false;
  bool get carregandoCodigo => _carregandoCodigo;
  String? _erroCodigo;
  String? get erroCodigo => _erroCodigo;

  /// Id da contraoferta em decisão — guarda de reentrância (mesmo
  /// padrão de `ControladorVitrine`).
  String? _decidindoId;
  bool decidindo(String contraofertaId) => _decidindoId == contraofertaId;

  String? _aviso;
  String? get aviso => _aviso;
  void limparAviso() {
    if (_aviso == null) return;
    _aviso = null;
    notifyListeners();
  }

  Future<void> carregar() async {
    _estado = const Carregando();
    notifyListeners();
    await _buscar();
  }

  Future<void> recarregar() => _buscar();

  Future<void> _buscar() async {
    try {
      final pedido = await _repositorio.obter(pedidoId);
      _estado = Pronto(pedido);
      // RF-A10.6 — contraofertas só existem enquanto o pedido ainda
      // aguarda entregador (publicado ou em negociação); fora disso a
      // rota do servidor devolve lista vazia, e a chamada é evitada.
      _contraofertas = pedido.status.aguardandoEntregador
          ? await _repositorio.obterContraofertas(pedidoId)
          : const [];
    } on ErroApi catch (erro) {
      _estado = Falhou(erro);
    } finally {
      notifyListeners();
    }
  }

  Future<void> carregarCodigo() async {
    if (_carregandoCodigo) return;
    _carregandoCodigo = true;
    _erroCodigo = null;
    notifyListeners();
    try {
      _codigo = await _repositorio.obterCodigoDeEntrega(pedidoId);
    } on ErroApi catch (erro) {
      _erroCodigo = erro.mensagemParaUsuario;
    } finally {
      _carregandoCodigo = false;
      notifyListeners();
    }
  }

  /// RF-A10.6 — aceita ou recusa. O app não replica a invalidação em
  /// cascata das demais propostas (T-14): só recarrega o pedido para
  /// refletir o resultado.
  Future<bool> decidir(String contraofertaId, {required bool aceitar}) async {
    if (_decidindoId != null) return false;

    _decidindoId = contraofertaId;
    _aviso = null;
    notifyListeners();

    try {
      await _repositorio.decidirContraoferta(contraofertaId, aceitar: aceitar);
      await _buscar();
      return true;
    } on ErroApi catch (erro) {
      _aviso = erro.mensagemParaUsuario;
      return false;
    } finally {
      _decidindoId = null;
      notifyListeners();
    }
  }
}
