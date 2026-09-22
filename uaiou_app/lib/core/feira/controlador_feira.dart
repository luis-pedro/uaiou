import 'package:flutter/foundation.dart';

import '../rede/erros_api.dart';
import '../sessao/controlador_sessao.dart';
import 'modelos_feira.dart';
import 'repositorio_feira.dart';

/// ===============================================================
/// CONTROLADOR DO MODO FEIRA — `docs/feira/`
/// ===============================================================
///
/// Estado de tudo que a demonstração precisa: se o modo está ligado,
/// a vitrine de pedidos-prêmio e a última captura (o comprovante que o
/// visitante mostra no balcão).
class ControladorFeira extends ChangeNotifier {
  final RepositorioFeira _repositorio;
  final ControladorSessao _sessao;

  ControladorFeira({
    required RepositorioFeira repositorio,
    required ControladorSessao sessao,
    required this.habilitado,
  }) : _repositorio = repositorio,
       _sessao = sessao;

  /// Decidido uma vez, na abertura do app (`main`), antes de existir
  /// árvore de widgets: assim a primeira tela já é a certa, sem piscar
  /// o app do produto e trocar para a feira no quadro seguinte.
  final bool habilitado;

  List<PedidoFeira> _pedidos = const [];
  List<PedidoFeira> get pedidos => _pedidos;

  bool _carregando = false;
  bool get carregando => _carregando;

  /// Captura recém-feita, para a tela abrir o comprovante. Zerada
  /// depois de exibida — é evento, não estado de tela.
  CapturaFeira? _ultimaCaptura;
  CapturaFeira? get ultimaCaptura => _ultimaCaptura;

  String? _erro;
  String? get erro => _erro;

  /// Em curso, para o botão do pedido não disparar duas capturas com
  /// um toque duplo enquanto a primeira não respondeu.
  String? _capturando;
  String? get capturando => _capturando;

  /// Entrada do jogador. A sessão devolvida é adotada pelo controlador
  /// de sessão, que é quem persiste credencial no app — a feira não
  /// guarda token por conta própria.
  Future<void> entrar({required String nome, required String username}) async {
    _erro = null;
    _carregando = true;
    notifyListeners();
    try {
      final sessao = await _repositorio.entrar(nome: nome, username: username);
      await _sessao.adotarSessaoExterna(sessao);
    } on ErroApi catch (e) {
      _erro = e.mensagemParaUsuario;
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<void> carregarPedidos() async {
    _carregando = true;
    notifyListeners();
    try {
      _pedidos = await _repositorio.pedidos();
      _erro = null;
    } on ErroApi catch (e) {
      _erro = e.mensagemParaUsuario;
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// Uma captura por pessoa por pedido é regra do servidor (constraint
  /// no banco); aqui o 409 vira mensagem, não exceção na tela.
  Future<void> capturar(String pedidoId) async {
    if (_capturando != null) return;
    _capturando = pedidoId;
    _erro = null;
    notifyListeners();
    try {
      _ultimaCaptura = await _repositorio.capturar(pedidoId);
      await carregarPedidos();
    } on ErroApi catch (e) {
      _erro = e.mensagemParaUsuario;
    } finally {
      _capturando = null;
      notifyListeners();
    }
  }

  void comprovanteExibido() {
    _ultimaCaptura = null;
    notifyListeners();
  }

  void limpar() {
    _pedidos = const [];
    _ultimaCaptura = null;
    _erro = null;
    _capturando = null;
    notifyListeners();
  }
}
