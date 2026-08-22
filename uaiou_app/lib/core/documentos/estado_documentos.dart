
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../estado/carregavel.dart';
import '../rede/cliente_api.dart';
import '../rede/erros_api.dart';
import '../uploads/repositorio_uploads.dart';
import 'documento.dart';

/// `GET`/`POST /me/documents` — `api/usuarios.md` (T-06).
class RepositorioDocumentos {
  final ClienteApi _api;

  const RepositorioDocumentos(this._api);

  Future<SituacaoDocumental> situacao() async {
    final resposta = await _api.obter('/me/documents');
    if (resposta is! Map) {
      throw const ErroInesperado(
        mensagem: 'Resposta de documentos fora do contrato.',
      );
    }
    return SituacaoDocumental.doJson(Map<String, dynamic>.from(resposta));
  }

  /// Vincula um upload já confirmado a um tipo de documento.
  ///
  /// RNF-A04.2 — reenviar não cria duplicata na fila: o servidor marca
  /// a versão anterior como `superseded` (RF-06.4/RF-06.5).
  Future<void> enviar({
    required PropositoUpload tipo,
    required String uploadId,
  }) async {
    await _api.criar(
      '/me/documents',
      corpo: {'type': tipo.noContrato, 'uploadId': uploadId},
    );
  }
}

/// Envio em andamento, para a tela mostrar progresso e permitir
/// cancelar (RF-A04.7).
class EnvioEmCurso {
  final PropositoUpload tipo;
  final CancelToken cancelamento;
  final double progresso;

  const EnvioEmCurso({
    required this.tipo,
    required this.cancelamento,
    this.progresso = 0,
  });

  EnvioEmCurso com({double? progresso}) => EnvioEmCurso(
    tipo: tipo,
    cancelamento: cancelamento,
    progresso: progresso ?? this.progresso,
  );
}

/// ===============================================================
/// DOCUMENTOS DE CADASTRO
/// ===============================================================
///
/// Alimenta a tela de cadastro em análise (RF-A04.8): o que já foi
/// enviado, o que falta e o que voltou rejeitado — com o motivo.
class EstadoDocumentos extends ChangeNotifier {
  final RepositorioDocumentos _documentos;
  final RepositorioUploads _uploads;

  EstadoDocumentos({
    required RepositorioDocumentos documentos,
    required RepositorioUploads uploads,
  }) : _documentos = documentos,
       _uploads = uploads;

  Carregavel<SituacaoDocumental> _estado = const Carregando();
  final Map<PropositoUpload, EnvioEmCurso> _envios = {};
  String? _erroDeEnvio;

  Carregavel<SituacaoDocumental> get estado => _estado;
  Map<PropositoUpload, EnvioEmCurso> get envios => Map.unmodifiable(_envios);
  String? get erroDeEnvio => _erroDeEnvio;

  bool enviando(PropositoUpload tipo) => _envios.containsKey(tipo);

  Future<void> carregar() async {
    _estado = const Carregando();
    notifyListeners();
    await _buscar();
  }

  Future<void> recarregar() => _buscar();

  /// Fluxo completo de um documento: upload em três fases e vínculo.
  ///
  /// Falha em qualquer etapa **não perde o que já foi feito nas
  /// outras** — o usuário reenvia só este documento (RF-A04.7).
  Future<bool> enviarDocumento({
    required PropositoUpload tipo,
    required Uint8List bytes,
    required String tipoDeConteudo,
  }) async {
    if (enviando(tipo)) return false;

    _erroDeEnvio = null;
    _envios[tipo] = EnvioEmCurso(tipo: tipo, cancelamento: CancelToken());
    notifyListeners();

    try {
      final uploadId = await _uploads.enviar(
        bytes: bytes,
        tipoDeConteudo: tipoDeConteudo,
        proposito: tipo,
        cancelamento: _envios[tipo]!.cancelamento,
        aoProgredir: (p) {
          final atual = _envios[tipo];
          if (atual == null) return;
          _envios[tipo] = atual.com(progresso: p);
          notifyListeners();
        },
      );

      await _documentos.enviar(tipo: tipo, uploadId: uploadId);
      _envios.remove(tipo);
      await _buscar();
      return true;
    } on ErroApi catch (erro) {
      _erroDeEnvio = erro.mensagemParaUsuario;
      _envios.remove(tipo);
      notifyListeners();
      return false;
    }
  }

  void cancelar(PropositoUpload tipo) {
    _envios[tipo]?.cancelamento.cancel('cancelado pelo usuário');
    _envios.remove(tipo);
    notifyListeners();
  }

  /// RF-A03.9 — nada do usuário anterior sobrevive ao logout.
  void limpar() {
    for (final envio in _envios.values) {
      envio.cancelamento.cancel('sessão encerrada');
    }
    _envios.clear();
    _erroDeEnvio = null;
    _estado = const Carregando();
    notifyListeners();
  }

  Future<void> _buscar() async {
    try {
      final situacao = await _documentos.situacao();
      _estado = Pronto(situacao);
    } on ErroApi catch (erro) {
      _estado = Falhou(erro);
    } finally {
      notifyListeners();
    }
  }
}
