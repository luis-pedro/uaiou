import 'package:flutter/material.dart';

import 'package:uaiou/core/tema/cores.dart';

/// ===============================================================
/// DIÁLOGO PADRÃO
/// ===============================================================
///
/// Todo diálogo do app com a mesma cara: ícone em círculo tingido,
/// título, conteúdo e, no rodapé, "cancelar" discreto à esquerda e a
/// ação principal como botão cheio. Ação destrutiva (sair, bloquear)
/// usa o vermelho; o resto, o laranja da marca.
///
/// Antes cada tela montava o próprio `AlertDialog`, com a ação
/// principal às vezes em `TextButton`, às vezes em `ElevatedButton`
/// com cor solta — o usuário não tinha como saber qual botão era o
/// importante.
class DialogoPadrao extends StatelessWidget {
  final String titulo;
  final Widget? conteudo;

  /// Ícone padrão; ignorado quando [cabecalho] é informado.
  final IconData? icone;

  /// Substitui o ícone (ex.: foto do entregador).
  final Widget? cabecalho;

  final String rotuloConfirmar;

  /// `null` desabilita o botão principal (formulário incompleto).
  final VoidCallback? aoConfirmar;

  final String rotuloCancelar;
  final VoidCallback? aoCancelar;
  final bool destrutivo;

  /// Ações secundárias entre cancelar e confirmar (ex.: "Ver pedido").
  final List<Widget> acoesExtras;

  const DialogoPadrao({
    super.key,
    required this.titulo,
    this.conteudo,
    this.icone,
    this.cabecalho,
    required this.rotuloConfirmar,
    required this.aoConfirmar,
    this.rotuloCancelar = 'Cancelar',
    this.aoCancelar,
    this.destrutivo = false,
    this.acoesExtras = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final destaque = destrutivo ? CoresUaiou.perigo : CoresUaiou.principal;

    return AlertDialog(
      icon:
          cabecalho ??
          (icone == null
              ? null
              : Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: destaque.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icone, color: destaque, size: 28),
                )),
      title: Text(titulo, textAlign: TextAlign.center),
      content: conteudo == null
          ? null
          : DefaultTextStyle.merge(
              style: TextStyle(fontSize: 15, height: 1.45, color: cores.texto),
              child: conteudo!,
            ),
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: aoCancelar ?? () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: cores.textoSuave),
          child: Text(rotuloCancelar),
        ),
        ...acoesExtras,
        FilledButton(
          onPressed: aoConfirmar,
          style: FilledButton.styleFrom(
            backgroundColor: destaque,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(rotuloConfirmar),
        ),
      ],
    );
  }
}

/// Confirmação simples sim/não no padrão. Devolve `true` só quando a
/// pessoa tocou na ação principal.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required String rotuloConfirmar,
  String rotuloCancelar = 'Cancelar',
  IconData? icone,
  bool destrutivo = false,
}) async {
  final resposta = await showDialog<bool>(
    context: context,
    builder: (dialogo) => DialogoPadrao(
      titulo: titulo,
      icone: icone,
      conteudo: Text(mensagem),
      rotuloConfirmar: rotuloConfirmar,
      rotuloCancelar: rotuloCancelar,
      destrutivo: destrutivo,
      aoCancelar: () => Navigator.pop(dialogo, false),
      aoConfirmar: () => Navigator.pop(dialogo, true),
    ),
  );
  return resposta ?? false;
}
