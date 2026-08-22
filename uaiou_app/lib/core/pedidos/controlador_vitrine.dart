import 'dart:async';

import 'package:flutter/foundation.dart';

import '../modelos/dinheiro.dart';
import '../modelos/status_pedido.dart';
import '../rede/erros_api.dart';
import 'lista_de_pedidos.dart';
import 'repositorio_pedidos.dart';

/// ===============================================================
/// VITRINE E ACEITE — A-07
/// ===============================================================
///
/// Junta a lista de pedidos elegíveis (`GET /orders?status=published`,
/// via [ListaDePedidos]) com as duas ações que a transformam: aceitar
/// (RF-A07.3) e contrapropor (RF-A07.5). Fica fora de [ListaDePedidos]
/// porque essas ações têm reentrância e resultado por-tentativa que
/// uma lista genérica de leitura não modela.
///
/// **A tela decide quando chamar [carregar]**: este controlador não
/// sabe se o entregador está disponível (RF-A07.9) — essa checagem é
/// de [ControladorPresenca], e a tela é quem cruza os dois.
class ControladorVitrine extends ChangeNotifier {
  final RepositorioPedidos _repositorio;

  final ListaDePedidos pedidos;

  ControladorVitrine(this._repositorio)
    : pedidos = ListaDePedidos(_repositorio, recorte: StatusPedido.pendente);

  /// Id do pedido cujo aceite está em voo. `null` = nenhum.
  ///
  /// RNF-A07.1 — a guarda é aqui, não só no `onPressed` do botão:
  /// `notifyListeners()` só reconstrói a UI no frame seguinte (mesmo
  /// motivo documentado em `ControladorCadastro.concluir()`), então um
  /// duplo toque passa pelo `onPressed: enviando ? null : ...` antes
  /// do botão desabilitar visualmente. É este campo em memória, não a
  /// reconstrução da tela, que impede a segunda requisição.
  String? _aceitandoId;
  String? get aceitandoId => _aceitandoId;
  bool aceitando(String pedidoId) => _aceitandoId == pedidoId;
  bool get haAceiteEmVoo => _aceitandoId != null;

  String? _contrapondoId;
  bool contrapondo(String pedidoId) => _contrapondoId == pedidoId;
  bool get haContrapropostaEmVoo => _contrapondoId != null;

  /// Pedidos com contraproposta pendente enviada nesta sessão de tela
  /// — RF-A07.5, "o entregador acompanha o estado da proposta".
  ///
  /// Não persiste entre cargas: a decisão do estabelecimento chega por
  /// push (A-11, fora de escopo aqui). Nesta v1, recarregar a vitrine
  /// (RF-A07.7) é o que reflete o estado mais recente do servidor —
  /// se o pedido some da lista, a proposta seguiu adiante; se volta
  /// como `published`, foi recusada ou invalidada.
  final Set<String> _propostasPendentes = {};
  bool temPropostaPendente(String pedidoId) =>
      _propostasPendentes.contains(pedidoId);

  /// Mensagem da última ação (sucesso ou falha), para a tela exibir
  /// uma vez e descartar.
  String? _aviso;
  String? get aviso => _aviso;

  void limparAviso() {
    if (_aviso == null) return;
    _aviso = null;
    notifyListeners();
  }

  Future<void> carregar() => pedidos.carregar();
  Future<void> recarregar() => pedidos.recarregar();

  /// RF-A07.3/RF-A07.4/RNF-A07.1 — aceita o pedido.
  ///
  /// Devolve `true` só quando a atribuição foi criada: é o sinal para
  /// a tela navegar à tela de entregas (RF-A07.8). Em 409
  /// (`ORDER_ALREADY_ASSIGNED`) — disputa perdida para outro
  /// entregador — não é falha genérica: remove o pedido da vitrine
  /// local e recarrega do servidor (RF-A07.4).
  Future<bool> aceitar(String pedidoId) async {
    if (_aceitandoId != null) return false;

    _aceitandoId = pedidoId;
    _aviso = null;
    notifyListeners();

    try {
      await _repositorio.aceitar(pedidoId);
      pedidos.removerLocalmente(pedidoId);
      return true;
    } on Conflito catch (erro) {
      // Mensagem já redigida pelo servidor (RF-A07.4) — se por algum
      // motivo vier vazia, o texto de reserva ainda deixa claro que
      // não é um erro genérico.
      _aviso = erro.mensagemParaUsuario.trim().isNotEmpty
          ? erro.mensagemParaUsuario
          : 'Esse pedido acabou de ser aceito por outra pessoa.';
      pedidos.removerLocalmente(pedidoId);
      // Não usa `await` no recarregamento antes de notificar: o aviso
      // já vale e não deve esperar a rede de novo para aparecer.
      unawaited(pedidos.recarregar());
      return false;
    } on ErroApi catch (erro) {
      _aviso = erro.mensagemParaUsuario;
      return false;
    } finally {
      _aceitandoId = null;
      notifyListeners();
    }
  }

  /// RF-A07.5 — propõe outro frete. O pedido **continua visível** aos
  /// demais entregadores (api/pedidos.md): contrapropor não reserva.
  Future<bool> contrapropor(String pedidoId, Dinheiro valor) async {
    if (_contrapondoId != null) return false;

    _contrapondoId = pedidoId;
    _aviso = null;
    notifyListeners();

    try {
      await _repositorio.contrapropor(pedidoId, valor);
      _propostasPendentes.add(pedidoId);
      return true;
    } on Conflito catch (erro) {
      _aviso = erro.mensagemParaUsuario;
      return false;
    } on ErroApi catch (erro) {
      _aviso = erro.mensagemParaUsuario;
      return false;
    } finally {
      _contrapondoId = null;
      notifyListeners();
    }
  }

  /// RF-A03.9 — descarta tudo no logout.
  void limpar() {
    pedidos.limpar();
    _aceitandoId = null;
    _contrapondoId = null;
    _propostasPendentes.clear();
    _aviso = null;
    notifyListeners();
  }

  @override
  void dispose() {
    pedidos.dispose();
    super.dispose();
  }
}
