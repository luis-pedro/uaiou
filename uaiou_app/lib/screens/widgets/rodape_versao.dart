import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:uaiou/core/tema/cores.dart';

/// Versão do aplicativo no rodapé do perfil.
///
/// Sem isto, a primeira pergunta de qualquer suporte ("qual versão você está
/// usando?") não tem resposta: o entregador não sabe, e a loja também não.
/// O pacote já era dependência — o registro de dispositivo (RF-A13.6) envia a
/// versão ao servidor —, só não aparecia em lugar nenhum para o usuário.
class RodapeVersao extends StatefulWidget {
  const RodapeVersao({super.key});

  @override
  State<RodapeVersao> createState() => _RodapeVersaoState();
}

class _RodapeVersaoState extends State<RodapeVersao> {
  String? _versao;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(
          () => _versao = 'versão ${info.version} (${info.buildNumber})',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final versao = _versao;
    if (versao == null) return const SizedBox(height: 18);

    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4),
      child: Center(
        child: Text(
          versao,
          style: const TextStyle(
            fontSize: 12,
            color: CoresUaiou.textoSecundario,
          ),
        ),
      ),
    );
  }
}
