import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/cadastro/rascunho_cadastro.dart';
import 'package:uaiou/core/sessao/identidade.dart';
import 'package:uaiou/core/tema/cores.dart';

/// Porta de entrada do cadastro — a tela de identidade do UaiOu.
///
/// Mantém o que ela sempre foi — laranja da marca, logo, "Pediu, entregou!"
/// e "Você é?" com os dois botões —, com acabamento atualizado.
class TelaCadastro extends StatelessWidget {
  const TelaCadastro({super.key});

  void _escolher(BuildContext context, Papel papel) {
    context.read<RascunhoCadastro>().definirPapel(papel);
    Navigator.pushNamed(context, '/cadastro_dados');
  }

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final baseInferior = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: CoresUaiou.principal,
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned(
                    top: 4,
                    left: 4,
                    child: IconButton(
                      tooltip: 'Voltar',
                      color: Colors.white,
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/imagens/UaiOu_logo_branca.png',
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Pediu, entregou!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + baseInferior),
            decoration: BoxDecoration(
              color: cores.fundo,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Você é?',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: cores.texto,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () =>
                          _escolher(context, Papel.estabelecimento),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Estabelecimento'),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: () => _escolher(context, Papel.entregador),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                        foregroundColor: CoresUaiou.principal,
                        side: const BorderSide(
                          color: CoresUaiou.principal,
                          width: 2,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Entregador'),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Já tem conta? ',
                            style: TextStyle(color: cores.textoSuave),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacementNamed(
                              context,
                              '/login',
                            ),
                            child: const Text(
                              'Entrar',
                              style: TextStyle(
                                color: CoresUaiou.principal,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
