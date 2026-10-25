import 'package:flutter/material.dart';

import 'package:uaiou/core/tema/cores.dart';

/// Porta de entrada: marca em tela cheia e as duas ações empilhadas no
/// rodapé, ao alcance do polegar (padrão de apps de entregador como
/// Dasher e Uber Driver).
class PrincipalLogin extends StatelessWidget {
  const PrincipalLogin({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoresUaiou.principal,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/imagens/UaiOu_logo_branca.png',
                          height: 140,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'Pediu,\nentregou!',
                    style: TextStyle(
                      color: CoresUaiou.sobrePrincipal,
                      fontSize: 44,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Conecte seu estabelecimento a entregadores da '
                    'região — ou faça entregas e ganhe no seu ritmo.',
                    style: TextStyle(
                      color: CoresUaiou.sobrePrincipal.withValues(alpha: .88),
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/cadastro'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1C1917),
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const Text('Criar conta'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CoresUaiou.sobrePrincipal,
                      minimumSize: const Size.fromHeight(56),
                      side: BorderSide(
                        color: CoresUaiou.sobrePrincipal.withValues(alpha: .7),
                        width: 1.5,
                      ),
                    ),
                    child: const Text('Já tenho conta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
