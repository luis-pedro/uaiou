import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool lembrarSenha = false;
  bool esconderSenha = true;

  @override
  Widget build(BuildContext context) {
    final larguraTela = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),

            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400, // limita no computador
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // TÍTULO
                  const Text(
                    'Entre',
                    style: TextStyle(
                      fontSize: 32,
                      color: Color.fromRGBO(254, 98, 29, 1),
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // EMAIL
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Email ou usuário',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // SENHA
                  TextField(
                    obscureText: esconderSenha,
                    decoration: InputDecoration(
                      hintText: 'Senha',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          esconderSenha
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            esconderSenha = !esconderSenha;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // LEMBRAR / ESQUECEU
                  Row(
                    children: [
                      Checkbox(
                        value: lembrarSenha,
                        activeColor:
                            const Color.fromRGBO(254, 98, 29, 1),
                        onChanged: (valor) {
                          setState(() {
                            lembrarSenha = valor!;
                          });
                        },
                      ),

                      const Text(
                        'Lembrar-se de mim',
                        style: TextStyle(fontSize: 12),
                      ),

                      const Spacer(),

                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'Esqueceu sua senha?',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // BOTÃO ENTRAR
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromRGBO(254, 98, 29, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Entrar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // OU
                  const Center(
                    child: Text(
                      'Ou',
                      style: TextStyle(
                        color: Color.fromRGBO(254, 98, 29, 1),
                        fontSize: 16,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // LOGIN GOOGLE
                  //SizedBox(
                    //width: double.infinity,
                    //height: 52,
                    //child: OutlinedButton.icon(
                      //onPressed: () {},
                      //icon: Image.asset(
                        //'assets/imagens/Google1.png',
                        //height: 22,
                      //),
                      //label: const Text(
                        //'Entrar com Google',
                        //style: TextStyle(
                          //color: Colors.black87,
                        //),
                      //),
                      //style: OutlinedButton.styleFrom(
                        //shape: RoundedRectangleBorder(
                          //borderRadius:
                              //BorderRadius.circular(10),
                        //),
                     //),
                    //),
                  //),

                  const SizedBox(height: 30),

                  // CADASTRO
                  Center(
                    child: Wrap(
                      children: [
                        const Text(
                          'Ainda não possui conta? ',
                          style: TextStyle(fontSize: 12),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: const Text(
                            'Cadastre-se aqui',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Color.fromRGBO(254, 98, 29, 1),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (larguraTela > 800)
                    const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}