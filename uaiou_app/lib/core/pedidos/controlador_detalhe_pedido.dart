import 'dart:async';

import 'package:flutter/foundation.dart';

import '../estado/carregavel.dart';
import '../rede/erros_api.dart';
import '../../others/pedido.dart';
import 'contraoferta.dart';
import 'motivos.dart';
import 'repositorio_pedidos.dart';

/// RF-A15.2 — enquanto o pedido aguarda coleta, o detalhe se atualiza
/// sozinho: a chegada do entregador não pode depender de puxar a tela.
const Duration _intervaloAguardandoColeta = Duration(seconds: 10);

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

  Timer? _pollTimer;

  bool _executandoAcao = false;
  bool get executandoAcao => _executandoAcao;

  bool get podeConfirmarColeta => pedido?.links.permite('pickupConfirmation') ?? false;
  bool get podeCancelar => pedido?.links.permite('cancellation') ?? false;

  /// RF-A15.1/RF-A15.2 — confirma que o pacote foi entregue ao
  /// entregador. 409/422 (corrida perdida, entregador fora do raio)
  /// recarregam e mostram a mensagem do servidor (RF-A15.7).
  Future<bool> confirmarColeta() => _acao(() async {
    await _repositorio.confirmarColeta(pedidoId);
    _aviso = 'Coleta confirmada.';
  });

  /// RF-A15.4/RF-A15.5 — cancela com motivo; a taxa, se houver, vem
  /// na resposta.
  Future<bool> cancelar(MotivoCancelamento motivo, {String? observacao}) =>
      _acao(() async {
        final taxa = await _repositorio.cancelar(
          pedidoId,
          motivo: motivo,
          observacao: observacao,
        );
        _aviso = taxa == null
            ? 'Pedido cancelado.'
            : 'Pedido cancelado. Taxa de ${taxa.formatarBRL()} a pagar ao entregador.';
      });

  Future<bool> _acao(Future<void> Function() executar) async {
    if (_executandoAcao) return false;
    _executandoAcao = true;
    notifyListeners();
    try {
      await executar();
      return true;
    } on ErroApi catch (erro) {
      _aviso = erro.mensagemParaUsuario;
      return false;
    } finally {
      _executandoAcao = false;
      await _buscar();
    }
  }

  void _ajustarPolling(Pedido pedido) {
    final aguardando = pedido.status == StatusPedido.aceito;
    if (aguardando && _pollTimer == null) {
      _pollTimer = Timer.periodic(_intervaloAguardandoColeta, (_) => _buscar());
    } else if (!aguardando) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _buscar() async {
    try {
      final pedido = await _repositorio.obter(pedidoId);
      _estado = Pronto(pedido);
      _ajustarPolling(pedido);
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
