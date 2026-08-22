import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/bloqueios/bloqueio.dart';
import 'package:uaiou/core/bloqueios/estado_bloqueios.dart';
import 'package:uaiou/screens/widgets/visao_carregavel.dart';

/// `GET`/`POST`/`DELETE /me/blocked-couriers` — RF-A05.6.
///
/// Bloquear é decisão comercial do estabelecimento; a elegibilidade
/// em si é decidida pelo servidor (RN-07.2). Esta tela só lista,
/// bloqueia por id e desbloqueia — sem busca de entregador, que
/// pertence a outra tarefa (o app hoje não tem um diretório de
/// entregadores para escolher).
class TelaBloqueios extends StatefulWidget {
  const TelaBloqueios({super.key});

  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  @override
  State<TelaBloqueios> createState() => _TelaBloqueiosState();
}

class _TelaBloqueiosState extends State<TelaBloqueios> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EstadoBloqueios>().carregar();
    });
  }

  Future<void> _abrirBloqueio(BuildContext context) async {
    final idControle = TextEditingController();
    final motivoControle = TextEditingController();

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Bloquear entregador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idControle,
              decoration: const InputDecoration(hintText: 'ID do entregador'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoControle,
              decoration: const InputDecoration(hintText: 'Motivo (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );

    if (confirmou != true || !context.mounted) return;
    if (idControle.text.trim().isEmpty) return;

    await context.read<EstadoBloqueios>().bloquear(
      entregadorId: idControle.text.trim(),
      motivo: motivoControle.text.trim().isEmpty ? null : motivoControle.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoBloqueios>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: TelaBloqueios.corPrincipal,
        foregroundColor: Colors.white,
        title: const Text('Entregadores bloqueados'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: TelaBloqueios.corPrincipal,
        onPressed: () => _abrirBloqueio(context),
        child: const Icon(Icons.person_add_disabled),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: VisaoCarregavel<List<EntregadorBloqueado>>(
            estado: estado.estado,
            aoTentarNovamente: estado.carregar,
            textoVazio: 'Nenhum entregador bloqueado',
            iconeVazio: Icons.block,
            construir: (lista) => ListView.separated(
              itemCount: lista.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (contexto, indice) {
                final bloqueado = lista[indice];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_off),
                    title: Text(bloqueado.nome ?? bloqueado.entregadorId),
                    subtitle: bloqueado.motivo != null ? Text(bloqueado.motivo!) : null,
                    trailing: TextButton(
                      onPressed: () =>
                          context.read<EstadoBloqueios>().desbloquear(bloqueado.entregadorId),
                      child: const Text('Desbloquear'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
