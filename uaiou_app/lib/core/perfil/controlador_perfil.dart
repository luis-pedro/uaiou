import 'package:flutter/foundation.dart';

import '../estado/carregavel.dart';
import '../rede/erros_api.dart';
import 'perfil.dart';
import 'repositorio_perfil.dart';

/// Carrega `GET /me` no `initState` da tela de perfil e aplica edições
/// por `PATCH /me` — RF-A05.1/RF-A05.2.
class ControladorPerfil extends ChangeNotifier {
  final RepositorioPerfil _repositorio;

  ControladorPerfil({required RepositorioPerfil repositorio}) : _repositorio = repositorio;

  Carregavel<Perfil> _estado = const Carregando();
  Carregavel<Perfil> get estado => _estado;

  Future<void> carregar() async {
    _estado = const Carregando();
    notifyListeners();
    await _buscar();
  }

  Future<void> recarregar() => _buscar();

  /// `true` se salvou. Erro fica em [ultimoErro] para a tela exibir.
  String? ultimoErro;

  Future<bool> salvar(EdicaoDePerfil edicao) async {
    if (edicao.estaVazia) return true;

    ultimoErro = null;
    try {
      final atualizado = await _repositorio.editar(edicao);
      _estado = Pronto(atualizado);
      notifyListeners();
      return true;
    } on ErroApi catch (erro) {
      ultimoErro = erro.mensagemParaUsuario;
      notifyListeners();
      return false;
    }
  }

  /// RF-A03.9 — nada do usuário anterior sobrevive ao logout.
  void limpar() {
    _estado = const Carregando();
    ultimoErro = null;
    notifyListeners();
  }

  Future<void> _buscar() async {
    try {
      final perfil = await _repositorio.obter();
      _estado = Pronto(perfil);
    } on ErroApi catch (erro) {
      _estado = Falhou(erro);
    } finally {
      notifyListeners();
    }
  }
}
