import 'package:flutter/material.dart';

import 'package:uaiou/core/tema/cores.dart';
import 'package:uaiou/screens/widgets/botao_google.dart';
import 'package:uaiou/screens/widgets/aviso_flutuante.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/rede/erros_api.dart';
import 'package:uaiou/core/sessao/controlador_sessao.dart';

/// Login real (A-02).
///
/// Antes desta task, "Entrar" navegava para a tela do estabelecimento
/// e "Entrar com Google" para a do entregador, sem ler campo nenhum.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color corPrincipal = CoresUaiou.principal;

  final _login = TextEditingController();
  final _senha = TextEditingController();

  bool lembrarSenha = false;
  bool esconderSenha = true;
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _login.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    // Mesma guarda de reentrância do cadastro: `setState` só
    // reconstrói no frame seguinte, então um duplo toque pode disparar
    // dois `POST /auth/sessions` antes do botão desabilitar.
    if (_enviando) return;

    final login = _login.text.trim();
    final senha = _senha.text;

    if (login.isEmpty || senha.isEmpty) {
      setState(() => _erro = 'Informe usuário e senha.');
      return;
    }

    setState(() {
      _enviando = true;
      _erro = null;
    });

    try {
      await context.read<ControladorSessao>().entrarSemPapel(
        login: login,
        senha: senha,
      );

      // O destino continua sendo decidido pela raiz, a partir do papel
      // que o servidor devolveu. O que esta tela precisa fazer é sair
      // da pilha: ela foi empilhada ACIMA da raiz, e trocar o conteúdo
      // da raiz não a desmonta — sem isto, o login bem-sucedido deixa
      // o usuário olhando para o próprio formulário.
      if (mounted) {
        Navigator.of(context).popUntil((rota) => rota.isFirst);
      }
    } on ErroApi catch (erro) {
      if (mounted) setState(() => _erro = erro.mensagemParaUsuario);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _recuperarSenha() async {
    final email = _login.text.trim();
    if (email.isEmpty) {
      setState(() => _erro = 'Informe seu e-mail para recuperar a senha.');
      return;
    }

    try {
      await context.read<ControladorSessao>().pedirRecuperacaoDeSenha(email);
      if (!mounted) return;
      mostrarAviso(
        context,
        'Se existir uma conta com esse e-mail, enviamos as instruções.',
      );
    } on ErroApi catch (erro) {
      if (mounted) setState(() => _erro = erro.mensagemParaUsuario);
    }
  }

  void _entrarComGoogle() {
    // O caminho até a API existe (ControladorSessao.entrarComGoogle),
    // mas obter o idToken exige o cliente OAuth configurado por
    // plataforma — ver A-13. Até lá, avisa em vez de fingir que
    // entrou: era exatamente esse o defeito anterior.
    setState(() {
      _erro = 'Login com Google ainda não está configurado neste aplicativo.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Bem-vindo de volta',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 28),

                    TextField(
                      controller: _login,
                      enabled: !_enviando,
                      autofillHints: const [AutofillHints.username],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'E-mail ou usuário',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: _senha,
                      enabled: !_enviando,
                      obscureText: esconderSenha,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _enviando ? null : _entrar(),
                      decoration: InputDecoration(
                        hintText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: esconderSenha
                              ? 'Mostrar senha'
                              : 'Esconder senha',
                          icon: Icon(
                            esconderSenha
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() => esconderSenha = !esconderSenha);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Checkbox(
                          value: lembrarSenha,
                          activeColor: corPrincipal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          onChanged: (valor) {
                            setState(() => lembrarSenha = valor!);
                          },
                        ),
                        const Text(
                          'Lembrar de mim',
                          style: TextStyle(fontSize: 13),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _enviando ? null : _recuperarSenha,
                          child: const Text(
                            'Esqueci a senha',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),

                    if (_erro != null) _buildErro(_erro!),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: _enviando ? null : _entrar,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      child: _enviando
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Entrar'),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'ou',
                            style: TextStyle(color: cores.textoSuave),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 24),

                    BotaoGoogle(aoTocar: _enviando ? null : _entrarComGoogle),

                    const SizedBox(height: 28),

                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Ainda não tem conta? ',
                            style: TextStyle(color: cores.textoSuave),
                          ),
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushNamed(context, '/cadastro'),
                            child: const Text(
                              'Cadastre-se',
                              style: TextStyle(
                                color: corPrincipal,
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
        ),
      ),
    );
  }

  Widget _buildErro(String mensagem) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cores.perigo.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.cores.perigo.withValues(alpha: .4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: context.cores.perigo, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensagem,
              style: TextStyle(color: context.cores.perigo, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
