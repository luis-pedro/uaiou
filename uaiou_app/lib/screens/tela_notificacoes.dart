import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/notificacoes/controlador_notificacoes.dart';
import 'package:uaiou/core/notificacoes/modelo_notificacao.dart';
import 'package:uaiou/core/sessao/controlador_sessao.dart';
import 'package:uaiou/core/sessao/identidade.dart';
import 'package:uaiou/screens/tela_detalhe_pedido.dart';
import 'package:uaiou/screens/tela_entrega_em_andamento.dart';
import 'package:uaiou/screens/widgets/visao_carregavel.dart';

/// ===============================================================
/// CAIXA DE ENTRADA — RF-A11.6/RF-A11.7/RF-A11.10
/// ===============================================================
///
/// Caminho de recuperação quando o push falha — e nesta v1 web ele
/// sempre "falha" por não existir (ver `controlador_notificacoes.dart`).
/// Por isso a busca é sempre ativa: ao abrir a tela e ao a aba voltar
/// a ficar em primeiro plano, nunca por push empurrando dado.
class TelaNotificacoes extends StatefulWidget {
  const TelaNotificacoes({super.key});

  @override
  State<TelaNotificacoes> createState() => _TelaNotificacoesState();
}

class _TelaNotificacoesState extends State<TelaNotificacoes>
    with WidgetsBindingObserver {
  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ControladorNotificacoes>().carregar();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A aba voltando ao primeiro plano é o mais próximo que a web tem
  /// de "app reaberto" — recarrega para pegar o que chegou enquanto
  /// estava em segundo plano, já que não há push empurrando.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ControladorNotificacoes>().recarregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controlador = context.watch<ControladorNotificacoes>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
        title: const Text('Notificações'),
        actions: [
          if (controlador.naoLidas > 0)
            TextButton(
              onPressed: controlador.marcandoTodas
                  ? null
                  : controlador.marcarTodasLidas,
              child: controlador.marcandoTodas
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Marcar todas',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: corPrincipal,
        onRefresh: controlador.recarregar,
        child: VisaoCarregavel<List<Notificacao>>(
          estado: controlador.estado,
          aoTentarNovamente: controlador.carregar,
          textoVazio: 'Nenhuma notificação por aqui ainda',
          iconeVazio: Icons.notifications_none,
          construir: (itens) => ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: itens.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, indice) =>
                _ItemNotificacao(notificacao: itens[indice]),
          ),
        ),
      ),
    );
  }
}

class _ItemNotificacao extends StatelessWidget {
  final Notificacao notificacao;

  const _ItemNotificacao({required this.notificacao});

  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  @override
  Widget build(BuildContext context) {
    final lida = notificacao.lida;
    final urgente = notificacao.priority == PrioridadeNotificacao.urgente;

    return ListTile(
      tileColor: lida ? Colors.white : corPrincipal.withValues(alpha: 0.06),
      leading: Icon(
        urgente ? Icons.priority_high : Icons.notifications_outlined,
        color: urgente ? Colors.red : (lida ? Colors.grey : corPrincipal),
      ),
      title: Text(
        notificacao.title.isEmpty ? notificacao.type : notificacao.title,
        style: TextStyle(
          fontWeight: lida ? FontWeight.normal : FontWeight.bold,
          color: const Color.fromRGBO(34, 34, 34, 1),
        ),
      ),
      subtitle: Text(
        notificacao.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: lida
          ? null
          : Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: corPrincipal,
                shape: BoxShape.circle,
              ),
            ),
      onTap: () => _abrir(context),
    );
  }

  /// RF-A11.5/RF-A11.10 — leva à tela do evento quando o `type`
  /// mapeia para uma que já existe no app; a tela de destino busca o
  /// estado dela na API própria, nunca renderiza direto do `payload`.
  /// Sem mapeamento conhecido, só marca como lida e expande aqui
  /// mesmo — a inbox nunca fica sem destino.
  Future<void> _abrir(BuildContext context) async {
    final controlador = context.read<ControladorNotificacoes>();
    if (!notificacao.lida) {
      await controlador.marcarLida(notificacao.id);
    }
    if (!context.mounted) return;

    final orderId = notificacao.payload['orderId'];
    final papel = context.read<ControladorSessao>().papel;

    switch (notificacao.type) {
      case 'counteroffer.received':
      case 'counteroffer.decided':
      case 'order.assigned':
      case 'order.published':
        if (orderId is String && papel == Papel.estabelecimento) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TelaDetalhePedido(pedidoId: orderId),
            ),
          );
          return;
        }
      case 'delivery.code_contingency':
      case 'delivery.completed':
      case 'delivery.contestable':
        if (orderId is String && papel == Papel.entregador) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TelaEntregaEmAndamento(pedidoId: orderId),
            ),
          );
          return;
        }
    }

    // Sem tela correspondente hoje (dispute.*, registration.reviewed,
    // sanction.applied, goal.*, support.replied, wallet.*): mostra o
    // detalhe aqui mesmo em vez de tentar abrir algo que não existe.
    _mostrarDetalhe(context);
  }

  void _mostrarDetalhe(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (contexto) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.isEmpty ? notificacao.type : title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(notificacao.body),
          ],
        ),
      ),
    );
  }

  String get title => notificacao.title;
}
