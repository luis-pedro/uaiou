import 'dart:async';

import 'package:flutter/foundation.dart';

import '../rede/erros_api.dart';
import 'leitor_de_posicao.dart';
import 'repositorio_presenca.dart';

/// Deslocamento mínimo, em metros, para o stream de posição emitir uma
/// nova leitura (RF-A06.3, critério 5). 30m é menor que a maioria dos
/// raios de geofence de entrega — a posição não fica velha demais para
/// a listagem de pedidos — mas grande o bastante para não gerar
/// tráfego a cada solavanco de GPS parado num semáforo.
const int filtroDeDistanciaMetros = 30;

/// ===============================================================
/// PRESENÇA DO ENTREGADOR — A-06
/// ===============================================================
///
/// Liga o botão "Disponível/Indisponível" e o mapa da tela principal
/// ao backend: `PUT /me/availability`, `PUT /me/location` e a queda de
/// presença detectada em `GET /me` (RF-A06.8).
///
/// **Fora de escopo desta implementação, por limitação de plataforma:**
/// RF-A06.5 (segundo plano com entrega ativa) e a etapa de permissão
/// em segundo plano de RF-A06.6 dependem de capacidade nativa
/// (Android/iOS background location) que uma aba de navegador não tem.
/// O envio aqui é sempre em primeiro plano, enquanto a aba está aberta
/// — ver [LeitorDePosicaoGeolocator.stream].
class ControladorPresenca extends ChangeNotifier {
  final RepositorioPresenca _repositorio;
  final LeitorDePosicao _leitor;

  ControladorPresenca({
    required RepositorioPresenca repositorio,
    LeitorDePosicao leitor = const LeitorDePosicaoGeolocator(),
  }) : _repositorio = repositorio,
       _leitor = leitor;

  /// `null` até a primeira chamada — o app não afirma disponibilidade
  /// nem indisponibilidade sem o servidor ter confirmado uma vez.
  bool? _disponivel;
  bool get disponivel => _disponivel ?? false;
  bool get sabeDisponibilidade => _disponivel != null;

  bool _enviando = false;
  bool get enviando => _enviando;

  String? _erro;
  String? get erro => _erro;

  PosicaoLida? _posicaoAtual;
  PosicaoLida? get posicaoAtual => _posicaoAtual;

  StreamSubscription<PosicaoLida>? _assinatura;

  /// RF-A06.2 — só para centrar o mapa na posição real do aparelho.
  /// Não exige disponibilidade nem manda nada ao servidor: falhar
  /// (serviço desligado, permissão negada) deixa o mapa no fallback
  /// fixo, não trava a tela.
  Future<void> lerPosicaoInicial() async {
    try {
      if (!await _leitor.servicoHabilitado()) return;
      if (!await _leitor.permissaoConcedida() && !await _leitor.pedirPermissao()) {
        return;
      }
      _posicaoAtual = await _leitor.posicaoAtual();
      notifyListeners();
    } catch (_) {
      // Mapa permanece no centro fixo — ver doc da classe.
    }
  }

  /// RF-A06.1/RF-A06.6/RF-A06.7 — alterna disponibilidade contra o
  /// servidor. O estado exibido só muda com a resposta confirmada; em
  /// falha, volta ao anterior.
  Future<void> alternarDisponibilidade(bool querDisponivel) async {
    if (_enviando) return;
    final anterior = _disponivel;

    if (querDisponivel) {
      final bloqueio = await _verificarPreCondicoes();
      if (bloqueio != null) {
        _erro = bloqueio;
        notifyListeners();
        return;
      }
    }

    _enviando = true;
    _erro = null;
    notifyListeners();

    try {
      if (querDisponivel) {
        // RN-01.1: ativar exige localização recente no servidor — manda
        // a posição antes de pedir disponibilidade para não bater no
        // 422 LOCATION_REQUIRED de usuarios.md.
        final posicao = await _leitor.posicaoAtual();
        _posicaoAtual = posicao;
        await _repositorio.enviarLocalizacao(
          lat: posicao.lat,
          lng: posicao.lng,
          precisao: posicao.precisao,
        );
      }

      final confirmado = await _repositorio.definirDisponibilidade(querDisponivel);
      _disponivel = confirmado;

      if (confirmado) {
        _iniciarEnvioDePosicao();
      } else {
        _pararEnvioDePosicao();
      }
    } on ErroApi catch (e) {
      _disponivel = anterior;
      _erro = e.mensagemParaUsuario;
    } catch (_) {
      _disponivel = anterior;
      _erro = 'Não foi possível obter a localização do aparelho.';
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  Future<String?> _verificarPreCondicoes() async {
    if (!await _leitor.servicoHabilitado()) {
      return 'Ative a localização do aparelho para ficar disponível.';
    }
    if (!await _leitor.permissaoConcedida()) {
      final concedeu = await _leitor.pedirPermissao();
      if (!concedeu) {
        // Web: não há tela de configurações do SO para abrir — a
        // orientação possível é liberar o site nas configurações do
        // navegador.
        return 'Permissão de localização negada. Libere o acesso à '
            'localização para este site nas configurações do navegador '
            'para ficar disponível.';
      }
    }
    return null;
  }

  void _iniciarEnvioDePosicao() {
    if (_assinatura != null) return;
    _assinatura = _leitor
        .stream(filtroDeDistanciaMetros: filtroDeDistanciaMetros)
        .listen(_aoReceberPosicao);
  }

  /// RF-A06.4 — encerra o envio quando deixa de fazer sentido.
  void _pararEnvioDePosicao() {
    _assinatura?.cancel();
    _assinatura = null;
  }

  Future<void> _aoReceberPosicao(PosicaoLida posicao) async {
    _posicaoAtual = posicao;
    notifyListeners();
    try {
      await _repositorio.enviarLocalizacao(
        lat: posicao.lat,
        lng: posicao.lng,
        precisao: posicao.precisao,
      );
    } on ErroApi {
      // RNF-A06.2 — descarta a leitura e espera a próxima do stream,
      // em vez de enfileirar sem teto.
    }
  }

  /// RF-A06.8 — leitura leve de `GET /me` para notar que o servidor
  /// expirou a presença por inatividade (job de T-10). Chamada ao
  /// focar a tela; sem polling agressivo nesta v1 web.
  Future<void> recarregarDoServidor() async {
    if (_disponivel != true) return;
    try {
      final doServidor = await _repositorio.obterDisponibilidadeDoServidor();
      if (doServidor == false) {
        _disponivel = false;
        _pararEnvioDePosicao();
        notifyListeners();
      }
    } on ErroApi {
      // Falha na checagem não deve derrubar um estado local que ainda
      // pode estar correto.
    }
  }

  /// RF-A03.9/RF-A06.4 — logout interrompe o envio e descarta o que o
  /// usuário anterior tinha.
  void limpar() {
    _pararEnvioDePosicao();
    _disponivel = null;
    _enviando = false;
    _erro = null;
    _posicaoAtual = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pararEnvioDePosicao();
    super.dispose();
  }
}
