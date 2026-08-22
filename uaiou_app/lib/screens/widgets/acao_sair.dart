import 'package:flutter/material.dart';
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
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text(
          'Você precisará entrar novamente para usar o aplicativo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Sair', style: TextStyle(color: _corPerigo)),
          ),
        ],
      ),
    );

    if (confirmou != true || !context.mounted) return;

    await context.read<ControladorSessao>().sair();

    // A raiz já trocou para a tela de entrada; esta tela está acima
    // dela na pilha e precisa sair.
    if (context.mounted) {
      Navigator.of(context).popUntil((rota) => rota.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _confirmarESair(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _corPerigo.withValues(alpha: .4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.logout, color: _corPerigo),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sair da conta',
                  style: TextStyle(fontSize: 16, color: _corPerigo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
