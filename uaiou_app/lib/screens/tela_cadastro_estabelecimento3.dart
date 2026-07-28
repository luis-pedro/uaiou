import 'package:flutter/material.dart';

class CadastroEstabelecimento3 extends StatefulWidget {
  const CadastroEstabelecimento3({super.key});

  @override
  State<CadastroEstabelecimento3> createState() =>
      _CadastroEstabelecimento3State();
}

class _CadastroEstabelecimento3State
    extends State<CadastroEstabelecimento3> {

  bool lembrarSenha = false;
  bool esconderSenha = true;
  bool esconderConfirmacao = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            //padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),

            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // LOGO
                  Center(
                    child: Image.asset(
                      'assets/imagens/UaiOu_logo_horizontal.png',
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // TÍTULO
                  const Text(
                    'Pronto!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(254, 98, 29, 1),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // BARRA DE PROGRESSO
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: 1.0,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation(
                        Color.fromRGBO(108, 201, 80, 1),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // USUÁRIO
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Usuário',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

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

                  const SizedBox(height: 18),

                  // CONFIRMAR SENHA
                  TextField(
                    obscureText: esconderConfirmacao,
                    decoration: InputDecoration(
                      hintText: 'Confirme a senha',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          esconderConfirmacao
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            esconderConfirmacao =
                                !esconderConfirmacao;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // LEMBRAR SENHA
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
                        'Lembrar-se da senha',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // BOTÃO FINALIZAR
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Finalizar cadastro
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromRGBO(254, 98, 29, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Finalizar Cadastro',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // VOLTAR
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Voltar a tela anterior',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                  //const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}