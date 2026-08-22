import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/estatisticas/repositorio_estatisticas.dart';
import '../core/modelos/dinheiro.dart';
import '../core/pedidos/lista_de_pedidos.dart';
import '../core/pedidos/repositorio_pedidos.dart';
import '../core/rede/erros_api.dart';
import '../core/sessao/controlador_sessao.dart';
import 'pedido.dart';

/// ===============================================================
/// ESTADO DO ESTABELECIMENTO — RF-A03.2
/// ===============================================================
///
/// Substitui o antigo `EstabelecimentoService.instance`.
///
/// O que sumiu aqui, de propósito:
///
/// - **`adicionarPedido`** (RF-A03.4): criava pedido na memória do app
///   com número autoincrementado a partir de 6246. A criação real é
///   `POST /orders`, em [A-10].
/// - **`faturamentoHoje`** (RF-A03.5/RF-A10.10): somava `double` de
///   uma lista local e inferia "hoje" pelo relógio do aparelho. O
///   agregado vem de `GET /me/stats` e `GET /me/payables`.
class EstadoEstabelecimento extends ChangeNotifier {
  final ControladorSessao _sessao;
  final RepositorioEstatisticas _estatisticas;

  /// `GET /orders` — o servidor já devolve só os próprios pedidos
  /// deste estabelecimento (RF-11.6).
  final ListaDePedidos pedidos;

  EstadoEstabelecimento({
    required RepositorioPedidos repositorio,
    required ControladorSessao sessao,
    required RepositorioEstatisticas estatisticas,
  }) : _sessao = sessao,
       _estatisticas = estatisticas,
       pedidos = ListaDePedidos(repositorio) {
    // Ver a nota em EstadoEntregador: sem repassar a notificação da
    // lista, a tela que observa só esta loja fica girando para sempre.
    pedidos.addListener(notifyListeners);
  }

  @override
  void dispose() {
    pedidos.removeListener(notifyListeners);
    super.dispose();
  }

  /// Nome vem da sessão (A-02); cidade e logo são de `GET /me` (A-05).
  String get nome => _sessao.usuario?.nomeExibicao ?? '';

  /// RF-A10.10 — `freightSpend` de `GET /me/stats` (`MerchantStatsResponse`).
  /// `null` até a primeira carga responder; nunca uma soma feita aqui.
  Dinheiro? _faturamento;
  Dinheiro? get faturamentoHoje => _faturamento;

  Future<void> _carregarEstatisticas() async {
    try {
      final estatisticas = await _estatisticas.obterEstabelecimento();
      _faturamento = estatisticas.freteGasto;
    } on ErroApi {
      // Estatística indisponível não impede a lista de pedidos de
      // aparecer — o card de faturamento só fica em "—".
    } finally {
      notifyListeners();
    }
  }

  /// Recortes locais que a tela de atividades usa para agrupar o que
  /// **já foi carregado**. Não é filtro de escopo — o escopo veio do
  /// servidor; isto só separa visualmente o que está na mão.
  List<Pedido> get concluidos =>
      pedidos.itens.where((p) => p.status.concluido).toList();

  List<Pedido> get cancelados =>
      pedidos.itens.where((p) => p.status == StatusPedido.cancelado).toList();

  Future<void> carregar() async {
    await pedidos.carregar();
    unawaited(_carregarEstatisticas());
  }

  /// RF-A03.9
  void limpar() {
    pedidos.limpar();
    _faturamento = null;
    notifyListeners();
  }
}
