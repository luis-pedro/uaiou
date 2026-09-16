import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/tema/controlador_tema.dart';
import 'package:uaiou/core/tema/cores.dart';

/// Escolha de tema, no mesmo formato do seletor de formas de pagamento.
///
/// "Do sistema" vem primeiro e é o padrão: na maioria dos casos é o que a
/// pessoa já quer, e as outras duas existem para quem discorda do aparelho.
Future<void> escolherTema(BuildContext context) async {
  final controlador = context.read<ControladorTema>();

  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (contexto) => SafeArea(
      child: ListenableBuilder(
        listenable: controlador,
        builder: (contexto, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
              child: Text(
                'Tema',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: contexto.cores.texto,
                ),
              ),
            ),
            Text(
              'A troca vale na hora.',
              style: TextStyle(fontSize: 13, color: contexto.cores.textoSuave),
            ),
            const SizedBox(height: 8),
            _opcao(
              contexto,
              controlador,
              modo: ThemeMode.system,
              icone: Icons.brightness_auto,
              titulo: 'Do sistema',
              detalhe: 'Acompanha o ajuste do aparelho',
            ),
            _opcao(
              contexto,
              controlador,
              modo: ThemeMode.light,
              icone: Icons.light_mode,
              titulo: 'Claro',
              detalhe: null,
            ),
            _opcao(
              contexto,
              controlador,
              modo: ThemeMode.dark,
              icone: Icons.dark_mode,
              titulo: 'Escuro',
              detalhe: null,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}

Widget _opcao(
  BuildContext context,
  ControladorTema controlador, {
  required ThemeMode modo,
  required IconData icone,
  required String titulo,
  required String? detalhe,
}) {
  final selecionado = controlador.modo == modo;

  return ListTile(
    leading: Icon(
      icone,
      color: selecionado ? CoresUaiou.principal : context.cores.textoSuave,
    ),
    title: Text(titulo, style: TextStyle(color: context.cores.texto)),
    subtitle: detalhe == null
        ? null
        : Text(
            detalhe,
            style: TextStyle(fontSize: 12, color: context.cores.textoSuave),
          ),
    trailing: selecionado
        ? const Icon(Icons.check, color: CoresUaiou.principal)
        : null,
    // Sem fechar a folha: trocar e ver o resultado atrás dela é o que deixa
    // claro o que cada opção faz.
    onTap: () => controlador.definir(modo),
  );
}
