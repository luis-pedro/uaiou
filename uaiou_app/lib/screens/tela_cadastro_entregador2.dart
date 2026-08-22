import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/cadastro/rascunho_cadastro.dart';
import 'package:uaiou/screens/widgets/campo_cadastro.dart';

class CadastroEntregador2 extends StatefulWidget {
  const CadastroEntregador2({super.key});

  @override
  State<CadastroEntregador2> createState() => _CadastroEntregador2State();
}

class _CadastroEntregador2State extends State<CadastroEntregador2> {
  /// Só mostra erro depois da primeira tentativa de avançar —
  /// marcar campo vazio em vermelho antes de digitar é hostil.
  bool _mostrarErros = false;

  void _avancar(BuildContext context, RascunhoCadastro rascunho) {
    if (!rascunho.passoValido(PassoCadastro.perfil)) {
      setState(() => _mostrarErros = true);
      return;
    }
    Navigator.pushNamed(context, '/cadastro_entregador3');
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
            //padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //const SizedBox(height: 30),

                  // LOGO
                  Center(
                    child: Image.asset(
                      'assets/imagens/UaiOu_logo_horizontal.png',
                      height: 150,

                      fit: BoxFit.contain,
                    ),
                  ),

                  // Título
                  const Text(
                    "Quase lá...",
                    style: TextStyle(
                      fontSize: 32,
                      color: Color.fromRGBO(254, 98, 29, 1),
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Barra de progresso
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

                  // Placa do veículo
                  CampoCadastro(
                    rotulo: 'Placa do veículo',
                    valorInicial: rascunho.placa,
                    aoMudar: (v) => rascunho.placa = v,
                    erro: erros['Placa do veículo'],
                  ),

                  const SizedBox(height: 18),

                  // Rua
                  CampoCadastro(
                    rotulo: 'Rua',
                    valorInicial: rascunho.rua,
                    aoMudar: (v) => rascunho.rua = v,
                    erro: erros['Rua'],
                  ),

                  const SizedBox(height: 18),

                  // Endereço
                  CampoCadastro(
                    rotulo: 'Endereço',
                    valorInicial: rascunho.enderecoComplemento,
                    aoMudar: (v) => rascunho.enderecoComplemento = v,
                    erro: erros['Endereço'],
                  ),

                  const SizedBox(height: 18),

                  // Número
                  CampoCadastro(
                    rotulo: 'Número',
                    valorInicial: rascunho.numero,
                    aoMudar: (v) => rascunho.numero = v,
                    teclado: TextInputType.number,
                    erro: erros['Número'],
                  ),

                  const SizedBox(height: 18),

                  // Cidade
                  CampoCadastro(
                    rotulo: 'Cidade',
                    valorInicial: rascunho.cidade,
                    aoMudar: (v) => rascunho.cidade = v,
                    erro: erros['Cidade'],
                  ),

                  const SizedBox(height: 35),

                  // Botão Continuar
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

                  // Voltar
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
