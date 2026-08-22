import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/cadastro/rascunho_cadastro.dart';
import 'package:uaiou/screens/widgets/campo_cadastro.dart';

class CadastroEstabelecimento1 extends StatefulWidget {
  const CadastroEstabelecimento1({super.key});

  @override
  State<CadastroEstabelecimento1> createState() =>
      _CadastroEstabelecimento1State();
}

class _CadastroEstabelecimento1State extends State<CadastroEstabelecimento1> {
  /// Só mostra erro depois da primeira tentativa de avançar —
  /// marcar campo vazio em vermelho antes de digitar é hostil.
  bool _mostrarErros = false;

  void _avancar(BuildContext context, RascunhoCadastro rascunho) {
    if (!rascunho.passoValido(PassoCadastro.dadosPessoais)) {
      setState(() => _mostrarErros = true);
      return;
    }
    Navigator.pushNamed(context, '/cadastro_estabelecimento2');
  }

  @override
  Widget build(BuildContext context) {
    final rascunho = context.watch<RascunhoCadastro>();
    final erros = _mostrarErros
        ? rascunho.validar(PassoCadastro.dadosPessoais)
        : const <String, String>{};

    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            //padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),

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
                    'Crie uma conta',
                    style: TextStyle(
                      fontSize: 32,
                      color: Color.fromRGBO(254, 98, 29, 1),
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // BARRA DE PROGRESSO
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: 0.33,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation(
                        Color.fromRGBO(108, 201, 80, 1),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // NOME
                  CampoCadastro(
                    rotulo: 'Nome',
                    valorInicial: rascunho.nome,
                    aoMudar: (v) => rascunho.nome = v,
                    erro: erros['Nome'],
                  ),

                  const SizedBox(height: 18),

                  // EMAIL
                  CampoCadastro(
                    rotulo: 'Email',
                    valorInicial: rascunho.email,
                    aoMudar: (v) => rascunho.email = v,
                    teclado: TextInputType.emailAddress,
                    erro: erros['Email'],
                  ),

                  const SizedBox(height: 18),

                  // TELEFONE
                  CampoCadastro(
                    rotulo: 'Telefone',
                    valorInicial: rascunho.telefone,
                    aoMudar: (v) => rascunho.telefone = v,
                    teclado: TextInputType.phone,
                    erro: erros['Telefone'],
                  ),

                  const SizedBox(height: 18),

                  // DATA DE NASCIMENTO
                  CampoCadastro(
                    rotulo: 'Data de nascimento',
                    valorInicial: rascunho.dataNascimento,
                    aoMudar: (v) => rascunho.dataNascimento = v,
                    teclado: TextInputType.datetime,
                    erro: erros['Data de nascimento'],
                  ),

                  const SizedBox(height: 18),

                  // CPF
                  CampoCadastro(
                    rotulo: 'CPF',
                    valorInicial: rascunho.cpf,
                    aoMudar: (v) => rascunho.cpf = v,
                    teclado: TextInputType.number,
                    erro: erros['CPF'],
                  ),

                  const SizedBox(height: 35),

                  // BOTÃO PRÓXIMO
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        _avancar(context, rascunho);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(254, 98, 29, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Próximo',
                        style: TextStyle(color: Colors.white, fontSize: 18),
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
                        'Voltar a tela principal',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
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
