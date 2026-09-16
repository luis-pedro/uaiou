import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/perfil/controlador_perfil.dart';
import 'package:uaiou/core/uploads/repositorio_uploads.dart';
import 'package:uaiou/core/uploads/seletor_de_imagem.dart';
import 'package:uaiou/screens/widgets/aviso_flutuante.dart';

/// Foto de perfil vinda do servidor, com ícone de reserva.
///
/// A URL tem validade curta: se venceu ou falhou, o ícone aparece no
/// lugar em vez de um quadro quebrado.
class AvatarRede extends StatelessWidget {
  final String? url;
  final IconData icone;
  final double raio;
  final Color corFundo;

  const AvatarRede({
    super.key,
    required this.url,
    required this.icone,
    this.raio = 24,
    this.corFundo = const Color.fromRGBO(217, 217, 217, 1),
  });

  @override
  Widget build(BuildContext context) {
    final temFoto = url != null && url!.isNotEmpty;
    // Leitor de tela anuncia "foto de perfil" em vez de ler o ícone de reserva
    // como se fosse conteúdo.
    return Semantics(
      image: true,
      label: temFoto ? 'Foto de perfil' : 'Sem foto de perfil',
      child: CircleAvatar(
        radius: raio,
        backgroundColor: corFundo,
        foregroundImage: temFoto ? NetworkImage(url!) : null,
        onForegroundImageError: temFoto ? (_, _) {} : null,
        child: Icon(icone, color: Colors.white, size: raio * .8),
      ),
    );
  }
}

/// Fluxo de troca de foto das telas de perfil: escolhe a origem, envia
/// e vincula. O [proposito] decide se é foto do entregador ou logo.
Future<void> trocarFotoDePerfil(
  BuildContext context,
  PropositoUpload proposito,
) async {
  final origem = await showModalBottomSheet<OrigemDaImagem>(
    context: context,
    builder: (contexto) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Tirar foto'),
            onTap: () => Navigator.pop(contexto, OrigemDaImagem.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Escolher da galeria'),
            onTap: () => Navigator.pop(contexto, OrigemDaImagem.galeria),
          ),
        ],
      ),
    ),
  );
  if (origem == null || !context.mounted) return;

  final imagem = await context.read<SeletorDeImagem>().escolher(origem);
  if (imagem == null || !context.mounted) return;

  final controlador = context.read<ControladorPerfil>();
  final ok = await controlador.trocarFoto(imagem, proposito);
  if (!context.mounted) return;
  mostrarAviso(
    context,
    ok
        ? 'Foto atualizada.'
        : (controlador.ultimoErro ?? 'Não foi possível trocar a foto.'),
    erro: !ok,
  );
}

/// Avatar grande das telas de perfil, tocável para trocar a foto.
class AvatarPerfilEditavel extends StatelessWidget {
  final IconData icone;
  final PropositoUpload proposito;

  const AvatarPerfilEditavel({
    super.key,
    required this.icone,
    required this.proposito,
  });

  @override
  Widget build(BuildContext context) {
    final controlador = context.watch<ControladorPerfil>();
    final url = controlador.estado.valorOuNulo?.detalhes?.fotoUrl;

    return GestureDetector(
      onTap: controlador.enviandoFoto
          ? null
          : () => trocarFotoDePerfil(context, proposito),
      child: Stack(
        children: [
          AvatarRede(url: url, icone: icone, raio: 40),
          Positioned(
            right: 0,
            bottom: 0,
            child: CircleAvatar(
              radius: 13,
              backgroundColor: Colors.white,
              child: controlador.enviandoFoto
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.camera_alt,
                      size: 15,
                      color: Color.fromRGBO(254, 98, 29, 1),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
