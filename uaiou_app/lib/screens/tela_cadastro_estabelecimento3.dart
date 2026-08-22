import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/cadastro/controlador_cadastro.dart';
import 'package:uaiou/core/cadastro/rascunho_cadastro.dart';
import 'package:uaiou/screens/widgets/campo_cadastro.dart';

class CadastroEstabelecimento3 extends StatefulWidget {
  const CadastroEstabelecimento3({super.key});

  /// RF-A04.1 — o envio acontece só aqui, na confirmação final.
  @override
  State<CadastroEstabelecimento3> createState() =>
      _CadastroEstabelecimento3State();
}

class _CadastroEstabelecimento3State extends State<CadastroEstabelecimento3> {
  /// Só mostra erro depois da primeira tentativa de avançar —
  /// marcar campo vazio em vermelho antes de digitar é hostil.
  bool _mostrarErros = false;

  Future<void> _concluir(
    BuildContext context,
    RascunhoCadastro rascunho,
  ) async {
    setState(() => _mostrarErros = true);
    if (!rascunho.passoValido(PassoCadastro.credenciais)) return;

    final controlador = context.read<ControladorCadastro>();
    final concluido = await controlador.concluir(rascunho);
    if (!context.mounted) return;

    if (concluido) {
      // A raiz observa a sessão e já mostra a tela de análise
      // (RF-A04.8); esta tela só precisa sair da pilha.
      Navigator.of(context).popUntil((rota) => rota.isFirst);
      return;
    }

    // RF-A04.4 — erro cuja origem é outro passo devolve o usuário
    // ao passo certo, em vez de falhar genericamente aqui.
    final falha = controlador.falha;
    if (falha?.passo != null && falha!.passo != PassoCadastro.credenciais) {
      Navigator.of(context).pop();
    }
  }

  bool lembrarSenha = false;
  bool esconderSenha = true;
  bool esconderConfirmacao = true;

  @override
  Widget build(BuildContext context) {
    final rascunho = context.watch<RascunhoCadastro>();
    final cadastro = context.watch<ControladorCadastro>();
    final erros = _mostrarErros
        ? rascunho.validar(PassoCadastro.credenciais)
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
                  CampoCadastro(
                    rotulo: 'Usuário',
                    valorInicial: rascunho.login,
                    aoMudar: (v) => rascunho.login = v,
                    erro: erros['Usuário'],
                  ),

                  const SizedBox(height: 18),

                  // SENHA
                  CampoCadastro(
                    rotulo: 'Senha',
                    valorInicial: rascunho.senha,
                    aoMudar: (v) => rascunho.senha = v,
                    senha: true,
                    erro: erros['Senha'],
                  ),

                  const SizedBox(height: 18),

                  // CONFIRMAR SENHA
                  CampoCadastro(
                    rotulo: 'Confirme a senha',
                    valorInicial: rascunho.confirmacaoDeSenha,
                    aoMudar: (v) => rascunho.confirmacaoDeSenha = v,
                    senha: true,
                    erro: erros['Confirme a senha'],
                  ),

                  const SizedBox(height: 18),

                  // LEMBRAR SENHA
                  Row(
                    children: [
                      Checkbox(
                        value: lembrarSenha,
                        activeColor: const Color.fromRGBO(254, 98, 29, 1),
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

                  // Erro do servidor, exibido como veio (RF-A04.3).
                  if (cadastro.falha != null)
                    AvisoDeErro(cadastro.falha!.mensagem),

                  const SizedBox(height: 10),

                  // BOTÃO FINALIZAR
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: cadastro.enviando
                          ? null
                          : () => _concluir(context, rascunho),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(254, 98, 29, 1),
                        disabledBackgroundColor: const Color.fromRGBO(
                          254,
                          98,
                          29,
                          0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: cadastro.enviando
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
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
