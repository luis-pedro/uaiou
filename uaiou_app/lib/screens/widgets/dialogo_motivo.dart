import 'package:flutter/material.dart';

import 'package:uaiou/core/tema/cores.dart';
import 'package:uaiou/screens/widgets/dialogo_padrao.dart';

/// Resultado de [escolherMotivo].
typedef MotivoEscolhido<T> = ({T motivo, String? observacao});

/// Diálogo de motivo obrigatório — cancelamento (RF-A15.4) e
/// desistência (RF-A15.15). "Outro" exige observação: o botão de
/// confirmar só habilita com ela preenchida, porque o servidor recusaria.
Future<MotivoEscolhido<T>?> escolherMotivo<T>(
  BuildContext context, {
  required String titulo,
  required List<T> opcoes,
  required String Function(T) rotulo,
  required bool Function(T) exigeObservacao,
  required String textoConfirmar,
  String? aviso,
  IconData icone = Icons.help_outline_rounded,
}) {
  return showDialog<MotivoEscolhido<T>>(
    context: context,
    builder: (_) => _DialogoMotivo<T>(
      titulo: titulo,
      opcoes: opcoes,
      rotulo: rotulo,
      exigeObservacao: exigeObservacao,
      textoConfirmar: textoConfirmar,
      aviso: aviso,
      icone: icone,
    ),
  );
}

class _DialogoMotivo<T> extends StatefulWidget {
  final String titulo;
  final List<T> opcoes;
  final String Function(T) rotulo;
  final bool Function(T) exigeObservacao;
  final String textoConfirmar;
  final String? aviso;
  final IconData icone;

  const _DialogoMotivo({
    required this.titulo,
    required this.opcoes,
    required this.rotulo,
    required this.exigeObservacao,
    required this.textoConfirmar,
    required this.aviso,
    required this.icone,
  });

  @override
  State<_DialogoMotivo<T>> createState() => _DialogoMotivoState<T>();
}

class _DialogoMotivoState<T> extends State<_DialogoMotivo<T>> {
  T? _motivo;
  final TextEditingController _observacao = TextEditingController();

  @override
  void dispose() {
    _observacao.dispose();
    super.dispose();
  }

  bool get _podeConfirmar {
    final motivo = _motivo;
    if (motivo == null) return false;
    return !widget.exigeObservacao(motivo) ||
        _observacao.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final motivo = _motivo;

    // Cancelar e desistir são destrutivos: vermelho no padrão.
    return DialogoPadrao(
      titulo: widget.titulo,
      icone: widget.icone,
      destrutivo: true,
      rotuloCancelar: 'Voltar',
      rotuloConfirmar: widget.textoConfirmar,
      aoConfirmar: _podeConfirmar
          ? () => Navigator.of(context).pop((
              motivo: motivo as T,
              observacao: _observacao.text.trim().isEmpty
                  ? null
                  : _observacao.text.trim(),
            ))
          : null,
      conteudo: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.aviso != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.cores.atencao.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.cores.atencao),
                ),
                child: Text(
                  widget.aviso!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            RadioGroup<T>(
              groupValue: motivo,
              onChanged: (valor) => setState(() => _motivo = valor),
              child: Column(
                children: [
                  for (final opcao in widget.opcoes)
                    RadioListTile<T>(
                      value: opcao,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(widget.rotulo(opcao)),
                    ),
                ],
              ),
            ),
            if (motivo != null && widget.exigeObservacao(motivo))
              TextField(
                controller: _observacao,
                maxLength: 280,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Descreva o motivo',
                  border: OutlineInputBorder(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
