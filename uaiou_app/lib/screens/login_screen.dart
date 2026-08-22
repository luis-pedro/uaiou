import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/rede/erros_api.dart';
import 'package:uaiou/core/sessao/controlador_sessao.dart';
import 'package:uaiou/core/sessao/identidade.dart';

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
  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  final _login = TextEditingController();
  final _senha = TextEditingController();

  /// RF-A02.3 — o contrato exige `role` no login. O toggle é o
  /// controle que 🖼 `tela_de_login_motoboy.png` já previa.
  Papel _papel = Papel.estabelecimento;

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
      await context.read<ControladorSessao>().entrarComSenha(
        login: login,
        senha: senha,
        papel: _papel,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se existir uma conta com esse e-mail, enviamos as instruções.',
          ),
        ),
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
    final larguraTela = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  Center(
                    child: Image.asset(
                      'assets/imagens/UaiOu_logo_horizontal.png',
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  ),

                  _buildSeletorDePapel(),

                  const SizedBox(height: 24),

                  const Text(
                    'Entre',
                    style: TextStyle(
                      fontSize: 32,
                      color: corPrincipal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 30),

                  TextField(
                    controller: _login,
                    enabled: !_enviando,
                    autofillHints: const [AutofillHints.username],
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Email ou usuário',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: _senha,
                    enabled: !_enviando,
                    obscureText: esconderSenha,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _enviando ? null : _entrar(),
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
                          setState(() => esconderSenha = !esconderSenha);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Checkbox(
                        value: lembrarSenha,
                        activeColor: corPrincipal,
                        onChanged: (valor) {
                          setState(() => lembrarSenha = valor!);
                        },
                      ),
                      const Text(
                        'Lembrar-se de mim',
                        style: TextStyle(fontSize: 12),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _enviando ? null : _recuperarSenha,
                        child: const Text(
                          'Esqueceu sua senha?',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),

                  if (_erro != null) _buildErro(_erro!),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _enviando ? null : _entrar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: corPrincipal,
                        disabledBackgroundColor: corPrincipal.withValues(
                          alpha: .5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                          : const Text(
                              'Entrar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  const Center(
                    child: Text(
                      'Ou',
                      style: TextStyle(color: corPrincipal, fontSize: 16),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _enviando ? null : _entrarComGoogle,
                      icon: Image.asset(
                        'assets/imagens/google_icon_novo.png',
                        height: 22,
                      ),
                      label: const Text(
                        'Entrar com Google',
                        style: TextStyle(color: Colors.black87),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  Center(
                    child: Wrap(
                      children: [
                        const Text(
                          'Ainda não possui conta? ',
                          style: TextStyle(fontSize: 12),
                        ),
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, '/cadastro'),
                          child: const Text(
                            'Cadastre-se aqui',
                            style: TextStyle(
                              fontSize: 12,
                              color: corPrincipal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: larguraTela > 800 ? 20 : 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 🖼 Toggle **Estabelecimento | Entregador** do protótipo.
  Widget _buildSeletorDePapel() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: corPrincipal, width: 2),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          _buildOpcaoDePapel(Papel.estabelecimento, 'Estabelecimento'),
          _buildOpcaoDePapel(Papel.entregador, 'Entregador'),
        ],
      ),
    );
  }

  Widget _buildOpcaoDePapel(Papel papel, String rotulo) {
    final selecionado = _papel == papel;

    return Expanded(
      child: GestureDetector(
        onTap: _enviando
            ? null
            : () => setState(() {
                _papel = papel;
                _erro = null;
              }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selecionado ? corPrincipal : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            rotulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selecionado ? Colors.white : corPrincipal,
              fontWeight: FontWeight.bold,
              fontSize: 14,
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
        color: Colors.red.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: .4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensagem,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
