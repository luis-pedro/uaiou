import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/notificacoes/controlador_preferencias_notificacao.dart';
import 'package:uaiou/core/notificacoes/modelo_notificacao.dart';
import 'package:uaiou/core/tema/cores.dart';
import 'package:uaiou/screens/widgets/ui.dart';
import 'package:uaiou/screens/widgets/visao_carregavel.dart';

/// RF-A11.8 — `GET`/`PUT /me/notification-preferences`.
///
/// Só os canais que o usuário controla; os avisos que o servidor não deixa
/// silenciar não aparecem aqui.
class TelaPreferenciasNotificacao extends StatefulWidget {
  const TelaPreferenciasNotificacao({super.key});

  @override
  State<TelaPreferenciasNotificacao> createState() =>
      _TelaPreferenciasNotificacaoState();
}

class _TelaPreferenciasNotificacaoState
    extends State<TelaPreferenciasNotificacao> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ControladorPreferenciasNotificacao>().carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controlador = context.watch<ControladorPreferenciasNotificacao>();

    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: VisaoCarregavel<PreferenciasNotificacao>(
        estado: controlador.estado,
        aoTentarNovamente: controlador.carregar,
        construir: (preferencias) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            Text(
              'Escolha por onde quer receber os avisos do UaiOu. Tudo continua '
              'aparecendo no sino do app.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: context.cores.textoSuave,
              ),
            ),
            const SizedBox(height: 16),
            const TituloSecao('Canais'),
            Cartao(
              preenchimento: EdgeInsets.zero,
              filho: Column(
                children: [
                  _buildCanal(
                    canal: 'push',
                    icone: Icons.phone_iphone_rounded,
                    rotulo: 'No celular',
                    descricao: 'Novos pedidos e andamento das entregas',
                    preferencias: preferencias,
                    controlador: controlador,
                  ),
                  _divisor(),
                  _buildCanal(
                    canal: 'email',
                    icone: Icons.mail_outline_rounded,
                    rotulo: 'E-mail',
                    descricao: 'Resumos e avisos sobre a sua conta',
                    preferencias: preferencias,
                    controlador: controlador,
                  ),
                  _divisor(),
                  _buildCanal(
                    canal: 'sms',
                    icone: Icons.sms_outlined,
                    rotulo: 'SMS',
                    descricao: 'Só o essencial, por mensagem de texto',
                    preferencias: preferencias,
                    controlador: controlador,
                  ),
                ],
              ),
            ),
            if (controlador.erro != null) ...[
              const SizedBox(height: 12),
              Text(
                controlador.erro!,
                style: TextStyle(fontSize: 13, color: context.cores.perigo),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _divisor() =>
      Divider(height: 1, indent: 56, color: context.cores.borda);

  Widget _buildCanal({
    required String canal,
    required IconData icone,
    required String rotulo,
    required String descricao,
    required PreferenciasNotificacao preferencias,
    required ControladorPreferenciasNotificacao controlador,
  }) {
    final ligado = preferencias.channels[canal] ?? false;
    final cores = context.cores;
    return InkWell(
      onTap: controlador.salvando
          ? null
          : () => controlador.alternarCanal(canal, !ligado),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Row(
          children: [
            Icon(icone, color: CoresUaiou.principal, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rotulo,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cores.texto,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    descricao,
                    style: TextStyle(fontSize: 13, color: cores.textoSuave),
                  ),
                ],
              ),
            ),
            Switch(
              value: ligado,
              activeThumbColor: Colors.white,
              activeTrackColor: CoresUaiou.principal,
              onChanged: controlador.salvando
                  ? null
                  : (valor) => controlador.alternarCanal(canal, valor),
            ),
          ],
        ),
      ),
    );
  }
}
