
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Imagem escolhida, pronta para o upload.
class ImagemEscolhida {
  final Uint8List bytes;
  final String tipoDeConteudo;
  final String nome;

  const ImagemEscolhida({
    required this.bytes,
    required this.tipoDeConteudo,
    required this.nome,
  });

  double get megabytes => bytes.length / (1024 * 1024);
}

enum OrigemDaImagem { camera, galeria }

/// ===============================================================
/// CAPTURA DE IMAGEM — RF-A04.6 e RF-A04.9
/// ===============================================================
///
/// A permissão é pedida **no momento do uso** — quando o usuário toca
/// em enviar documento —, não na abertura do app. Pedir tudo de
/// entrada é o padrão que mais gera negação permanente.
///
/// Quem pede a permissão de fato é o `image_picker`, através do
/// seletor do próprio sistema. Não há `permission_handler` aqui: para
/// câmera e galeria o pedido do sistema já é o pedido certo, e uma
/// segunda camada só criaria dois diálogos para a mesma coisa.
class SeletorDeImagem {
  final ImagePicker _seletor;

  SeletorDeImagem({ImagePicker? seletor}) : _seletor = seletor ?? ImagePicker();

  /// Compressão aplicada na captura — RF-A04.6.
  ///
  /// Foto de documento em aparelho moderno passa de vários megabytes,
  /// o teto do servidor é 5 MB, e o entregador costuma estar em rede
  /// móvel. Reduzir aqui é mais barato que falhar depois de subir.
  static const int _larguraMaxima = 1600;
  static const int _qualidade = 85;

  /// Devolve `null` se o usuário desistiu ou negou a permissão.
  Future<ImagemEscolhida?> escolher(OrigemDaImagem origem) async {
    final arquivo = await _seletor.pickImage(
      source: origem == OrigemDaImagem.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: _larguraMaxima.toDouble(),
      imageQuality: _qualidade,
    );

    if (arquivo == null) return null;

    final bytes = await arquivo.readAsBytes();

    return ImagemEscolhida(
      bytes: bytes,
      tipoDeConteudo: _tipoDe(arquivo, bytes),
      nome: arquivo.name,
    );
  }

  /// A câmera só está disponível em aparelho — no navegador, a origem
  /// é sempre o seletor de arquivos.
  bool get temCamera => !kIsWeb;

  /// O servidor confere o tipo **real** do arquivo na confirmação, e
  /// recusa o que não for JPEG ou PNG. Por isso o tipo é deduzido dos
  /// bytes quando o `mimeType` não vem — declarar errado só adiaria a
  /// recusa para a fase 3.
  String _tipoDe(XFile arquivo, Uint8List bytes) {
    final declarado = arquivo.mimeType?.toLowerCase();
    if (declarado == 'image/jpeg' || declarado == 'image/png') {
      return declarado!;
    }

    // Assinatura PNG: 89 50 4E 47
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }

    // JPEG começa com FF D8 FF
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    final nome = arquivo.name.toLowerCase();
    if (nome.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }
}
