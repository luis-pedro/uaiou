import 'package:flutter/material.dart';

import 'package:uaiou/screens/widgets/dialogo_padrao.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/sessao/controlador_sessao.dart';

/// Saída da conta — RF-A02.7, com a confirmação que RF-A05.8 pede.
///
/// Compartilhado pelos dois perfis: sem uma porta na interface, o
/// logout existiria só nos testes.
class AcaoSair extends StatelessWidget {
  const AcaoSair({super.key});

  static const Color _corPerigo = Color.fromRGBO(211, 47, 47, 1);

  Future<void> _confirmarESair(BuildContext context) async {
    final confirmou = await confirmar(
      context,
      titulo: 'Sair da conta',
      mensagem: 'Você precisará entrar novamente para usar o aplicativo.',
      rotuloConfirmar: 'Sair',
      icone: Icons.logout_rounded,
      destrutivo: true,
    );

    if (!confirmou || !context.mounted) return;

    await context.read<ControladorSessao>().sair();

    // A raiz já trocou para a tela de entrada; esta tela está acima
    // dela na pilha e precisa sair.
    if (context.mounted) {
      Navigator.of(context).popUntil((rota) => rota.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _confirmarESair(context),
        style: TextButton.styleFrom(
          foregroundColor: _corPerigo,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text(
          'Sair da conta',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
