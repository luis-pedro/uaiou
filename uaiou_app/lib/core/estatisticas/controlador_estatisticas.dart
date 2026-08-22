import 'package:flutter/foundation.dart';

import '../estado/carregavel.dart';
import '../rede/erros_api.dart';
import 'modelo_estatisticas.dart';
import 'repositorio_estatisticas.dart';

/// RF-A09.7 — painel simples da tela de atividades: contagens e taxas
/// de `GET /me/stats`. Sem gráfico: o contrato não devolve série
/// nesta rota (`/me/stats/series` é outra chamada, fora do escopo de
/// A-09 — não há pedido de gráfico nos critérios de aceite).
class ControladorEstatisticas extends ChangeNotifier {
  final RepositorioEstatisticas _repositorio;

  ControladorEstatisticas({required RepositorioEstatisticas repositorio})
    : _repositorio = repositorio;

  Carregavel<EstatisticasEntregador> _estado = const Carregando();
  Carregavel<EstatisticasEntregador> get estado => _estado;

  Future<void> carregar({String? periodo}) async {
    _estado = const Carregando();
    notifyListeners();
    try {
      final resultado = await _repositorio.obter(periodo: periodo);
      _estado = Pronto(resultado);
    } on ErroApi catch (erro) {
      _estado = Falhou(erro);
    } finally {
      notifyListeners();
    }
  }

  void limpar() {
    _estado = const Carregando();
    notifyListeners();
  }
}
