import 'dart:async';

import 'package:flutter/foundation.dart';

import '../estado/carregavel.dart';
import '../pedidos/motivos.dart';
import '../pedidos/repositorio_pedidos.dart';
import '../presenca/leitor_de_posicao.dart';
import '../rede/erros_api.dart';
import '../../others/pedido.dart';
import 'controlador_entrega.dart' show intervaloDePolling;

/// ===============================================================
/// FASE DE RETIRADA — A-15 (RF-A15.8 a RF-A15.12, RF-A15.15)
/// ===============================================================
///
/// Do aceite até o estabelecimento confirmar a coleta. A chegada é
/// detectada pelo servidor a partir das posições já enviadas pela
/// presença (RF-26.1); este controlador só oferece o que o pedido
/// permite em `_links`: "Cheguei", reaviso e desistência.
///
/// Vive no estado da tela (não no provider do app): a fase dura
/// minutos e não tem nada que precise sobreviver a sair da tela.
class ControladorRetirada extends ChangeNotifier {
  final RepositorioPedidos _repositorio;
  final LeitorDePosicao _leitor;
  final String pedidoId;

  ControladorRetirada(
    this._repositorio, {
    required this.pedidoId,
    LeitorDePosicao leitor = const LeitorDePosicaoGeolocator(),
  }) : _leitor = leitor;

  Timer? _pollTimer;

  Carregavel<Pedido> _estado = const Carregando();
  Carregavel<Pedido> get estado => _estado;
  Pedido? get pedido => _estado.valorOuNulo;

  bool _enviando = false;
  bool get enviando => _enviando;

  String? _erro;
  String? get erro => _erro;

  /// Mensagem de sucesso a exibir uma vez (ex.: "estabelecimento
  /// avisado").
  String? _aviso;
  String? get aviso => _aviso;

  bool get podeRegistrarChegada =>
      pedido?.links.permite('pickupArrival') ?? false;
  bool get podePedirNovoAviso =>
      pedido?.links.permite('pickupReminders') ?? false;
  bool get podeDesistir => pedido?.links.permite('withdrawal') ?? false;

  /// RF-A15.9 — o botão de reaviso só aparece depois de 5 min de
  /// espera; o servidor recusa antes (`REMINDER_TOO_EARLY`), e o app
  /// não oferece o que seria recusado.
  bool get reavisoLiberado {
    final chegada = pedido?.chegouEm;
    if (chegada == null || !podePedirNovoAviso) return false;
    return DateTime.now().difference(chegada) >= const Duration(minutes: 5);
  }

  Future<void> abrir() async {
    await _carregar();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(intervaloDePolling, (_) => _carregar());
  }

  Future<void> recarregar() => _carregar();

  Future<void> _carregar() async {
    try {
      _estado = Pronto(await _repositorio.obter(pedidoId));
    } on ErroApi catch (erro) {
      _estado = Falhou(erro);
    } finally {
      notifyListeners();
    }
  }

  /// RF-A15.10 — "Cheguei". Recusa por raio vem com a mensagem do
  /// servidor.
  Future<void> registrarChegada() => _executar(() async {
    final posicao = await _leitor.posicaoAtual();
    await _repositorio.registrarChegada(
      pedidoId,
      lat: posicao.lat,
      lng: posicao.lng,
    );
    _aviso = 'Chegada registrada. O estabelecimento foi avisado.';
  });

  /// RF-A15.9 — reaviso. O 429 (`REMINDER_TOO_FREQUENT`) aparece como
  /// veio.
  Future<void> pedirNovoAviso() => _executar(() async {
    await _repositorio.pedirNovoAvisoDeColeta(pedidoId);
    _aviso = 'Estabelecimento avisado de novo.';
  });

  /// RF-A15.15 — desistência. Devolve `true` quando o servidor aceitou:
  /// a tela sai da entrega, que já não é mais deste entregador.
  Future<bool> desistir(MotivoDesistencia motivo, {String? observacao}) async {
    var ok = false;
    await _executar(() async {
      await _repositorio.desistir(
        pedidoId,
        motivo: motivo,
        observacao: observacao,
      );
      ok = true;
    }, recarregarDepois: false);
    if (ok) _pararPolling();
    return ok;
  }

  Future<void> _executar(
    Future<void> Function() acao, {
    bool recarregarDepois = true,
  }) async {
    if (_enviando) return;
    _enviando = true;
    _erro = null;
    notifyListeners();
    try {
      await acao();
      if (recarregarDepois) await _carregar();
    } on ErroApi catch (erro) {
      _erro = erro.mensagemParaUsuario;
    } catch (_) {
      _erro = 'Não foi possível obter a localização do aparelho.';
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  void limparMensagens() {
    if (_erro == null && _aviso == null) return;
    _erro = null;
    _aviso = null;
    notifyListeners();
  }

  void _pararPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _pararPolling();
    super.dispose();
  }
}
