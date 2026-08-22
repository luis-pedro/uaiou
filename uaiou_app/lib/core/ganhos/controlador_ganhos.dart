import 'package:flutter/foundation.dart';

import '../estado/carregavel.dart';
import '../modelos/pagina.dart';
import '../rede/erros_api.dart';
import 'modelo_ganhos.dart';
import 'repositorio_ganhos.dart';

/// ===============================================================
/// GANHOS E ACERTO — A-09
/// ===============================================================
///
/// Alimenta o card "Ganhos de Hoje"/extrato com `GET /me/earnings` e
/// confirma acerto por `POST /me/earnings/settlements`. O total
/// exibido é sempre `resumo`, nunca uma soma feita aqui (RF-A09.1) —
/// a seleção some só serve para o usuário conferir antes de confirmar
/// (RNF-A09.2), não para substituir o `summary` do servidor.
class ControladorGanhos extends ChangeNotifier {
  final RepositorioGanhos _repositorio;

  ControladorGanhos({required RepositorioGanhos repositorio})
    : _repositorio = repositorio;

  Carregavel<List<Lancamento>> _estado = const Carregando();
  Carregavel<List<Lancamento>> get estado => _estado;
  List<Lancamento> get lancamentos => _estado.valorOuNulo ?? const [];

  ResumoGanhos _resumo = ResumoGanhos.zero;
  ResumoGanhos get resumo => _resumo;

  Pagina<Lancamento>? _ultimaPagina;
  bool _carregandoMais = false;
  bool get carregandoMais => _carregandoMais;
  bool get temMais => _ultimaPagina?.temProxima ?? false;

  final Set<String> _selecionados = {};
  Set<String> get selecionados => Set.unmodifiable(_selecionados);

  bool _confirmando = false;
  bool get confirmando => _confirmando;

  String? _erro;
  String? get erro => _erro;

  /// Primeira carga — mostra *carregando* enquanto não há o que exibir.
  Future<void> carregar() async {
    _estado = const Carregando();
    _selecionados.clear();
    notifyListeners();
    await _buscar();
  }

  /// Recarga (puxar para atualizar / após confirmar acerto): mantém o
  /// conteúdo na tela em vez de piscar para *carregando*.
  Future<void> recarregar() async {
    await _buscar();
  }

  Future<void> carregarMais() async {
    final proxima = _ultimaPagina?.proximaHref;
    if (proxima == null || _carregandoMais) return;

    _carregandoMais = true;
    notifyListeners();

    try {
      final resultado = await _repositorio.seguir(proxima);
      final acumulada = _ultimaPagina!.mais(resultado.pagina);
      _ultimaPagina = acumulada;
      _estado = Pronto(acumulada.itens);
      // O resumo da última resposta é o mais atual — o servidor manda
      // o mesmo `summary` do período em toda página.
      _resumo = resultado.resumo;
    } on ErroApi {
      // Falha ao paginar preserva o que já está na tela.
    } finally {
      _carregandoMais = false;
      notifyListeners();
    }
  }

  void alternarSelecao(String id) {
    if (_selecionados.contains(id)) {
      _selecionados.remove(id);
    } else {
      _selecionados.add(id);
    }
    notifyListeners();
  }

  void limparSelecao() {
    if (_selecionados.isEmpty) return;
    _selecionados.clear();
    notifyListeners();
  }

  /// RF-A09.3/RF-A09.4 — confirma o acerto dos lançamentos
  /// selecionados. Guarda de reentrância: um duplo toque não dispara
  /// dois `POST` para o mesmo acerto, que é irreversível.
  Future<bool> confirmarSelecionados() async {
    if (_confirmando || _selecionados.isEmpty) return false;

    _confirmando = true;
    _erro = null;
    notifyListeners();

    try {
      await _repositorio.confirmarAcerto(_selecionados.toList());
      _selecionados.clear();
      await _buscar();
      return true;
    } on ErroApi catch (erro) {
      _erro = erro.mensagemParaUsuario;
      return false;
    } finally {
      _confirmando = false;
      notifyListeners();
    }
  }

  void limpar() {
    _estado = const Carregando();
    _resumo = ResumoGanhos.zero;
    _ultimaPagina = null;
    _carregandoMais = false;
    _confirmando = false;
    _selecionados.clear();
    _erro = null;
    notifyListeners();
  }

  Future<void> _buscar() async {
    try {
      final resultado = await _repositorio.obter();
      _ultimaPagina = resultado.pagina;
      _resumo = resultado.resumo;
      _estado = resultado.pagina.estaVazia
          ? const Vazio()
          : Pronto(resultado.pagina.itens);
    } on ErroApi catch (erro) {
      _estado = Falhou(erro);
    } finally {
      notifyListeners();
    }
  }
}
