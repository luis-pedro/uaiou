import 'package:flutter/foundation.dart';

import '../estado/carregavel.dart';
import '../rede/erros_api.dart';
import 'bloqueio.dart';
import 'repositorio_bloqueios.dart';

/// Lista de bloqueios do estabelecimento — RF-A05.6.
///
/// Bloquear/desbloquear recarrega a lista do servidor em vez de
/// remendar localmente: quem decide elegibilidade é o servidor
/// (RN-07.2), a tela só reflete.
class EstadoBloqueios extends ChangeNotifier {
  final RepositorioBloqueios _repositorio;

  EstadoBloqueios({required RepositorioBloqueios repositorio}) : _repositorio = repositorio;

  Carregavel<List<EntregadorBloqueado>> _estado = const Carregando();
  Carregavel<List<EntregadorBloqueado>> get estado => _estado;

  String? ultimoErro;

  Future<void> carregar() async {
    _estado = const Carregando();
    notifyListeners();
    await _buscar();
  }

  Future<bool> bloquear({required String entregadorId, String? motivo}) async {
    ultimoErro = null;
    try {
      await _repositorio.bloquear(entregadorId: entregadorId, motivo: motivo);
      await _buscar();
      return true;
    } on ErroApi catch (erro) {
      ultimoErro = erro.mensagemParaUsuario;
      notifyListeners();
      return false;
    }
  }

  Future<bool> desbloquear(String entregadorId) async {
    ultimoErro = null;
    try {
      await _repositorio.desbloquear(entregadorId);
      await _buscar();
      return true;
    } on ErroApi catch (erro) {
      ultimoErro = erro.mensagemParaUsuario;
      notifyListeners();
      return false;
    }
  }

  void limpar() {
    _estado = const Carregando();
    ultimoErro = null;
    notifyListeners();
  }

  Future<void> _buscar() async {
    try {
      final lista = await _repositorio.listar();
      _estado = lista.isEmpty ? const Vazio() : Pronto(lista);
    } on ErroApi catch (erro) {
      _estado = Falhou(erro);
    } finally {
      notifyListeners();
    }
  }
}
