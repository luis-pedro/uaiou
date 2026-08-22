import 'dart:async';

import 'package:flutter/foundation.dart';

import '../estado/carregavel.dart';
import '../presenca/leitor_de_posicao.dart';
import '../rede/erros_api.dart';
import '../rede/idempotencia.dart';
import '../uploads/repositorio_uploads.dart';
import '../uploads/seletor_de_imagem.dart';
import 'modelo_entrega.dart';
import 'repositorio_entregas.dart';

/// Intervalo do polling de `GET .../delivery` — RF-A08.3 pede 8-15s.
const Duration intervaloDePolling = Duration(seconds: 10);

/// ===============================================================
/// EXECUÇÃO DA ENTREGA — A-08
/// ===============================================================
///
/// Leva o entregador do aceite até a validação: geofence só como
/// orientação (a autoridade é a resposta da API), código, escada de
/// contingência e finalização contestável com foto.
///
/// **RNF-A08.2**: [abrir] sempre busca `GET .../delivery` de novo —
/// o estado nunca é só o que já estava em memória.
///
/// **RF-A08.10**: este controlador vive no provider do app (não na
/// árvore da tela de entrega), então [uploadIdConfirmado] sobrevive a
/// um rebuild da tela — sair e voltar não perde a foto já enviada.
class ControladorEntrega extends ChangeNotifier {
  final RepositorioEntregas _repositorio;
  final RepositorioUploads _uploads;
  final SeletorDeImagem _seletor;
  final LeitorDePosicao _leitor;

  ControladorEntrega({
    required RepositorioEntregas repositorio,
    required RepositorioUploads uploads,
    required SeletorDeImagem seletor,
    LeitorDePosicao leitor = const LeitorDePosicaoGeolocator(),
  }) : _repositorio = repositorio,
       _uploads = uploads,
       _seletor = seletor,
       _leitor = leitor;

  String? _pedidoId;
  String? get pedidoId => _pedidoId;

  Timer? _pollTimer;

  Carregavel<EstadoEntrega> _estado = const Carregando();
  Carregavel<EstadoEntrega> get estado => _estado;
  EstadoEntrega? get entrega => _estado.valorOuNulo;

  bool _enviando = false;
  bool get enviando => _enviando;

  bool _solicitandoRecuperacao = false;
  bool get solicitandoRecuperacao => _solicitandoRecuperacao;

  bool _enviandoFoto = false;
  bool get enviandoFoto => _enviandoFoto;

  double? _progressoFoto;
  double? get progressoFoto => _progressoFoto;

  String? _uploadIdConfirmado;
  String? get uploadIdConfirmado => _uploadIdConfirmado;

  String? _erro;
  String? get erro => _erro;

  Map<String, dynamic>? _ultimaRecuperacao;
  Map<String, dynamic>? get ultimaRecuperacao => _ultimaRecuperacao;

  bool get finalizada => entrega?.finalizada ?? false;

  /// Entra na tela de execução: recarrega do servidor e liga o
  /// polling (RF-A08.2/RNF-A08.2).
  Future<void> abrir(String pedidoId) async {
    if (_pedidoId != pedidoId) {
      // Troca de pedido: a foto pendente era da entrega anterior.
      _uploadIdConfirmado = null;
    }
    _pedidoId = pedidoId;
    await _carregar();
    _iniciarPolling();
  }

  Future<void> _carregar() async {
    final id = _pedidoId;
    if (id == null) return;
    try {
      final resultado = await _repositorio.obter(id);
      _estado = Pronto(resultado);
      if (resultado.finalizada) _pararPolling();
    } on ErroApi catch (erro) {
      _estado = Falhou(erro);
    } finally {
      notifyListeners();
    }
  }

