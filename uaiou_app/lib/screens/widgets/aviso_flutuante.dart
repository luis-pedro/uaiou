import 'package:flutter/material.dart';

/// ===============================================================
/// AVISO NO CANTO SUPERIOR ESQUERDO
/// ===============================================================
///
/// Substitui o `SnackBar` nas telas do entregador. O `SnackBar` do
/// Material nasce **colado no rodapé**, que é exatamente onde vivem a
/// barra de navegação e os botões de ação da entrega: o aviso cobria o
/// que o entregador ia tocar, e sumia por baixo do que ele tocava.
///
/// Aqui o aviso entra pelo `Overlay`, sobrepondo qualquer tela, no
/// alto à esquerda. Some sozinho, e sai também no toque — quem já leu
/// não deveria esperar.
void mostrarAviso(BuildContext context, String mensagem, {bool erro = false}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null || mensagem.trim().isEmpty) return;

  late OverlayEntry entrada;
  var removida = false;
  void remover() {
    if (removida) return;
    removida = true;
    entrada.remove();
  }

  entrada = OverlayEntry(
    builder: (contexto) => Positioned(
      top: MediaQuery.paddingOf(contexto).top + 12,
      left: 12,
      // Não ocupa a largura toda: os controles do mapa moram no alto à
      // direita, e um aviso por cima deles tiraria o zoom da mão do
      // entregador bem na hora em que ele quer conferir o caminho.
      right: 76,
      child: _CartaoDeAviso(mensagem: mensagem, erro: erro, aoFechar: remover),
    ),
  );

  overlay.insert(entrada);
  Future.delayed(const Duration(seconds: 5), remover);
}

class _CartaoDeAviso extends StatelessWidget {
  final String mensagem;
  final bool erro;
  final VoidCallback aoFechar;

  const _CartaoDeAviso({
    required this.mensagem,
    required this.erro,
    required this.aoFechar,
  });

  @override
  Widget build(BuildContext context) {
    final cor = erro ? Colors.red.shade700 : Colors.black87;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: aoFechar,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                erro ? Icons.error_outline : Icons.info_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  mensagem,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
