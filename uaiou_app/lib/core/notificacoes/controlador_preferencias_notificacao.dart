import 'package:flutter/foundation.dart';

import '../estado/carregavel.dart';
import '../rede/erros_api.dart';
import 'modelo_notificacao.dart';
import 'repositorio_notificacoes.dart';

/// RF-A11.8 — `GET`/`PUT /me/notification-preferences`.
///
/// `mandatory` são **tipos de notificação** que o servidor nunca
/// silencia (`NotificationPreferencesResponse.mandatory`), não canais:
/// o contrato não expõe um endpoint para desligar tipo por tipo, só
/// canal por canal (`channels.push/email/sms`). A tela mostra a lista
/// de tipos obrigatórios como informação ("estes sempre chegam"), e os
/// toggles de canal como o único controle real que existe.
class ControladorPreferenciasNotificacao extends ChangeNotifier {
  final RepositorioNotificacoes _repositorio;

  ControladorPreferenciasNotificacao({required RepositorioNotificacoes repositorio})
    : _repositorio = repositorio;

  Carregavel<PreferenciasNotificacao> _estado = const Carregando();
  Carregavel<PreferenciasNotificacao> get estado => _estado;
  PreferenciasNotificacao get preferencias =>
      _estado.valorOuNulo ?? PreferenciasNotificacao.vazia;

  bool _salvando = false;
  bool get salvando => _salvando;

  String? _erro;
  String? get erro => _erro;

  Future<void> carregar() async {
    _estado = const Carregando();
    notifyListeners();

    try {
      final resultado = await _repositorio.obterPreferencias();
      _estado = Pronto(resultado);
    } on ErroApi catch (erro) {
      _estado = Falhou(erro);
    } finally {
      notifyListeners();
    }
  }

  /// Alterna um único canal. **Só o canal tocado vai no corpo** — o
  /// campo ausente mantém o valor atual no servidor, então nunca se
  /// manda os outros dois.
  Future<void> alternarCanal(String canal, bool valor) async {
    if (_salvando) return;
    _salvando = true;
    _erro = null;
    notifyListeners();

    try {
      final atualizado = await _repositorio.atualizarPreferencias(
        push: canal == 'push' ? valor : null,
        email: canal == 'email' ? valor : null,
        sms: canal == 'sms' ? valor : null,
      );
      _estado = Pronto(atualizado);
    } on ErroApi catch (erro) {
      _erro = erro.mensagemParaUsuario;
    } finally {
      _salvando = false;
      notifyListeners();
    }
  }

  void limpar() {
    _estado = const Carregando();
    _salvando = false;
    _erro = null;
    notifyListeners();
  }
}
