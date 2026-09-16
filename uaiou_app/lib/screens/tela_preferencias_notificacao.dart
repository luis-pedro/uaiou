import 'package:flutter/material.dart';

import 'package:uaiou/core/tema/cores.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/notificacoes/controlador_preferencias_notificacao.dart';
import 'package:uaiou/core/notificacoes/modelo_notificacao.dart';
import 'package:uaiou/screens/widgets/visao_carregavel.dart';

/// RF-A11.8 — `GET`/`PUT /me/notification-preferences`.
class TelaPreferenciasNotificacao extends StatefulWidget {
  const TelaPreferenciasNotificacao({super.key});

  @override
  State<TelaPreferenciasNotificacao> createState() =>
      _TelaPreferenciasNotificacaoState();
}

class _TelaPreferenciasNotificacaoState
    extends State<TelaPreferenciasNotificacao> {
  static const Color corPrincipal = CoresUaiou.principal;

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
      appBar: AppBar(
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
        title: const Text('Preferências de notificação'),
      ),
      body: VisaoCarregavel<PreferenciasNotificacao>(
        estado: controlador.estado,
        aoTentarNovamente: controlador.carregar,
        construir: (preferencias) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            const Text(
              'Canais',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildCanal(
              context,
              canal: 'push',
              rotulo: 'Push',
              // Fora de escopo desta v1 web (RF-A11.9): não há push
              // real por trás, mas o canal ainda existe no servidor e
              // pode valer para outra plataforma da mesma conta.
              descricao:
                  'Sem push real no navegador nesta versão — a inbox '
                  'continua funcionando independente deste toggle.',
              ligado: preferencias.channels['push'] ?? false,
              controlador: controlador,
            ),
            _buildCanal(
              context,
              canal: 'email',
              rotulo: 'E-mail',
              descricao: 'Fora do escopo desta task — cadastro no servidor.',
              ligado: preferencias.channels['email'] ?? false,
              controlador: controlador,
            ),
            _buildCanal(
              context,
              canal: 'sms',
              rotulo: 'SMS',
              descricao: 'Fora do escopo desta task — cadastro no servidor.',
              ligado: preferencias.channels['sms'] ?? false,
              controlador: controlador,
            ),
            if (preferencias.mandatory.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text(
                'Sempre notificados',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'O servidor não permite silenciar estes eventos — não '
                'há como desligá-los.',
                style: TextStyle(fontSize: 13, color: context.cores.textoSuave),
              ),
              const SizedBox(height: 12),
              ...preferencias.mandatory.map(
                (tipo) => ListTile(
                  leading: Icon(
                    Icons.lock_outline,
                    color: context.cores.textoSuave,
                  ),
                  title: Text(tipo),
                  dense: true,
                ),
              ),
            ],
            if (controlador.erro != null) ...[
              const SizedBox(height: 16),
              Text(
                controlador.erro!,
                style: TextStyle(color: context.cores.perigo),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCanal(
    BuildContext context, {
    required String canal,
    required String rotulo,
    required String descricao,
    required bool ligado,
    required ControladorPreferenciasNotificacao controlador,
  }) {
    return SwitchListTile(
      activeThumbColor: corPrincipal,
      value: ligado,
      onChanged: controlador.salvando
          ? null
          : (valor) => controlador.alternarCanal(canal, valor),
      title: Text(rotulo),
      subtitle: Text(descricao, style: const TextStyle(fontSize: 12)),
    );
  }
}
