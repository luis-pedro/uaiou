import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/notificacoes/controlador_notificacoes.dart';
import 'package:uaiou/core/notificacoes/servico_push.dart';
import 'package:uaiou/core/sessao/controlador_sessao.dart';
import 'package:uaiou/screens/destino_notificacao.dart';
import 'package:uaiou/screens/widgets/aviso_flutuante.dart';

/// Navegador do `MaterialApp`: o receptor vive no `builder`, acima do
/// `Navigator`, e precisa abrir telas a partir de um toque em push.
final GlobalKey<NavigatorState> navegadorRaiz = GlobalKey<NavigatorState>();

/// ===============================================================
/// RECEPTOR DE PUSH
/// ===============================================================
///
/// - Chegou com o app aberto: recarrega a inbox e mostra um toast no
///   rodapé (tocar abre a tela do evento). Com o app aberto não há notificação
///   do sistema (ver `servico_push.dart`), então o aviso não duplica.
/// - Tocou na notificação: abre a tela do evento pela mesma regra da
///   inbox (`destino_notificacao.dart`); sem tela para o tipo, a inbox.
class ReceptorPush extends StatefulWidget {
  final ServicoPush? push;
  final Widget child;

  const ReceptorPush({super.key, required this.push, required this.child});

  @override
  State<ReceptorPush> createState() => _ReceptorPushState();
}

class _ReceptorPushState extends State<ReceptorPush> {
  final List<StreamSubscription<EventoPush>> _assinaturas = [];

  @override
  void initState() {
    super.initState();
    final push = widget.push;
    if (push == null) return;

    _assinaturas
      ..add(push.recebidas.listen(_aoChegar))
      ..add(push.abertas.listen(_abrirEvento));

    final inicial = push.consumirAberturaInicial();
    if (inicial != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _abrirEvento(inicial),
      );
    }
  }

  @override
  void dispose() {
    for (final assinatura in _assinaturas) {
      assinatura.cancel();
    }
    super.dispose();
  }

  void _aoChegar(EventoPush evento) {
    _recarregarInbox();
    final overlay = navegadorRaiz.currentState?.overlay;
    final titulo = evento.titulo ?? 'Nova notificação';
    if (overlay == null) return;
    mostrarToast(
      overlay,
      titulo: titulo,
      mensagem: (evento.corpo ?? '').isEmpty ? 'Toque para ver' : evento.corpo!,
      tom: evento.urgente ? TomAviso.urgente : TomAviso.info,
      aoTocar: () => _abrirEvento(evento),
    );
  }

  void _recarregarInbox() {
    if (!mounted || !context.read<ControladorSessao>().autenticado) return;
    context.read<ControladorNotificacoes>().recarregar();
  }

  /// Leva à tela do evento (mesma regra da inbox, `destino_notificacao.dart`)
  /// e marca como lida. Sem `type` ou sem tela para ele, abre a inbox.
  Future<void> _abrirEvento(EventoPush evento) async {
    if (!mounted) return;
    final sessao = context.read<ControladorSessao>();
    // Abertura a frio: a sessão ainda pode estar saindo do cofre.
    if (sessao.fase == FaseSessao.carregando) {
      await _aguardarSessao(sessao);
    }
    if (!mounted || !sessao.podeOperar) return;
    final navegador = navegadorRaiz.currentState;
    if (navegador == null) return;

    final notificacoes = context.read<ControladorNotificacoes>();
    final id = evento.notificationId;
    if (id != null && id.isNotEmpty) unawaited(notificacoes.marcarLida(id));
    _recarregarInbox();

    final type = evento.type;
    final abriu =
        type != null &&
        abrirDestinoNotificacao(
          navegador,
          papel: sessao.papel,
          type: type,
          payload: evento.dados,
        );
    if (!abriu) navegador.pushNamed('/notificacoes');
  }

  Future<void> _aguardarSessao(ControladorSessao sessao) {
    final pronto = Completer<void>();
    void ouvir() {
      if (sessao.fase != FaseSessao.carregando && !pronto.isCompleted) {
        sessao.removeListener(ouvir);
        pronto.complete();
      }
    }

    sessao.addListener(ouvir);
    return pronto.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => sessao.removeListener(ouvir),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
