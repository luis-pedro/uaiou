import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/feira/controlador_feira.dart';
import 'package:uaiou/core/tema/cores.dart';

/// ===============================================================
/// ENTRADA DO JOGADOR — modo feira (`docs/feira/01-fluxos.md`)
/// ===============================================================
///
/// Um passo só: nome e nome de usuário. Não existe tela de login
/// separada porque não existe senha a provar, e não existe escolha de
/// papel porque nesta versão só existe entregador — estabelecimento
/// não se cadastra nem entra.
class TelaFeiraEntrar extends StatefulWidget {
  const TelaFeiraEntrar({super.key});

  @override
  State<TelaFeiraEntrar> createState() => _TelaFeiraEntrarState();
}

class _TelaFeiraEntrarState extends State<TelaFeiraEntrar> {
  final _nome = TextEditingController();
  final _username = TextEditingController();
  final _formulario = GlobalKey<FormState>();

  @override
  void dispose() {
    _nome.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!(_formulario.currentState?.validate() ?? false)) return;
    // Sem `Navigator` aqui: adotar a sessão muda a fase, e a raiz do
    // app troca de tela sozinha.
    await context.read<ControladorFeira>().entrar(
      nome: _nome.text.trim(),
      username: _username.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feira = context.watch<ControladorFeira>();

    return Scaffold(
      body: Container(
        color: const Color.fromRGBO(254, 98, 29, 1),
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/imagens/UaiOu_logo_branca.png',
                        height: 130,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Ache o ponto, pegue o prêmio.',
                        style: TextStyle(color: Colors.white, fontSize: 22),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  32,
                  32,
                  32,
                  32 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                decoration: BoxDecoration(
                  color: context.cores.superficie,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Form(
                      key: _formulario,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: _nome,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            maxLength: 120,
                            decoration: const InputDecoration(
                              labelText: 'Seu nome',
                              counterText: '',
                            ),
                            validator: (valor) => (valor ?? '').trim().isEmpty
                                ? 'Diga como te chamar.'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _username,
                            maxLength: 20,
                            // O servidor normaliza para minúsculas sem
                            // acento; filtrar aqui evita a surpresa de
                            // digitar algo e receber outro nome.
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z0-9_]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Nome de usuário',
                              helperText: 'De 3 a 20 letras, números ou _',
                              counterText: '',
                            ),
                            validator: (valor) =>
                                (valor ?? '').trim().length < 3
                                ? 'Pelo menos 3 caracteres.'
                                : null,
                            onFieldSubmitted: (_) => _entrar(),
                          ),
                          if (feira.erro != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              feira.erro!,
                              style: TextStyle(color: context.cores.perigo),
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: feira.carregando ? null : _entrar,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromRGBO(
                                  254,
                                  98,
                                  29,
                                  1,
                                ),
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                feira.carregando ? 'Entrando…' : 'Entrar',
                                style: const TextStyle(fontSize: 17),
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
