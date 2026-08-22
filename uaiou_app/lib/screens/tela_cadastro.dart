import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/cadastro/rascunho_cadastro.dart';
import 'package:uaiou/core/sessao/identidade.dart';

class TelaCadastro extends StatelessWidget {
  const TelaCadastro({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(254, 98, 29, 1),
      body: SafeArea(
        child: Column(
          children: [
            // PARTE SUPERIOR (laranja com logo)
            Expanded(
              flex: 6,
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/imagens/UaiOu_logo_branca.png',
                          height: 150,
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Pediu, entregou!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // PARTE INFERIOR (branca)
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 32,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),

                child: Center(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),

                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Você é?',
                            style: TextStyle(
                              fontSize: 30,
                              color: Color.fromRGBO(254, 98, 29, 1),
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 40),

                          // BOTÃO ESTABELECIMENTO
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: () {
                                // RF-A04.2 — a escolha vira o `role` do
                                // cadastro. É o único ponto em que o
                                // cliente decide o papel, e ele só
                                // propõe: quem confirma é o servidor.
                                context.read<RascunhoCadastro>().definirPapel(
                                  Papel.estabelecimento,
                                );
                                Navigator.pushNamed(
                                  context,
                                  '/cadastro_estabelecimento1',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromRGBO(
                                  254,
                                  98,
                                  29,
                                  1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Estabelecimento',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // BOTÃO ENTREGADOR
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: OutlinedButton(
                              onPressed: () {
                                context.read<RascunhoCadastro>().definirPapel(
                                  Papel.entregador,
                                );
                                Navigator.pushNamed(
                                  context,
                                  '/cadastro_entregador1',
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color.fromRGBO(254, 98, 29, 1),
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Entregador',
                                style: TextStyle(
                                  color: Color.fromRGBO(254, 98, 29, 1),
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // VOLTAR
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Voltar à tela principal',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
