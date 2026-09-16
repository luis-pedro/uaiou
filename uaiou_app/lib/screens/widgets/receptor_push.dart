import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/notificacoes/controlador_notificacoes.dart';
import 'package:uaiou/core/notificacoes/servico_push.dart';
import 'package:uaiou/core/sessao/controlador_sessao.dart';

/// Navegador do `MaterialApp`: o receptor vive no `builder`, acima do
/// `Navigator`, e precisa abrir telas a partir de um toque em push.
final GlobalKey<NavigatorState> navegadorRaiz = GlobalKey<NavigatorState>();

/// ===============================================================
/// RECEPTOR DE PUSH
/// ===============================================================
///
/// - Chegou com o app aberto: recarrega a inbox (o contador do sino
///   muda na hora). O aviso visual é do sistema — banner no iOS,
///   notificação local no Android (ver `servico_push.dart`) —, então
///   aqui não se desenha nada, para não avisar duas vezes.
/// - Tocou na notificação: abre a inbox, que já sabe levar cada `type`
///   à tela certa (`tela_notificacoes.dart#_abrir`). Um único lugar
///   decidindo o deep link, em vez de duas cópias do mesmo `switch`.
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
      ..add(push.recebidas.listen((_) => _recarregarInbox()))
      ..add(push.abertas.listen((_) => _abrirInbox()));

    final inicial = push.consumirAberturaInicial();
    if (inicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _abrirInbox());
    }
  }

  @override
  void dispose() {
    for (final assinatura in _assinaturas) {
      assinatura.cancel();
    }
    super.dispose();
  }

  void _recarregarInbox() {
    if (!mounted || !context.read<ControladorSessao>().autenticado) return;
    context.read<ControladorNotificacoes>().recarregar();
  }

  Future<void> _abrirInbox() async {
    if (!mounted) return;
    final sessao = context.read<ControladorSessao>();
    // Abertura a frio: a sessão ainda pode estar saindo do cofre.
    if (sessao.fase == FaseSessao.carregando) {
      await _aguardarSessao(sessao);
    }
    if (!mounted || !sessao.podeOperar) return;
    _recarregarInbox();
    navegadorRaiz.currentState?.pushNamed('/notificacoes');
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
