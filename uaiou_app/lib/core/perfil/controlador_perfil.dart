import 'package:flutter/foundation.dart';

import '../estado/carregavel.dart';
import '../rede/erros_api.dart';
import '../uploads/repositorio_uploads.dart';
import '../uploads/seletor_de_imagem.dart';
import 'perfil.dart';
import 'repositorio_perfil.dart';

/// Carrega `GET /me` no `initState` da tela de perfil e aplica edições
/// por `PATCH /me` — RF-A05.1/RF-A05.2.
class ControladorPerfil extends ChangeNotifier {
  final RepositorioPerfil _repositorio;
  final RepositorioUploads? _uploads;

  ControladorPerfil({
    required RepositorioPerfil repositorio,
    RepositorioUploads? uploads,
  }) : _repositorio = repositorio,
       _uploads = uploads;

  Carregavel<Perfil> _estado = const Carregando();
  Carregavel<Perfil> get estado => _estado;

  bool _enviandoFoto = false;
  bool get enviandoFoto => _enviandoFoto;

  Future<void> carregar() async {
    _estado = const Carregando();
    notifyListeners();
    await _buscar();
  }

  Future<void> recarregar() => _buscar();

  /// `true` se salvou. Erro fica em [ultimoErro] para a tela exibir.
  String? ultimoErro;

  Future<bool> salvar(EdicaoDePerfil edicao) async {
    if (edicao.estaVazia) return true;

    ultimoErro = null;
    try {
      final atualizado = await _repositorio.editar(edicao);
      _estado = Pronto(atualizado);
      notifyListeners();
      return true;
    } on ErroApi catch (erro) {
      ultimoErro = erro.mensagemParaUsuario;
      notifyListeners();
      return false;
    }
  }

  /// Envia a imagem (três fases de upload) e vincula ao perfil por
  /// `PATCH /me` com `photoUploadId`. O [proposito] é o do papel:
  /// `fotoEntregador` ou `logoEstabelecimento`.
  Future<bool> trocarFoto(ImagemEscolhida imagem, PropositoUpload proposito) async {
    final uploads = _uploads;
    if (uploads == null || _enviandoFoto) return false;

    _enviandoFoto = true;
    ultimoErro = null;
    notifyListeners();
    try {
      final uploadId = await uploads.enviar(
        bytes: imagem.bytes,
        tipoDeConteudo: imagem.tipoDeConteudo,
        proposito: proposito,
      );
      return await salvar(EdicaoDePerfil(fotoUploadId: uploadId));
    } on ErroApi catch (erro) {
      ultimoErro = erro.mensagemParaUsuario;
      return false;
    } finally {
      _enviandoFoto = false;
      notifyListeners();
    }
  }

  /// RF-A03.9 — nada do usuário anterior sobrevive ao logout.
  void limpar() {
    _estado = const Carregando();
    ultimoErro = null;
    _enviandoFoto = false;
    notifyListeners();
  }

  Future<void> _buscar() async {
    try {
      final perfil = await _repositorio.obter();
      _estado = Pronto(perfil);
    } on ErroApi catch (erro) {
      _estado = Falhou(erro);
    } finally {
      notifyListeners();
    }
  }
}
