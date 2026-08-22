import 'package:flutter/foundation.dart';

import '../estado/carregavel.dart';
import '../rede/erros_api.dart';
import 'modelo_avaliacao.dart';
import 'repositorio_avaliacoes.dart';

/// ===============================================================
/// AVALIAÇÕES — A-12
/// ===============================================================
///
/// Carrega pendentes e recebidas, e envia a avaliação de um pedido.
/// RF-A12.2: não avaliar nunca bloqueia nada aqui — este controlador
/// só oferece a ação, nunca condiciona outra tela a ela.
class ControladorAvaliacoes extends ChangeNotifier {
  final RepositorioAvaliacoes _repositorio;

  ControladorAvaliacoes({required RepositorioAvaliacoes repositorio})
    : _repositorio = repositorio;

  Carregavel<List<AvaliacaoPendente>> _pendentes = const Carregando();
  Carregavel<List<AvaliacaoPendente>> get pendentes => _pendentes;

  Carregavel<RespostaAvaliacoesRecebidas> _recebidas = const Carregando();
  Carregavel<RespostaAvaliacoesRecebidas> get recebidas => _recebidas;

  bool _enviando = false;
  bool get enviando => _enviando;

  String? _erroEnvio;
  String? get erroEnvio => _erroEnvio;

  /// Chamado ao abrir a tela de avaliações — busca as duas listas.
  Future<void> carregar() async {
    await Future.wait([_carregarPendentes(), _carregarRecebidas()]);
  }

  Future<void> recarregar() => carregar();

  Future<void> _carregarPendentes() async {
    try {
      final itens = await _repositorio.pendentes();
      _pendentes = itens.isEmpty ? const Vazio() : Pronto(itens);
    } on ErroApi catch (erro) {
      _pendentes = Falhou(erro);
    } finally {
      notifyListeners();
    }
  }

  Future<void> _carregarRecebidas() async {
    try {
      final resposta = await _repositorio.recebidas();
      _recebidas = Pronto(resposta);
    } on ErroApi catch (erro) {
      _recebidas = Falhou(erro);
    } finally {
      notifyListeners();
    }
  }

  /// RF-A12.1 — envia a avaliação de um pedido pendente. Em sucesso,
  /// recarrega a lista de pendentes (o pedido some dela) e a de
  /// recebidas não muda aqui (é o que a *outra* parte escreveu).
  Future<bool> avaliar(String orderId, {required int rating, String? comment}) async {
    if (_enviando) return false;
    _enviando = true;
    _erroEnvio = null;
    notifyListeners();

    try {
      await _repositorio.criar(orderId, rating: rating, comment: comment);
      await _carregarPendentes();
      return true;
    } on ErroApi catch (erro) {
      _erroEnvio = erro.mensagemParaUsuario;
      return false;
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  void limparErroEnvio() {
    if (_erroEnvio == null) return;
    _erroEnvio = null;
    notifyListeners();
  }

  /// RF-A03.9 — logout descarta o que foi carregado.
  void limpar() {
    _pendentes = const Carregando();
    _recebidas = const Carregando();
    _enviando = false;
    _erroEnvio = null;
    notifyListeners();
  }
}
