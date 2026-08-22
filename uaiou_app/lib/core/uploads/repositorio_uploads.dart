import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../rede/cliente_api.dart';
import '../rede/erros_api.dart';

/// Propósito do upload (`api/uploads.md`). Vocabulário em MAIÚSCULAS,
/// como o contrato serializa.
enum PropositoUpload {
  documentoIdentidade('IDENTITY_DOCUMENT', 'Documento de identidade'),
  cnh('DRIVER_LICENSE', 'CNH'),
  documentoVeiculo('VEHICLE_DOCUMENT', 'Documento do veículo'),
  documentoCnpj('CNPJ_DOCUMENT', 'Cartão CNPJ'),
  logoEstabelecimento('MERCHANT_LOGO', 'Logo do estabelecimento'),
  comprovanteEntrega('DELIVERY_PROOF', 'Comprovante de entrega'),
  desconhecido('', '—');

  const PropositoUpload(this.noContrato, this.rotulo);

  final String noContrato;
  final String rotulo;

  static PropositoUpload doContrato(Object? bruto) {
    if (bruto is! String) return desconhecido;
    final valor = bruto.trim().toUpperCase();
    for (final p in values) {
      if (p.noContrato.isNotEmpty && p.noContrato == valor) return p;
    }
    return desconhecido;
  }
}

/// ===============================================================
/// UPLOAD EM TRÊS FASES — RF-A04.5
/// ===============================================================
///
/// `api/uploads.md`:
///
/// 1. `POST /uploads` — pede a URL pré-assinada
/// 2. `PUT {uploadUrl}` — envia o arquivo **direto ao armazenamento**
/// 3. `PUT /uploads/{id}` — confirma; o servidor valida o tipo real
///
/// **O arquivo não passa pela API.** É o que permite a API não ter
/// endpoint de multipart e o armazenamento escalar sozinho.
///
/// A fase 2 usa um cliente HTTP **separado**: a URL pré-assinada já
/// carrega a autorização na própria query, e mandar o `Authorization`
/// do UaiOu para o armazenamento é vazar credencial para um terceiro.
class RepositorioUploads {
  final ClienteApi _api;
  final Dio _armazenamento;

  RepositorioUploads(this._api, {Dio? armazenamento})
    : _armazenamento = armazenamento ?? Dio();

  /// Tipos que o servidor aceita (`PurposePolicy`).
  static const Set<String> tiposAceitos = {'image/jpeg', 'image/png'};

  /// Teto do servidor: 5 MB.
  static const int tamanhoMaximoBytes = 5 * 1024 * 1024;

  /// Executa as três fases e devolve o `uploadId` para vincular ao
  /// documento.
  ///
  /// [aoProgredir] recebe 0..1 durante a fase 2 (RF-A04.7).
  /// [cancelamento] permite abortar o envio.
  Future<String> enviar({
    required Uint8List bytes,
    required String tipoDeConteudo,
    required PropositoUpload proposito,
    void Function(double progresso)? aoProgredir,
    CancelToken? cancelamento,
  }) async {
    if (!tiposAceitos.contains(tipoDeConteudo)) {
      throw RequisicaoInvalida(
        codigo: 'CONTENT_TYPE_NOT_ALLOWED',
        mensagem: 'Envie uma foto JPEG ou PNG.',
      );
    }
    if (bytes.length > tamanhoMaximoBytes) {
      throw RequisicaoInvalida(
        codigo: 'FILE_TOO_LARGE',
        mensagem: 'A imagem passa de 5 MB. Tente uma foto menor.',
      );
    }

    // Fase 1
    final criado = await _api.criar(
      '/uploads',
      corpo: {
        'purpose': proposito.noContrato,
        'contentType': tipoDeConteudo,
        'sizeBytes': bytes.length,
      },
    );

    if (criado is! Map) {
      throw const ErroInesperado(
        mensagem: 'Resposta de upload fora do contrato.',
      );
    }

    final id = criado['id'] as String;
    final url = criado['uploadUrl'] as String;

    // Fase 2 — direto ao armazenamento.
    await _enviarArquivo(
      url: url,
      bytes: bytes,
      tipoDeConteudo: tipoDeConteudo,
      aoProgredir: aoProgredir,
      cancelamento: cancelamento,
    );

    // Fase 3 — o servidor confere o tipo REAL do arquivo aqui, não o
    // que o cliente declarou.
    await _api.substituir('/uploads/$id');

    return id;
  }

  Future<void> _enviarArquivo({
    required String url,
    required Uint8List bytes,
    required String tipoDeConteudo,
    void Function(double progresso)? aoProgredir,
    CancelToken? cancelamento,
  }) async {
    try {
      final resposta = await _armazenamento.putUri<dynamic>(
        Uri.parse(url),
        data: Stream.fromIterable([bytes]),
        cancelToken: cancelamento,
        options: Options(
          headers: {
            Headers.contentTypeHeader: tipoDeConteudo,
            Headers.contentLengthHeader: bytes.length,
          },
          validateStatus: (_) => true,
        ),
        onSendProgress: (enviados, total) {
          if (total > 0) aoProgredir?.call(enviados / total);
        },
      );

      final status = resposta.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw ErroInesperado(
          codigo: 'STORAGE_REJECTED',
          mensagem: 'O envio da imagem falhou. Tente novamente.',
          status: status,
        );
      }
    } on DioException catch (falha) {
      if (falha.type == DioExceptionType.cancel) {
        throw const FalhaDeRede(
          codigo: 'CANCELLED',
          mensagem: 'Envio cancelado.',
        );
      }
      throw const FalhaDeRede(
        mensagem: 'Não foi possível enviar a imagem. Verifique a internet.',
      );
    }
  }
}
