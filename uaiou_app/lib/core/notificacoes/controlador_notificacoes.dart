import 'package:flutter/foundation.dart';

import '../estado/carregavel.dart';
import '../rede/erros_api.dart';
import 'modelo_notificacao.dart';
import 'repositorio_notificacoes.dart';

/// ===============================================================
/// CAIXA DE ENTRADA DE NOTIFICAÇÕES — A-11
/// ===============================================================
///
/// ## O que esta task NÃO faz — fora de escopo por limitação de
/// plataforma, não por corte de produto (ver RF-A11.3/RF-A11.4/
/// RNF-A11.1 na task)
///
/// Push de verdade (FCM/APNs entregando com o app fechado) não existe
/// de forma confiável em Flutter Web sem Service Worker + VAPID key +
/// Firebase Cloud Messaging for Web — e mesmo essa combinação não
/// entrega nada com o navegador totalmente fechado, só minimizado.
/// Como não há esse provedor configurado, este módulo não simula push:
/// nenhuma notificação "chega" sozinha. O que existe é honesto sobre
/// isso — a inbox é alimentada por busca ativa (ao abrir a tela / ao
/// focar a aba), que é exatamente o caminho de recuperação que
/// RF-A11.6 já prevê para quando "o push falha" — aqui ele sempre
/// "falha", então a inbox é a única fonte.
///
/// Por isso também não há RF-A11.9 (permissão nativa do navegador):
/// não há o que pedir permissão para, sem um provedor de push real.
///
/// ## O que é real
///
/// `GET /me/notifications`, marcar como lida (individual e em massa) e
/// o contador de não lidas (`meta.unread`, nunca calculado localmente
/// somando itens — RF-A11.7) são chamadas de verdade contra o
/// backend.
class ControladorNotificacoes extends ChangeNotifier {
  final RepositorioNotificacoes _repositorio;

  ControladorNotificacoes({required RepositorioNotificacoes repositorio})
    : _repositorio = repositorio;

  Carregavel<List<Notificacao>> _estado = const Carregando();
  Carregavel<List<Notificacao>> get estado => _estado;
  List<Notificacao> get notificacoes => _estado.valorOuNulo ?? const [];

  int _naoLidas = 0;
  int get naoLidas => _naoLidas;

  bool _marcandoTodas = false;
  bool get marcandoTodas => _marcandoTodas;

  /// RNF-A11.3 — evita marcar a mesma notificação como lida duas vezes
  /// em cliques rápidos (idempotência da tela, não do push).
  final Set<String> _marcandoIndividualmente = {};
  bool marcandoEsta(String id) => _marcandoIndividualmente.contains(id);

  String? _erro;
  String? get erro => _erro;

  /// Primeira carga.
  Future<void> carregar() async {
    _estado = const Carregando();
    notifyListeners();
    await _buscar();
  }

  /// Recarga — ao reabrir a tela ou focar a aba (o "poll" possível em
  /// web, sem WebSocket). Mantém a lista na tela em vez de piscar.
  Future<void> recarregar() => _buscar();

  Future<void> _buscar() async {
    try {
      final resultado = await _repositorio.obter(porPagina: 50);
      _naoLidas = resultado.unread;
      _estado = resultado.data.isEmpty ? const Vazio() : Pronto(resultado.data);
    } on ErroApi catch (erro) {
      _estado = Falhou(erro);
    } finally {
      notifyListeners();
    }
  }

  /// RF-A11.6 — marca uma notificação como lida e atualiza a lista e o
  /// contador localmente com o que o servidor devolveu, sem recarregar
  /// tudo. Duplo toque na mesma notificação não duplica a chamada
  /// (RNF-A11.3).
  Future<void> marcarLida(String id) async {
    if (_marcandoIndividualmente.contains(id)) return;
    final atual = notificacoes.firstWhere(
      (n) => n.id == id,
      orElse: () => Notificacao(
        id: id,
        type: '',
        priority: PrioridadeNotificacao.normal,
        title: '',
        body: '',
        payload: const {},
      ),
    );
    if (atual.lida) return;

    _marcandoIndividualmente.add(id);
    notifyListeners();

    try {
      final atualizada = await _repositorio.marcarLida(id);
      final lista = notificacoes
          .map((n) => n.id == atualizada.id ? atualizada : n)
          .toList();
      _estado = Pronto(lista);
      if (_naoLidas > 0) _naoLidas -= 1;
    } on ErroApi catch (erro) {
      _erro = erro.mensagemParaUsuario;
    } finally {
      _marcandoIndividualmente.remove(id);
      notifyListeners();
    }
  }

  /// RF-A11.6/critério 6 — zera o contador ao marcar todas como lidas.
  Future<void> marcarTodasLidas() async {
    if (_marcandoTodas) return;
    _marcandoTodas = true;
    notifyListeners();

    try {
      await _repositorio.marcarTodasLidas();
      final agora = DateTime.now();
      _estado = Pronto(
        notificacoes.map((n) => n.lida ? n : n.comoLida(agora)).toList(),
      );
      _naoLidas = 0;
    } on ErroApi catch (erro) {
      _erro = erro.mensagemParaUsuario;
    } finally {
      _marcandoTodas = false;
      notifyListeners();
    }
  }

  void limpar() {
    _estado = const Carregando();
    _naoLidas = 0;
    _marcandoTodas = false;
    _marcandoIndividualmente.clear();
    _erro = null;
    notifyListeners();
  }
}
