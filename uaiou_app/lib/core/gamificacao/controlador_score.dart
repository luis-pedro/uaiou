import 'package:flutter/foundation.dart';

import '../estado/carregavel.dart';
import '../rede/erros_api.dart';
import 'repositorio_score.dart';
import 'score.dart';

/// ===============================================================
/// SCORE — A-12 (RF-A12.4/RF-A12.5)
/// ===============================================================
///
/// Único ponto de leitura de `GET /me/score` compartilhado entre o
/// cabeçalho da tela principal e o card do perfil (dos dois papéis) —
/// antes cada tela buscava por conta própria (ou, no cabeçalho do
/// entregador, nem buscava: lia um `double?` sempre nulo do singleton
/// antigo, `EstadoEntregador.avaliacao`). Só leitura: o app nunca
/// recalcula a nota nem os componentes (RF-A12.5).
class ControladorScore extends ChangeNotifier {
  final RepositorioScore _repositorio;

  ControladorScore({required RepositorioScore repositorio}) : _repositorio = repositorio;

  Carregavel<Score> _estado = const Carregando();
  Carregavel<Score> get estado => _estado;
  Score? get score => _estado.valorOuNulo;

  Future<void> carregar() async {
    try {
      final score = await _repositorio.obter();
      _estado = Pronto(score);
    } on ErroApi catch (erro) {
      // Entregador/estabelecimento novo sem nota ainda cai aqui como
      // 404 — a tela mostra "sem avaliações", nunca "0,0" (critério 8
      // de A-12).
      _estado = Falhou(erro);
    } finally {
      notifyListeners();
    }
  }

  /// RF-A03.9 — logout descarta a nota carregada.
  void limpar() {
    _estado = const Carregando();
    notifyListeners();
  }
}
