import 'package:flutter/material.dart';

import 'package:uaiou/core/sessao/identidade.dart';
import 'package:uaiou/screens/tela_a_pagar.dart';
import 'package:uaiou/screens/tela_detalhe_pedido.dart';
import 'package:uaiou/screens/tela_entrega_em_andamento.dart';
import 'package:uaiou/screens/tela_status_conta.dart';

/// ===============================================================
/// DESTINO DE UMA NOTIFICAÇÃO — RF-A11.5
/// ===============================================================
///
/// Único lugar que decide para qual tela um `type` + `payload` leva.
/// Usado pela inbox (toque no cartão) e pelo push (toque na
/// notificação do sistema ou no toast), para os dois nunca divergirem.
///
/// A tela de destino busca o próprio estado na API; do payload só sai
/// o identificador (`orderId`), nunca conteúdo renderizado.
///
/// Devolve `false` quando o evento não tem tela no app (hoje só
/// `support.replied` e disputa sem pedido) — quem chamou mostra o
/// detalhe da notificação.
bool abrirDestinoNotificacao(
  NavigatorState navegador, {
  required Papel papel,
  required String type,
  required Map<String, Object?> payload,
}) {
  final orderId = payload['orderId'];
  final pedido = orderId is String && orderId.isNotEmpty ? orderId : null;
  final entregador = papel == Papel.entregador;
  final estabelecimento = papel == Papel.estabelecimento;

  void empurrar(Widget tela) =>
      navegador.push(MaterialPageRoute<void>(builder: (_) => tela));

  switch (type) {
    // ---- Pedido: o estabelecimento sempre cai no detalhe do pedido.
    case 'order.published' ||
            'order.assigned' ||
            'order.courier_arrived' ||
            'order.picked_up' ||
            'order.cancelled' ||
            'order.courier_withdrew' ||
            'counteroffer.received' ||
            'counteroffer.decided' ||
            'delivery.code_contingency' ||
            'delivery.completed' ||
            'delivery.contestable' ||
            'dispute.opened' ||
            'dispute.decided'
        when estabelecimento && pedido != null:
      empurrar(TelaDetalhePedido(pedidoId: pedido));
      return true;

    // ---- Entregador: só abre a entrega quando ela é dele e segue viva.
    case 'order.assigned' ||
            'order.picked_up' ||
            'delivery.code_contingency' ||
            'delivery.completed' ||
            'delivery.contestable' ||
            'dispute.opened' ||
            'dispute.decided'
        when entregador && pedido != null:
      empurrar(TelaEntregaEmAndamento(pedidoId: pedido));
      return true;

    case 'counteroffer.decided' when entregador:
      if (payload['outcome'] == 'accepted' && pedido != null) {
        empurrar(TelaEntregaEmAndamento(pedidoId: pedido));
      } else {
        // Recusada ou invalidada: o que resta é procurar outro pedido.
        navegador.pushNamed('/principal_entregador');
      }
      return true;

    case 'order.published' when entregador:
      navegador.pushNamed('/principal_entregador');
      return true;

    case 'order.cancelled' when entregador:
      // O pedido cancelado não tem mais entrega; o histórico mostra a
      // taxa recebida, quando houver.
      navegador.pushNamed('/entregas_entregador');
      return true;

    // ---- Dinheiro.
    case 'wallet.earning_released' || 'withdrawal.settled' when entregador:
      navegador.pushNamed('/extrato_ganhos');
      return true;
    case 'wallet.earning_released' || 'withdrawal.settled' when estabelecimento:
      empurrar(const TelaAPagar());
      return true;

    // ---- Gamificação: score e metas vivem no perfil.
    case 'goal.completed' || 'bonus.granted' when entregador:
      navegador.pushNamed('/perfil_entregador');
      return true;
    case 'goal.completed' || 'bonus.granted' when estabelecimento:
      navegador.pushNamed('/perfil_estabelecimento');
      return true;

    // ---- Conta.
    case 'registration.reviewed':
      if (payload['decision'] == 'rejected') {
        // Motivo da recusa e reenvio ficam nos documentos.
        navegador.pushNamed('/documentos');
      } else {
        navegador.pushNamed(
          entregador ? '/principal_entregador' : '/principal_estabelecimento',
        );
      }
      return true;
    case 'sanction.applied':
      empurrar(const TelaStatusConta());
      return true;
  }

  return false;
}
