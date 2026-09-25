import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../others/pedido.dart';
import '../estado/carregavel.dart';
import '../modelos/pagina.dart';
import '../rede/erros_api.dart';
import 'repositorio_pedidos.dart';
import 'sinal_pedidos.dart';

/// ===============================================================
/// UMA LISTA DE PEDIDOS — RF-A03.2
/// ===============================================================
///
/// Substitui as listas mutáveis dos singletons. Cada instância cuida
/// de **um recorte** (`GET /orders?status=`) e carrega o seu próprio
/// estado de carga, erro e paginação.
///
/// Depois do primeiro [carregar], se mantém atualizada sozinha via
/// [SinalPedidos] (push, volta do segundo plano, ações e polling).
class ListaDePedidos extends ChangeNotifier {
  final RepositorioPedidos _repositorio;

  /// Recorte do servidor. `null` = padrão do papel (vitrine para o
  /// entregador, próprios pedidos para o estabelecimento).
  final StatusPedido? recorte;

  ListaDePedidos(this._repositorio, {this.recorte}) {
    _sinal = SinalPedidos.instancia.eventos.listen(
      (_) => _atualizarEmSilencio(),
    );
  }

  late final StreamSubscription<Object?> _sinal;

  Carregavel<List<Pedido>> _estado = const Carregando();
  Pagina<Pedido>? _ultimaPagina;
  bool _carregandoMais = false;
  bool _emRecarga = false;

  /// Houve um [carregar] desde o último [limpar]: só então o sinal
  /// recarrega — lista que nenhuma tela abriu não gasta chamada.
  bool _ativa = false;

  /// O usuário já rolou além da primeira página. A recarga silenciosa
  /// jogaria fora o que ele rolou, então fica suspensa até o próximo
  /// [carregar]/[recarregar].
  bool _paginou = false;

  /// Número da busca mais recente. A resposta de uma busca antiga que
  /// chega depois de uma nova é descartada — sem isso, uma resposta
  /// atrasada sobrescrevia o pedido já atualizado com o estado anterior.
  int _geracao = 0;

  Carregavel<List<Pedido>> get estado => _estado;
  bool get carregandoMais => _carregandoMais;
  bool get emRecarga => _emRecarga;
  bool get temMais => _ultimaPagina?.temProxima ?? false;

  List<Pedido> get itens => _estado.valorOuNulo ?? const [];

  /// Primeira carga. Mostra o estado de *carregando* — a tela ainda
  /// não tem o que exibir.
  Future<void> carregar() async {
    _ativa = true;
    _estado = const Carregando();
    notifyListeners();
    await _buscar();
  }

  /// Recarga por gesto de puxar (RF-A03.6).
  ///
  /// **Mantém o conteúdo na tela.** Trocar para *carregando* aqui faria
  /// a lista piscar a cada gesto.
  Future<void> recarregar() async {
    _emRecarga = true;
    notifyListeners();
    await _buscar();
    _emRecarga = false;
    notifyListeners();
  }

  Future<void> _atualizarEmSilencio() async {
    if (!_ativa || _paginou || _emRecarga || _carregandoMais) return;
    await _buscar();
  }

  /// Próxima página, seguindo o `_links.next` do servidor.
  Future<void> carregarMais() async {
    final proxima = _ultimaPagina?.proximaHref;
    if (proxima == null || _carregandoMais) return;

    _carregandoMais = true;
    notifyListeners();
    final geracao = _geracao;

    try {
      final resultado = await _repositorio.seguir(proxima);
      // Uma busca completa chegou no meio: a base mudou e esta página
      // não se encaixa mais nela.
      if (geracao != _geracao) return;
      final acumulado = _ultimaPagina!.mais(resultado.pagina);
      _ultimaPagina = acumulado;
      _paginou = true;
      _estado = Pronto(acumulado.itens);
    } on ErroApi {
      // Falha ao paginar não descarta o que já está na tela: o
      // usuário continua com as páginas anteriores.
    } finally {
      _carregandoMais = false;
      notifyListeners();
    }
  }

  /// Remove localmente um item por id — RF-A07.4: quando o aceite
  /// perde a disputa por 409, o pedido já se sabe fora da vitrine
  /// antes mesmo do próximo `carregar()` confirmar, e não deve
  /// reaparecer na tela por uma fração de segundo.
  void removerLocalmente(String id) {
    final atual = _estado.valorOuNulo;
    if (atual == null) return;

    final restante = atual.where((pedido) => pedido.id != id).toList();
    _estado = restante.isEmpty ? const Vazio() : Pronto(restante);
    notifyListeners();
  }

  /// RF-A03.9 — descarta tudo. Chamado no logout.
  void limpar() {
    _ativa = false;
    _paginou = false;
    _geracao++;
    _estado = const Carregando();
    _ultimaPagina = null;
    _carregandoMais = false;
    _emRecarga = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sinal.cancel();
    super.dispose();
  }

  Future<void> _buscar() async {
    final geracao = ++_geracao;
    try {
      final resultado = await _repositorio.listar(status: recorte);
      if (geracao != _geracao) return;
      _ultimaPagina = resultado.pagina;
      _paginou = false;

      _estado = resultado.pagina.estaVazia
          ? Vazio(resultado.motivoDoVazio)
          : Pronto(resultado.pagina.itens);
    } on ErroApi catch (erro) {
      if (geracao != _geracao) return;
      // Falha numa recarga não apaga a lista que já está na tela.
      if (!_estado.temConteudo) _estado = Falhou(erro);
    } finally {
      if (geracao == _geracao) notifyListeners();
    }
  }
}
