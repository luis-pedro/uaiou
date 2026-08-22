import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/cadastro/rascunho_cadastro.dart';
import 'package:uaiou/screens/widgets/campo_cadastro.dart';

class CadastroEstabelecimento2 extends StatefulWidget {
  const CadastroEstabelecimento2({super.key});

  @override
  State<CadastroEstabelecimento2> createState() =>
      _CadastroEstabelecimento2State();
}

class _CadastroEstabelecimento2State extends State<CadastroEstabelecimento2> {
  /// Só mostra erro depois da primeira tentativa de avançar —
  /// marcar campo vazio em vermelho antes de digitar é hostil.
  bool _mostrarErros = false;

  void _avancar(BuildContext context, RascunhoCadastro rascunho) {
    if (!rascunho.passoValido(PassoCadastro.perfil)) {
      setState(() => _mostrarErros = true);
      return;
    }
    Navigator.pushNamed(context, '/cadastro_estabelecimento3');
  }

  @override
  Widget build(BuildContext context) {
    final rascunho = context.watch<RascunhoCadastro>();
    final erros = _mostrarErros
        ? rascunho.validar(PassoCadastro.perfil)
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
                    'Quase lá...',
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
                      value: 0.66,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation(
                        Color.fromRGBO(108, 201, 80, 1),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // CNPJ
                  CampoCadastro(
                    rotulo: 'CNPJ',
                    valorInicial: rascunho.cnpj,
                    aoMudar: (v) => rascunho.cnpj = v,
                    teclado: TextInputType.number,
                    erro: erros['CNPJ'],
                  ),

                  const SizedBox(height: 18),

                  // RUA
                  CampoCadastro(
                    rotulo: 'Rua',
                    valorInicial: rascunho.rua,
                    aoMudar: (v) => rascunho.rua = v,
                    erro: erros['Rua'],
                  ),

                  const SizedBox(height: 18),

                  // ENDEREÇO
                  CampoCadastro(
                    rotulo: 'Endereço',
                    valorInicial: rascunho.enderecoComplemento,
                    aoMudar: (v) => rascunho.enderecoComplemento = v,
                    erro: erros['Endereço'],
                  ),

                  const SizedBox(height: 18),

                  // NÚMERO
                  CampoCadastro(
                    rotulo: 'Número',
                    valorInicial: rascunho.numero,
                    aoMudar: (v) => rascunho.numero = v,
                    teclado: TextInputType.number,
                    erro: erros['Número'],
                  ),

                  const SizedBox(height: 18),

                  // CIDADE
                  CampoCadastro(
                    rotulo: 'Cidade',
                    valorInicial: rascunho.cidade,
                    aoMudar: (v) => rascunho.cidade = v,
                    erro: erros['Cidade'],
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
                        'Voltar a tela anterior',
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
