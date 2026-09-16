import 'package:flutter/material.dart';

import 'package:uaiou/core/formato/data.dart';
import 'package:uaiou/core/tema/cores.dart';
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
  static const Color corPrincipal = CoresUaiou.principal;

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
            // O fim da lista respeita a barra de navegação do celular.
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            itemCount: itens.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
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

  static const Color corPrincipal = CoresUaiou.principal;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final lida = notificacao.lida;
    final urgente = notificacao.priority == PrioridadeNotificacao.urgente;
    final destaque = urgente ? CoresUaiou.perigo : corPrincipal;
    final data = notificacao.createdAt;

    // Cartão com a mesma estrutura em todas: ícone, título de uma linha,
    // corpo de até duas e data — a lista não fica com alturas aleatórias.
    return Material(
      color: lida ? cores.superficie : destaque.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: lida ? cores.borda : destaque.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrir(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconeNotificacao(urgente: urgente, lida: lida),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.isEmpty ? notificacao.type : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: lida
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                              color: cores.texto,
                            ),
                          ),
                        ),
                        if (!lida)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: destaque,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (notificacao.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notificacao.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: cores.textoSuave,
                        ),
                      ),
                    ],
                    if (data != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        descreverData(data),
                        style: TextStyle(fontSize: 12, color: cores.textoSuave),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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

  /// Folha com altura estável (não "pula" conforme o tamanho do texto),
  /// rolável para mensagens longas e com o botão acima da barra de
  /// navegação do celular.
  void _mostrarDetalhe(BuildContext context) {
    final urgente = notificacao.priority == PrioridadeNotificacao.urgente;
    final data = notificacao.createdAt;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (contexto) {
        final cores = contexto.cores;
        final altura = MediaQuery.sizeOf(contexto).height;
        final inferior = MediaQuery.viewPaddingOf(contexto).bottom;

        // Altura fixa: toda notificação abre do mesmo tamanho, e o texto
        // longo rola dentro dela.
        return SizedBox(
          height: altura * 0.6,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + inferior),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _IconeNotificacao(urgente: urgente, lida: false),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.isEmpty ? notificacao.type : title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: cores.texto,
                            ),
                          ),
                          if (data != null)
                            Text(
                              descreverData(data),
                              style: TextStyle(
                                fontSize: 13,
                                color: cores.textoSuave,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: cores.borda),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      notificacao.body.isEmpty
                          ? 'Sem detalhes adicionais.'
                          : notificacao.body,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: cores.texto,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(contexto),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Entendi'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String get title => notificacao.title;
}

class _IconeNotificacao extends StatelessWidget {
  final bool urgente;
  final bool lida;

  const _IconeNotificacao({required this.urgente, required this.lida});

  @override
  Widget build(BuildContext context) {
    final cor = urgente
        ? CoresUaiou.perigo
        : (lida ? context.cores.textoSuave : CoresUaiou.principal);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        urgente
            ? Icons.notification_important_rounded
            : Icons.notifications_rounded,
        color: cor,
        size: 22,
      ),
    );
  }
}
