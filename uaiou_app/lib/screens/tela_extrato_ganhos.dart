import 'package:flutter/material.dart';

import 'package:uaiou/screens/widgets/dialogo_padrao.dart';
import 'package:uaiou/core/formato/data.dart';
import 'package:uaiou/core/tema/cores.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/feira/controlador_feira.dart';
import 'package:uaiou/core/feira/modelos_feira.dart';
import 'package:uaiou/core/ganhos/controlador_ganhos.dart';
import 'package:uaiou/main.dart' show feiraNestaBranch;
import 'package:uaiou/core/ganhos/modelo_ganhos.dart';
import 'package:uaiou/screens/widgets/aviso_flutuante.dart';
import 'package:uaiou/screens/widgets/visao_carregavel.dart';

/// ===============================================================
/// EXTRATO DE GANHOS — RF-A09.3/RF-A09.4/RF-A09.5/RF-A09.6
/// ===============================================================
///
/// Lista os lançamentos de `GET /me/earnings`, deixa o entregador
/// selecionar um ou vários "a receber" e confirmar o acerto por
/// `POST /me/earnings/settlements`. **A confirmação é irreversível**
/// (RF-A09.4): não há estorno na v1, então o diálogo é explícito sobre
/// o que está sendo declarado.
class TelaExtratoGanhos extends StatefulWidget {
  const TelaExtratoGanhos({super.key});

  static const Color corPrincipal = CoresUaiou.principal;

  @override
  State<TelaExtratoGanhos> createState() => _TelaExtratoGanhosState();
}

