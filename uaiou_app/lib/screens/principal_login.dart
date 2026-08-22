import 'package:flutter/material.dart';

class PrincipalLogin extends StatelessWidget {
  const PrincipalLogin({super.key});

  @override
  Widget build(BuildContext context) {
    // Pegando o tamanho da tela
    final largura = MediaQuery.of(context).size.width;
    final altura = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        width: largura,
        height: altura,
        color: const Color.fromRGBO(254, 98, 29, 1),
        child: Column(
          children: [
            // Parte superior laranja
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

            // Parte inferior branca
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 40,
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
                        children: [
                          // Botão Entrar
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/login');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromRGBO(
                                  254,
                                  98,
                                  29,
                                  1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                'Entrar',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Botão Cadastrar
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/cadastro');
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color.fromRGBO(254, 98, 29, 1),
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                'Cadastrar',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Color.fromRGBO(254, 98, 29, 1),
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
