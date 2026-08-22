import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/avaliacoes/controlador_avaliacoes.dart';
import 'package:uaiou/core/avaliacoes/modelo_avaliacao.dart';
import 'package:uaiou/screens/widgets/visao_carregavel.dart';

/// ===============================================================
/// AVALIAÇÕES — A-12
/// ===============================================================
///
/// Duas abas: "Pendentes" (RF-A12.1, `GET /me/reviews?direction=pending`)
/// e "Recebidas" (RF-A12.7, `GET /me/reviews?direction=received`).
/// Acessível do perfil dos dois papéis — a avaliação é mútua.
///
/// **Lacunas reais do backend, documentadas aqui de propósito:**
/// - Não existe `GET /orders/{id}/reviews` (RF-A12.3 tal como descrito
///   na spec não tem contraparte real): não há como ler, pedido a
///   pedido, o que a contraparte escreveu. A aba "Recebidas" é a
///   leitura cruzada que o contrato real permite — agregada, não por
///   pedido específico.
/// - "Pendentes" e "Recebidas" não têm paginação no backend
///   (`ReceivedReviewsResponse`/`List<PendingReviewEntry>` vêm
///   inteiros, sem `_links`/`meta.page`), então esta tela não pagina —
///   mostra tudo que veio, sem inventar paginação client-side.
class TelaAvaliacoes extends StatefulWidget {
  const TelaAvaliacoes({super.key});

  @override
  State<TelaAvaliacoes> createState() => _TelaAvaliacoesState();
}

class _TelaAvaliacoesState extends State<TelaAvaliacoes> {
  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ControladorAvaliacoes>().carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: corPrincipal,
          foregroundColor: Colors.white,
          title: const Text('Avaliações'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'Pendentes'), Tab(text: 'Recebidas')],
          ),
        ),
        body: const TabBarView(
          children: [_AbaPendentes(), _AbaRecebidas()],
        ),
      ),
    );
  }
}

class _AbaPendentes extends StatelessWidget {
  const _AbaPendentes();

  @override
  Widget build(BuildContext context) {
    final controlador = context.watch<ControladorAvaliacoes>();

    return RefreshIndicator(
      onRefresh: controlador.recarregar,
      child: VisaoCarregavel<List<AvaliacaoPendente>>(
        estado: controlador.pendentes,
        aoTentarNovamente: controlador.recarregar,
        textoVazio: 'Nada pendente de avaliar por aqui.',
        iconeVazio: Icons.check_circle_outline,
        construir: (itens) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: itens.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, indice) => _CardPendente(item: itens[indice]),
        ),
      ),
    );
  }
}

class _CardPendente extends StatelessWidget {
  final AvaliacaoPendente item;

  const _CardPendente({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(254, 98, 29, .06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pedido #${item.orderNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  item.counterpartyName.isEmpty
                      ? 'Contraparte'
                      : item.counterpartyName,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                if (item.deadline != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Prazo: ${_formatarData(item.deadline!)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _abrirAvaliar(context, item),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(254, 98, 29, 1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Avaliar'),
          ),
        ],
      ),
    );
  }

  String _formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';

  Future<void> _abrirAvaliar(BuildContext context, AvaliacaoPendente item) async {
    final controlador = context.read<ControladorAvaliacoes>();
    final enviado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormularioAvaliacao(item: item, controlador: controlador),
    );
    if (enviado == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avaliação enviada.')),
      );
    }
  }
}

class _FormularioAvaliacao extends StatefulWidget {
  final AvaliacaoPendente item;
  final ControladorAvaliacoes controlador;

  const _FormularioAvaliacao({required this.item, required this.controlador});

  @override
  State<_FormularioAvaliacao> createState() => _FormularioAvaliacaoState();
}

class _FormularioAvaliacaoState extends State<_FormularioAvaliacao> {
  int _nota = 5;
  final _comentarioController = TextEditingController();

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enviando = widget.controlador.enviando;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Avaliar pedido #${widget.item.orderNumber}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final valor = i + 1;
              return IconButton(
                onPressed: () => setState(() => _nota = valor),
                icon: Icon(
                  valor <= _nota ? Icons.star : Icons.star_border,
                  color: const Color.fromRGBO(254, 98, 29, 1),
                  size: 32,
                ),
              );
            }),
          ),
          TextField(
            controller: _comentarioController,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Comentário (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (widget.controlador.erroEnvio != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.controlador.erroEnvio!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: enviando ? null : _enviar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(254, 98, 29, 1),
                foregroundColor: Colors.white,
              ),
              child: enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Enviar avaliação'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enviar() async {
    final ok = await widget.controlador.avaliar(
      widget.item.orderId,
      rating: _nota,
      comment: _comentarioController.text,
    );
    if (ok && mounted) Navigator.pop(context, true);
  }
}

class _AbaRecebidas extends StatelessWidget {
  const _AbaRecebidas();

  @override
  Widget build(BuildContext context) {
    final controlador = context.watch<ControladorAvaliacoes>();

    return RefreshIndicator(
      onRefresh: controlador.recarregar,
      child: VisaoCarregavel<RespostaAvaliacoesRecebidas>(
        estado: controlador.recebidas,
        aoTentarNovamente: controlador.recarregar,
        textoVazio: 'Nenhuma avaliação recebida ainda.',
        iconeVazio: Icons.star_border,
        construir: (resposta) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _CardResumo(resumo: resposta.resumo),
            const SizedBox(height: 16),
            for (final item in resposta.itens) ...[
              _CardRecebida(item: item),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardResumo extends StatelessWidget {
  final ResumoAvaliacoesRecebidas resumo;

  const _CardResumo({required this.resumo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(254, 98, 29, .08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _EstatisticaResumo(
            rotulo: 'Média',
            valor: resumo.average.toStringAsFixed(1).replaceAll('.', ','),
          ),
          // RF-A12.2 — mostrada lado a lado com a média para que uma
          // nota alta formada por avaliações automáticas (padrão
          // positivo do job) não seja lida como excelência real.
          _EstatisticaResumo(
            rotulo: 'Ativas',
            valor: '${(resumo.activeRate * 100).toStringAsFixed(0)}%',
          ),
          _EstatisticaResumo(rotulo: 'Total', valor: '${resumo.count}'),
        ],
      ),
    );
  }
}

class _EstatisticaResumo extends StatelessWidget {
  final String rotulo;
  final String valor;

  const _EstatisticaResumo({required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(rotulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _CardRecebida extends StatelessWidget {
  final AvaliacaoRecebida item;

  const _CardRecebida({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color.fromRGBO(94, 94, 94, .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < item.rating ? Icons.star : Icons.star_border,
                    size: 16,
                    color: const Color.fromRGBO(254, 98, 29, 1),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Pedido #${item.orderNumber}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          if (item.comment != null && item.comment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.comment!),
          ],
          if (!item.active) ...[
            const SizedBox(height: 6),
            const Text(
              'Automática (padrão positivo)',
              style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}