class _TelaExtratoGanhosState extends State<TelaExtratoGanhos> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (feiraNestaBranch) {
        context.read<ControladorFeira>()
          ..carregarCapturas()
          ..carregarBonus();
      } else {
        context.read<ControladorGanhos>().carregar();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (feiraNestaBranch) return _buildExtratoDePremios(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: TelaExtratoGanhos.corPrincipal,
        foregroundColor: Colors.white,
        title: const Text('Extrato de ganhos'),
      ),
      body: Consumer<ControladorGanhos>(
        builder: (context, controlador, _) => Column(
          children: [
            _buildResumo(controlador),
            Expanded(child: _buildLista(controlador)),
            if (controlador.selecionados.isNotEmpty)
              _buildBarraConfirmar(controlador),
          ],
        ),
      ),
    );
  }

  /// Modo feira (docs/feira/): o extrato é a lista de prêmios conquistados,
  /// com o texto da recompensa no lugar do valor. O livro-razão do produto não
  /// serve aqui — na feira não há lançamento de dinheiro nenhum, então a tela
  /// original mostraria uma lista permanentemente vazia.
  Widget _buildExtratoDePremios(BuildContext context) {
    final feira = context.watch<ControladorFeira>();
    final capturas = feira.capturas;
    final bonus = feira.bonus;
    // Com bônus cadastrados, a seção deles é o primeiro item da lista.
    final cabecalho = bonus.isEmpty ? 0 : 1;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: TelaExtratoGanhos.corPrincipal,
        foregroundColor: Colors.white,
        title: const Text('Seus prêmios'),
      ),
      body: RefreshIndicator(
        onRefresh: () {
          final controlador = context.read<ControladorFeira>();
          return Future.wait([
            controlador.carregarCapturas(),
            controlador.carregarBonus(),
          ]);
        },
        child: capturas.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (bonus.isNotEmpty) _buildSecaoBonus(context, bonus),
                  SizedBox(height: bonus.isEmpty ? 74 : 16),
                  Center(
                    child: Text(
                      'Você ainda não conquistou nenhum prêmio.',
                      style: TextStyle(color: context.cores.textoSuave),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: capturas.length + cabecalho,
                separatorBuilder: (_, indice) =>
                    SizedBox(height: indice < cabecalho ? 0 : 10),
                itemBuilder: (_, indice) {
                  if (indice < cabecalho) {
                    return _buildSecaoBonus(context, bonus);
                  }
                  final captura = capturas[indice - cabecalho];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.cores.superficie,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: context.cores.borda),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          captura.entregue
                              ? Icons.check_circle
                              : Icons.card_giftcard,
                          color: captura.entregue
                              ? context.cores.positivo
                              : TelaExtratoGanhos.corPrincipal,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                captura.recompensa,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                captura.entregue
                                    ? 'Retirado no estande'
                                    : 'Retire no estande do UaiOu',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.cores.textoSuave,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  /// Bônus por meta, acima dos prêmios: o que falta para o próximo é o que
  /// faz o visitante voltar e pegar mais um pedido.
  Widget _buildSecaoBonus(BuildContext context, List<BonusFeira> bonus) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bônus',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        for (final item in bonus) ...[
          _buildCardBonus(context, item),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        const Text(
          'Prêmios',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildCardBonus(BuildContext context, BonusFeira bonus) {
    final cor = bonus.conquistado
        ? context.cores.positivo
        : TelaExtratoGanhos.corPrincipal;
    final String situacao;
    if (bonus.entregue) {
      situacao = 'Retirado no estande';
    } else if (bonus.conquistado) {
      situacao = 'Conquistado! Retire no estande do UaiOu';
    } else {
      situacao =
          'Faltam ${bonus.faltam} ${bonus.faltam == 1 ? 'entrega' : 'entregas'}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cores.superficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: bonus.conquistado ? cor : context.cores.borda,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                bonus.conquistado ? Icons.emoji_events : Icons.flag_outlined,
                color: cor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bonus.titulo,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${bonus.meta} ${bonus.meta == 1 ? 'entrega' : 'entregas'} = ${bonus.recompensa}',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.cores.textoSuave,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: bonus.conquistado ? 1 : bonus.progresso,
              minHeight: 8,
              color: cor,
              backgroundColor: context.cores.borda,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bonus.conquistado
                ? situacao
                : '${bonus.entregas.clamp(0, bonus.meta)}/${bonus.meta} · $situacao',
            style: TextStyle(fontSize: 13, color: context.cores.textoSuave),
          ),
        ],
      ),
    );
  }

  // RESUMO DO PERÍODO — RF-A09.1/RF-A09.2. Sempre o `summary` do
  // servidor, nunca soma feita aqui.
  Widget _buildResumo(ControladorGanhos controlador) {
    final resumo = controlador.resumo;
    return Container(
      padding: const EdgeInsets.all(20),
      color: TelaExtratoGanhos.corPrincipal.withValues(alpha: 0.06),
      child: Row(
        children: [
          Expanded(
            child: _buildValorResumo(
              'Total do período',
              resumo.total.formatarBRL(),
              context.cores.texto,
            ),
          ),
          Expanded(
            child: _buildValorResumo(
              'A receber',
              resumo.receivable.formatarBRL(),
              context.cores.atencao,
            ),
          ),
          Expanded(
            child: _buildValorResumo(
              'Recebido',
              resumo.settled.formatarBRL(),
              context.cores.positivo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValorResumo(String rotulo, String valor, Color cor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: TextStyle(fontSize: 12, color: context.cores.textoSuave),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
      ],
    );
  }

  Widget _buildLista(ControladorGanhos controlador) {
    return RefreshIndicator(
      color: TelaExtratoGanhos.corPrincipal,
      onRefresh: controlador.recarregar,
      child: VisaoCarregavel<List<Lancamento>>(
        estado: controlador.estado,
        aoTentarNovamente: controlador.carregar,
        textoVazio: 'Nenhum lançamento neste período',
        iconeVazio: Icons.receipt_long_outlined,
        construir: (itens) => ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: itens.length + (controlador.temMais ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= itens.length) {
              _pedirMais(controlador);
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _buildCardLancamento(itens[index], controlador);
          },
        ),
      ),
    );
  }

  void _pedirMais(ControladorGanhos controlador) {
    if (controlador.carregandoMais) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => controlador.carregarMais(),
    );
  }

  // RF-A09.5 — leitura visualmente distinta entre a receber e
  // recebido, e data + pedido de origem de cada lançamento.
  Widget _buildCardLancamento(
    Lancamento lancamento,
    ControladorGanhos controlador,
  ) {
    final selecionado = controlador.selecionados.contains(lancamento.id);
    final corStatus = lancamento.aReceber
        ? context.cores.atencao
        : context.cores.positivo;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selecionado
            ? TelaExtratoGanhos.corPrincipal.withValues(alpha: 0.08)
            : context.cores.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selecionado
              ? TelaExtratoGanhos.corPrincipal
              : context.cores.borda,
          width: selecionado ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          if (lancamento.aReceber)
            Checkbox(
              value: selecionado,
              activeColor: TelaExtratoGanhos.corPrincipal,
              onChanged: (_) => controlador.alternarSelecao(lancamento.id),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.check_circle,
                color: context.cores.positivo,
                size: 22,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (lancamento.taxaDeCancelamento) 'Taxa de cancelamento —',
                    lancamento.orderNumber.isNotEmpty
                        ? 'Pedido ${lancamento.orderNumber}'
                        : 'Pedido',
                  ].join(' '),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _descricaoData(lancamento),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.cores.textoSuave,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                lancamento.amount.formatarBRL(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: corStatus.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  lancamento.aReceber ? 'A receber' : 'Recebido',
                  style: TextStyle(
                    color: corStatus,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _descricaoData(Lancamento lancamento) {
    final criado = lancamento.createdAt;
    final acertado = lancamento.settledAt;
    final formatado = criado == null ? '—' : _formatarData(criado);
    if (acertado == null) return 'Entregue em $formatado';
    return 'Entregue em $formatado · recebido em ${_formatarData(acertado)}';
  }

  String _formatarData(DateTime data) => formatarData(data);

  // BARRA DE CONFIRMAÇÃO — RF-A09.3.
  Widget _buildBarraConfirmar(ControladorGanhos controlador) {
    final qtd = controlador.selecionados.length;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cores.superficie,
          boxShadow: [
            BoxShadow(
              color: context.cores.sombra,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$qtd lançamento${qtd == 1 ? '' : 's'} selecionado${qtd == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: controlador.confirmando
                  ? null
                  : () => _confirmar(controlador),
              style: ElevatedButton.styleFrom(
                backgroundColor: TelaExtratoGanhos.corPrincipal,
                foregroundColor: Colors.white,
              ),
              child: controlador.confirmando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirmar recebimento'),
            ),
          ],
        ),
      ),
    );
  }

  /// RF-A09.4 — a confirmação exige passo explícito e deixa claro que
  /// declara dinheiro **já recebido por fora**, sem estorno na v1.
  Future<void> _confirmar(ControladorGanhos controlador) async {
    final qtd = controlador.selecionados.length;
    final confirmou = await confirmar(
      context,
      titulo: 'Confirmar recebimento',
      mensagem:
          'Você está declarando que já recebeu, por fora da plataforma, '
          'o valor de $qtd lançamento${qtd == 1 ? '' : 's'} selecionado${qtd == 1 ? '' : 's'}.\n\n'
          'Esta ação não pode ser desfeita. Confirmar sem ter recebido o '
          'dinheiro cria uma divergência que só o suporte resolve.',
      rotuloConfirmar: 'Já recebi, confirmar',
      icone: Icons.payments_outlined,
    );

    if (!confirmou || !mounted) return;

    final ok = await controlador.confirmarSelecionados();
    if (!mounted) return;

    if (ok) {
      mostrarAviso(context, 'Recebimento confirmado.');
    } else {
      final erro = controlador.erro;
      if (erro != null) mostrarAviso(context, erro, erro: true);
    }
  }
}
