import 'package:flutter/foundation.dart';

import '../estado/carregavel.dart';
import '../rede/erros_api.dart';
import 'modelo_payables.dart';
import 'repositorio_payables.dart';

/// RF-A10.9 — "a pagar" da `tela_atividade_estabelecimento`. Só
/// leitura: o estabelecimento vê o que deve a cada entregador, quem
/// confirma o acerto é o entregador (A-09).
class ControladorPayables extends ChangeNotifier {
  final RepositorioPayables _repositorio;

  ControladorPayables({required RepositorioPayables repositorio})
    : _repositorio = repositorio;

  Carregavel<Payables> _estado = const Carregando();
  Carregavel<Payables> get estado => _estado;
  Payables get payables => _estado.valorOuNulo ?? Payables.vazio;

  Future<void> carregar() async {
    _estado = const Carregando();
    notifyListeners();
    try {
      final resultado = await _repositorio.obter();
      _estado = resultado.porEntregador.isEmpty ? const Vazio() : Pronto(resultado);
    } on ErroApi catch (erro) {
      _estado = Falhou(erro);
    } finally {
      notifyListeners();
    }
  }

  Future<void> recarregar() => carregar();

  void limpar() {
    _estado = const Carregando();
    notifyListeners();
  }
}
