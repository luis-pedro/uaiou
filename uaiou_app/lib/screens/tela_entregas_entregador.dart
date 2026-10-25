import 'package:flutter/material.dart';

import 'package:uaiou/core/tema/cores.dart';
import 'package:uaiou/screens/widgets/ui.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/pedidos/lista_de_pedidos.dart';
import 'package:uaiou/others/pedido.dart';
import 'package:uaiou/others/entregador_service.dart';
import 'package:uaiou/screens/widgets/badge_status.dart';
import 'package:uaiou/screens/widgets/visao_carregavel.dart';

class TelaEntregasEntregador extends StatefulWidget {
  const TelaEntregasEntregador({super.key});

  @override
  State<TelaEntregasEntregador> createState() => _TelaEntregasEntregadorState();
}

class _TelaEntregasEntregadorState extends State<TelaEntregasEntregador> {
  /// Cor principal do aplicativo
  static const Color corPrincipal = CoresUaiou.principal;

  @override
  void initState() {
    super.initState();
    // RNF-A03.1 — carga tem ciclo de vida próprio; `build` roda
    // muitas vezes e não pode disparar requisição.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EstadoEntregador>().carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PaginaAba(
      titulo: 'Entregas',
      subtitulo: 'O que está com você agora',
      filho: _buildConteudo(),
    );
  }

  /// ============================================================
  /// CONTEÚDO PRINCIPAL
  /// ============================================================

  Widget _buildConteudo() => _buildLista();

  /// ============================================================
  /// LISTA (seções: pendentes / concluídas)
  /// ============================================================

  /// Duas listas independentes, cada uma com o próprio recorte no
  /// servidor e o próprio estado de carga (RF-A03.3/RF-A03.5).
  Widget _buildLista() {
    final estado = context.watch<EstadoEntregador>();

    return RefreshIndicator(
      // RF-A03.6
      color: corPrincipal,
      onRefresh: estado.emAndamento.recarregar,
      child: ListView(
        // O vão do fim acompanha a barra, senão o último card fica atrás dela.
        padding: EdgeInsets.fromLTRB(20, 25, 20, 24),
        // Sem isto, puxar não funciona quando a lista é curta demais
        // para rolar — que é justamente o caso do estado vazio.
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Só o que está em andamento: concluídas e canceladas viraram
          // histórico, na tela de Atividades. Misturar as duas coisas fazia o
          // entregador rolar por entregas antigas para achar a de agora.
          _buildSecao(estado.emAndamento, vazio: "Nenhuma entrega pendente"),
        ],
      ),
    );
  }

  /// Observa a **própria lista**, não a loja que a contém.
  ///
  /// Depender do repasse da loja é frágil — e foi exatamente o que
  /// deixou esta tela girando para sempre com a requisição já
  /// respondida. Aqui, quem muda é quem avisa, e só esta seção
  /// reconstrói.
  Widget _buildSecao(ListaDePedidos lista, {required String vazio}) {
    return ListenableBuilder(
      listenable: lista,
      builder: (context, _) => VisaoCarregavel<List<Pedido>>(
        estado: lista.estado,
        aoTentarNovamente: lista.carregar,
        textoVazio: vazio,
        iconeVazio: Icons.local_shipping_outlined,
        construir: (entregas) => Column(
          children: [
            ...entregas.map((entrega) => _buildCardEntrega(context, entrega)),
            if (lista.temMais) _buildCarregarMais(lista),
          ],
        ),
      ),
    );
  }

  /// RF-A03.7 — a próxima página vem do `_links.next` do servidor.
  Widget _buildCarregarMais(ListaDePedidos lista) {
    if (lista.carregandoMais) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: CircularProgressIndicator(color: corPrincipal),
      );
    }

    return TextButton(
      onPressed: lista.carregarMais,
      child: const Text("Carregar mais", style: TextStyle(color: corPrincipal)),
    );
  }

  /// ============================================================
  /// CARD DA ENTREGA
  /// ============================================================

  Widget _buildCardEntrega(BuildContext context, Pedido entrega) {
    final cores = context.cores;
    // RF-A08.2 — pedido aceito abre a execução da entrega; demais estados
    // não têm ação aqui ainda.
    final abrir = entrega.status == StatusPedido.aceito
        ? () => Navigator.pushNamed(
            context,
            '/entrega_em_andamento',
            arguments: entrega.id,
          )
        : null;

    return Cartao(
      margem: const EdgeInsets.only(bottom: 12),
      aoTocar: abrir,
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconeTingido(Icons.storefront_rounded, tamanho: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entrega.nomeEstabelecimento?.isNotEmpty == true
                          ? entrega.nomeEstabelecimento!
                          : "Pedido ${entrega.rotuloCurto}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cores.texto,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // O endereço vem no detalhe que o servidor permitiu: na
                    // vitrine, só o bairro (RF-11.6).
                    Text(
                      entrega.enderecoResumido,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: cores.textoSuave),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BadgeStatus(entrega.status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (entrega.minutosDesdeAceite != null)
                _buildChipTempo(entrega.minutosDesdeAceite!),
              const Spacer(),
              if (abrir != null)
                FilledButton.icon(
                  onPressed: abrir,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text("Continuar"),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChipTempo(int minutos) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_rounded, size: 16, color: context.cores.textoSuave),
        const SizedBox(width: 4),
        Text(
          "há $minutos min",
          style: TextStyle(fontSize: 13, color: context.cores.textoSuave),
        ),
      ],
    );
  }
}