  void _iniciarPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(intervaloDePolling, (_) => _carregar());
  }

  void _pararPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// RF-A08.4/RF-A08.8 — finaliza com o código informado pelo
  /// destinatário. Erro 422 (código errado, geofence) é exposto como
  /// veio do servidor; o app não conta tentativas por conta própria.
  Future<bool> finalizarComCodigo(String codigo) async {
    if (_enviando) return false;
    final id = _pedidoId;
    if (id == null) return false;

    _enviando = true;
    _erro = null;
    notifyListeners();

    try {
      final posicao = await _leitor.posicaoAtual();
      await _repositorio.finalizarPorCodigo(
        id,
        codigo: codigo,
        lat: posicao.lat,
        lng: posicao.lng,
        chaveIdempotencia: gerarChaveIdempotencia('completion-$id'),
      );
      await _carregar();
      return true;
    } on ErroApi catch (erro) {
      _erro = erro.mensagemParaUsuario;
      // Recarrega mesmo em erro: é o servidor quem sabe as tentativas
      // restantes e se a contingência já abriu.
      await _carregar();
      return false;
    } catch (_) {
      _erro = 'Não foi possível obter a localização do aparelho.';
      notifyListeners();
      return false;
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  /// RF-A08.5 — aciona o próximo degrau da escada de contingência.
  Future<void> acionarContingencia({String motivo = 'receiver_without_code'}) async {
    if (_solicitandoRecuperacao) return;
    final id = _pedidoId;
    if (id == null) return;

    _solicitandoRecuperacao = true;
    _erro = null;
    notifyListeners();

    try {
      _ultimaRecuperacao = await _repositorio.solicitarRecuperacao(id, motivo: motivo);
      await _carregar();
    } on ErroApi catch (erro) {
      _erro = erro.mensagemParaUsuario;
    } finally {
      _solicitandoRecuperacao = false;
      notifyListeners();
    }
  }

  /// RF-A08.6 — captura e envia a foto de comprovação (fluxo de
  /// três fases de A-04). Sem foto confirmada, a tela não oferece o
  /// botão de finalizar contestável.
  Future<void> capturarEEnviarFoto(OrigemDaImagem origem) async {
    if (_enviandoFoto) return;

    final imagem = await _seletor.escolher(origem);
    if (imagem == null) return;

    _enviandoFoto = true;
    _progressoFoto = 0;
    _erro = null;
    notifyListeners();

    try {
      final id = await _uploads.enviar(
        bytes: imagem.bytes,
        tipoDeConteudo: imagem.tipoDeConteudo,
        proposito: PropositoUpload.comprovanteEntrega,
        aoProgredir: (progresso) {
          _progressoFoto = progresso;
          notifyListeners();
        },
      );
      _uploadIdConfirmado = id;
    } on ErroApi catch (erro) {
      _erro = erro.mensagemParaUsuario;
    } finally {
      _enviandoFoto = false;
      _progressoFoto = null;
      notifyListeners();
    }
  }

  void descartarFoto() {
    if (_uploadIdConfirmado == null) return;
    _uploadIdConfirmado = null;
    notifyListeners();
  }

  /// RF-A08.6/RF-A08.7/RF-A08.8 — finaliza pela via contestável.
  /// Exige `uploadIdConfirmado`; a tela já garante isso não oferecendo
  /// o botão sem foto, mas a guarda fica aqui também.
  Future<bool> finalizarContestavel() async {
    if (_enviando) return false;
    final id = _pedidoId;
    final uploadId = _uploadIdConfirmado;
    if (id == null || uploadId == null) return false;

    _enviando = true;
    _erro = null;
    notifyListeners();

    try {
      final posicao = await _leitor.posicaoAtual();
      await _repositorio.finalizarContestavel(
        id,
        uploadId: uploadId,
        lat: posicao.lat,
        lng: posicao.lng,
        chaveIdempotencia: gerarChaveIdempotencia('completion-$id'),
      );
      _uploadIdConfirmado = null;
      await _carregar();
      return true;
    } on ErroApi catch (erro) {
      _erro = erro.mensagemParaUsuario;
      return false;
    } catch (_) {
      _erro = 'Não foi possível obter a localização do aparelho.';
      notifyListeners();
      return false;
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  void limparErro() {
    if (_erro == null) return;
    _erro = null;
    notifyListeners();
  }

  /// Sai da tela: encerra o polling (RF-A08.3), mas preserva a foto já
  /// confirmada — RF-A08.10.
  void fechar() {
    _pararPolling();
  }

  /// RF-A03.9 — logout descarta tudo, inclusive a foto pendente.
  void limpar() {
    _pararPolling();
    _pedidoId = null;
    _estado = const Carregando();
    _uploadIdConfirmado = null;
    _erro = null;
    _enviando = false;
    _solicitandoRecuperacao = false;
    _ultimaRecuperacao = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pararPolling();
    super.dispose();
  }
}
