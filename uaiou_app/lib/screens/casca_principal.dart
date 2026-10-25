import 'package:flutter/material.dart';

import 'package:uaiou/core/sessao/identidade.dart';
import 'package:uaiou/core/tema/cores.dart';
import 'package:uaiou/screens/tela_atividade_entregador.dart';
import 'package:uaiou/screens/tela_atividade_estabelecimento.dart';
import 'package:uaiou/screens/tela_entregas_entregador.dart';
import 'package:uaiou/screens/tela_estabelecimento_pedidos.dart';
import 'package:uaiou/screens/tela_perfil_entregador.dart';
import 'package:uaiou/screens/tela_perfil_estabelecimento.dart';
import 'package:uaiou/screens/tela_principal_entregador.dart';
import 'package:uaiou/screens/tela_principal_estabelecimento.dart';

/// ===============================================================
/// CASCA DE NAVEGAÇÃO
/// ===============================================================
///
/// Antes, cada aba era uma rota própria que desenhava a própria barra
/// inferior e trocava de aba com `pushReplacementNamed` — oito cópias da
/// mesma barra, e cada troca reconstruía a tela do zero (mapa incluso).
/// Aqui a barra é uma só e as abas ficam vivas num [IndexedStack]: voltar
/// para o Início não recarrega o mapa nem a vitrine.
///
/// As rotas antigas (`/entregas_entregador` etc.) continuam existindo e
/// abrem a casca já na aba certa — quem navega por nome não precisa mudar.
class CascaPrincipal extends StatefulWidget {
  const CascaPrincipal({super.key, required this.papel, this.abaInicial = 0});

  final Papel papel;
  final int abaInicial;

  /// Troca de aba a partir de qualquer tela dentro da casca. Devolve
  /// `false` quando não há casca acima (tela aberta por fora dela).
  static bool irPara(BuildContext context, int aba) {
    final estado = context.findAncestorStateOfType<_CascaPrincipalState>();
    if (estado == null) return false;
    estado._selecionar(aba);
    return true;
  }

  @override
  State<CascaPrincipal> createState() => _CascaPrincipalState();
}

class _Aba {
  const _Aba(this.rotulo, this.icone, this.iconeAtivo, this.tela);

  final String rotulo;
  final IconData icone;
  final IconData iconeAtivo;
  final Widget tela;
}

class _CascaPrincipalState extends State<CascaPrincipal> {
  late int _atual = widget.abaInicial;

  /// Abas só são construídas na primeira visita: montar as quatro de uma
  /// vez dispararia as cargas de todas no login.
  late final Set<int> _visitadas = {widget.abaInicial};

  List<_Aba> get _abas => widget.papel == Papel.estabelecimento
      ? const [
          _Aba(
            'Início',
            Icons.home_outlined,
            Icons.home_rounded,
            TelaPrincipalEstabelecimento(),
          ),
          _Aba(
            'Pedidos',
            Icons.receipt_long_outlined,
            Icons.receipt_long_rounded,
            TelaPedidosEstabelecimento(),
          ),
          _Aba(
            'Atividade',
            Icons.bar_chart_rounded,
            Icons.bar_chart_rounded,
            TelaAtividadesEstabelecimento(),
          ),
          _Aba(
            'Perfil',
            Icons.person_outline_rounded,
            Icons.person_rounded,
            TelaPerfilEstabelecimento(),
          ),
        ]
      : const [
          _Aba(
            'Início',
            Icons.explore_outlined,
            Icons.explore_rounded,
            TelaPrincipalEntregador(),
          ),
          _Aba(
            'Entregas',
            Icons.inventory_2_outlined,
            Icons.inventory_2_rounded,
            TelaEntregasEntregador(),
          ),
          _Aba(
            'Atividade',
            Icons.bar_chart_rounded,
            Icons.bar_chart_rounded,
            TelaAtividadesEntregador(),
          ),
          _Aba(
            'Perfil',
            Icons.person_outline_rounded,
            Icons.person_rounded,
            TelaPerfilEntregador(),
          ),
        ];

  void _selecionar(int aba) {
    if (aba == _atual) return;
    setState(() {
      _atual = aba;
      _visitadas.add(aba);
    });
  }

  @override
  Widget build(BuildContext context) {
    final abas = _abas;
    final cores = context.cores;

    return Scaffold(
      body: IndexedStack(
        index: _atual,
        children: [
          for (final (i, aba) in abas.indexed)
            _visitadas.contains(i) ? aba.tela : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cores.borda)),
        ),
        child: NavigationBar(
          selectedIndex: _atual,
          onDestinationSelected: _selecionar,
          height: 68,
          backgroundColor: cores.superficie,
          surfaceTintColor: Colors.transparent,
          indicatorColor: CoresUaiou.principal.withValues(alpha: .14),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final aba in abas)
              NavigationDestination(
                icon: Icon(aba.icone, color: cores.textoSuave),
                selectedIcon: Icon(aba.iconeAtivo, color: CoresUaiou.principal),
                label: aba.rotulo,
              ),
          ],
        ),
      ),
    );
  }
}
