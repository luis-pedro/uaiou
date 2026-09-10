import 'package:flutter/material.dart';

/// Campo do assistente de cadastro, ligado ao rascunho.
///
/// Os `TextField` originais eram anônimos: ninguém lia o que era
/// digitado e sair da tela perdia tudo. Aqui o valor sobe para o
/// [RascunhoCadastro] a cada tecla — é o que faz RF-A04.1 funcionar,
/// inclusive ao voltar um passo.
class CampoCadastro extends StatefulWidget {
  final String rotulo;
  final String valorInicial;
  final ValueChanged<String> aoMudar;
  final TextInputType? teclado;
  final bool senha;

  /// Erro vindo da validação local ou do servidor (RF-A04.4).
  final String? erro;

  const CampoCadastro({
    super.key,
    required this.rotulo,
    required this.valorInicial,
    required this.aoMudar,
    this.teclado,
    this.senha = false,
    this.erro,
  });

  @override
  State<CampoCadastro> createState() => _CampoCadastroState();
}

class _CampoCadastroState extends State<CampoCadastro> {
  late final TextEditingController _controle = TextEditingController(
    text: widget.valorInicial,
  );
  late bool _escondido = widget.senha;

  /// O controlador nasce de [valorInicial] e, no uso normal, ninguém
  /// mais escreve nele. Mas o preenchimento automático por CEP
  /// (`MapaEndereco` -> ViaCEP) muda o valor de fora, depois do campo
  /// já montado — sem isto o texto novo simplesmente não apareceria.
  /// A comparação com o texto atual evita mexer no cursor de quem
  /// está digitando.
  @override
  void didUpdateWidget(CampoCadastro anterior) {
    super.didUpdateWidget(anterior);
    if (widget.valorInicial != anterior.valorInicial &&
        widget.valorInicial != _controle.text) {
      _controle.text = widget.valorInicial;
    }
  }

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controle,
      keyboardType: widget.teclado,
      obscureText: _escondido,
      onChanged: widget.aoMudar,
      decoration: InputDecoration(
        hintText: widget.rotulo,
        errorText: widget.erro,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        suffixIcon: widget.senha
            ? IconButton(
                icon: Icon(
                  _escondido ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _escondido = !_escondido),
              )
            : null,
      ),
    );
  }
}

/// Aviso de erro do passo, acima do botão de avanço.
class AvisoDeErro extends StatelessWidget {
  final String mensagem;

  const AvisoDeErro(this.mensagem, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
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
