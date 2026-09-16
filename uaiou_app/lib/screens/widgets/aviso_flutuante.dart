import 'package:flutter/material.dart';

import 'package:uaiou/core/tema/cores.dart';

/// Tom do toast — define ícone e cor da faixa lateral.
enum TomAviso { info, sucesso, erro, urgente }

/// ===============================================================
/// TOAST NA PARTE DE BAIXO
/// ===============================================================
///
/// Padrão único de aviso do app: cartão flutuante no rodapé, acima da
/// barra de navegação do celular (respeita `viewPadding`), que entra
/// deslizando, some sozinho e sai no toque ou arrastando para o lado.
///
/// Um toast por vez: um aviso novo substitui o anterior em vez de
/// empilhar cartões por cima dos botões da tela.
void mostrarAviso(
  BuildContext context,
  String mensagem, {
  bool erro = false,
  TomAviso? tom,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || mensagem.trim().isEmpty) return;
  mostrarToast(
    overlay,
    mensagem: mensagem,
    tom: tom ?? (erro ? TomAviso.erro : TomAviso.info),
  );
}

OverlayEntry? _atual;

/// Versão sem `BuildContext`, para quem vive acima do `Navigator`
/// (o receptor de push usa o overlay do navegador raiz).
void mostrarToast(
  OverlayState overlay, {
  String? titulo,
  required String mensagem,
  TomAviso tom = TomAviso.info,
  VoidCallback? aoTocar,
  Duration? duracao,
}) {
  _atual?.remove();
  _atual = null;

  late OverlayEntry entrada;
  var removida = false;
  void remover() {
    if (removida) return;
    removida = true;
    entrada.remove();
    if (identical(_atual, entrada)) _atual = null;
  }

  entrada = OverlayEntry(
    builder: (_) => _Toast(
      titulo: titulo,
      mensagem: mensagem,
      tom: tom,
      aoFechar: remover,
      aoTocar: aoTocar,
      // Urgente fica mais tempo: é justamente o aviso que não pode passar
      // despercebido.
      duracao:
          duracao ??
          (tom == TomAviso.urgente
              ? const Duration(seconds: 10)
              : const Duration(seconds: 4)),
    ),
  );

  _atual = entrada;
  overlay.insert(entrada);
}

class _Toast extends StatefulWidget {
  final String? titulo;
  final String mensagem;
  final TomAviso tom;
  final VoidCallback aoFechar;
  final VoidCallback? aoTocar;
  final Duration duracao;

  const _Toast({
    required this.titulo,
    required this.mensagem,
    required this.tom,
    required this.aoFechar,
    required this.aoTocar,
    required this.duracao,
  });

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _animacao = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 160),
  );

  @override
  void initState() {
    super.initState();
    _animacao.forward();
    Future.delayed(widget.duracao, _fechar);
  }

  Future<void> _fechar() async {
    if (!mounted) return;
    await _animacao.reverse();
    widget.aoFechar();
  }

  @override
  void dispose() {
    _animacao.dispose();
    super.dispose();
  }

  (IconData, Color) _estilo(CoresApp cores) => switch (widget.tom) {
    TomAviso.info => (Icons.info_outline_rounded, CoresUaiou.principal),
    TomAviso.sucesso => (Icons.check_circle_outline_rounded, cores.positivo),
    TomAviso.erro => (Icons.error_outline_rounded, CoresUaiou.perigo),
    TomAviso.urgente => (
      Icons.notification_important_rounded,
      CoresUaiou.perigo,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final (icone, destaque) = _estilo(cores);
    final inferior = MediaQuery.viewPaddingOf(context).bottom;
    final curva = CurvedAnimation(
      parent: _animacao,
      curve: Curves.easeOutCubic,
    );

    return Positioned(
      left: 12,
      right: 12,
      // Acima da barra de gestos/botões do sistema e com folga para não
      // encostar na barra inferior das telas.
      bottom: inferior + 16,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: FadeTransition(
              opacity: curva,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.4),
                  end: Offset.zero,
                ).animate(curva),
                child: Dismissible(
                  key: UniqueKey(),
                  direction: DismissDirection.horizontal,
                  onDismissed: (_) => widget.aoFechar(),
                  child: Material(
                    color: cores.superficie,
                    elevation: 6,
                    shadowColor: cores.sombra,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        widget.aoTocar?.call();
                        _fechar();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: destaque, width: 5),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icone, color: destaque, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.titulo != null) ...[
                                    Text(
                                      widget.titulo!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: cores.texto,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  Text(
                                    widget.mensagem,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: widget.titulo == null
                                          ? cores.texto
                                          : cores.textoSuave,
                                      fontSize: 14,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: cores.textoSuave,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
