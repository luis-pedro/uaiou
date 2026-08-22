import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/ganhos/controlador_ganhos.dart';
import 'package:uaiou/core/ganhos/modelo_ganhos.dart';
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

  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  @override
  State<TelaExtratoGanhos> createState() => _TelaExtratoGanhosState();
}

class _TelaExtratoGanhosState extends State<TelaExtratoGanhos> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ControladorGanhos>().carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
            if (controlador.selecionados.isNotEmpty) _buildBarraConfirmar(controlador),
          ],
        ),
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
            child: _buildValorResumo('Total do período', resumo.total.formatarBRL(), Colors.black87),
          ),
          Expanded(
            child: _buildValorResumo('A receber', resumo.receivable.formatarBRL(), Colors.orange.shade800),
          ),
          Expanded(
            child: _buildValorResumo('Recebido', resumo.settled.formatarBRL(), Colors.green.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildValorResumo(String rotulo, String valor, Color cor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cor),
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
    WidgetsBinding.instance.addPostFrameCallback((_) => controlador.carregarMais());
  }

  // RF-A09.5 — leitura visualmente distinta entre a receber e
  // recebido, e data + pedido de origem de cada lançamento.
  Widget _buildCardLancamento(Lancamento lancamento, ControladorGanhos controlador) {
    final selecionado = controlador.selecionados.contains(lancamento.id);
    final corStatus = lancamento.aReceber ? Colors.orange.shade800 : Colors.green.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selecionado ? TelaExtratoGanhos.corPrincipal.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selecionado ? TelaExtratoGanhos.corPrincipal : Colors.grey.shade300,
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
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.check_circle, color: Colors.green, size: 22),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lancamento.orderNumber.isNotEmpty
                      ? 'Pedido ${lancamento.orderNumber}'
                      : 'Pedido',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(_descricaoData(lancamento), style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                lancamento.amount.formatarBRL(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                  style: TextStyle(color: corStatus, fontSize: 11, fontWeight: FontWeight.bold),
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

  String _formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

  // BARRA DE CONFIRMAÇÃO — RF-A09.3.
  Widget _buildBarraConfirmar(ControladorGanhos controlador) {
    final qtd = controlador.selecionados.length;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))],
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
              onPressed: controlador.confirmando ? null : () => _confirmar(controlador),
              style: ElevatedButton.styleFrom(
                backgroundColor: TelaExtratoGanhos.corPrincipal,
                foregroundColor: Colors.white,
              ),
              child: controlador.confirmando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Confirmar recebimento'),
        content: Text(
          'Você está declarando que já recebeu, por fora da plataforma, '
          'o valor de $qtd lançamento${qtd == 1 ? '' : 's'} selecionado${qtd == 1 ? '' : 's'}.\n\n'
          'Esta ação não pode ser desfeita. Confirmar sem ter recebido o '
          'dinheiro cria uma divergência que só o suporte resolve.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Já recebi, confirmar'),
          ),
        ],
      ),
    );

    if (confirmou != true || !mounted) return;

    final ok = await controlador.confirmarSelecionados();
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recebimento confirmado.')),
      );
    } else {
      final erro = controlador.erro;
      if (erro != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      }
    }
  }
}
