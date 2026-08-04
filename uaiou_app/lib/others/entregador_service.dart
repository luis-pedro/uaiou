import 'pedido.dart';

/// ===============================================================
/// ESTADO DO ENTREGADOR
/// ===============================================================
///
/// Singleton simples para compartilhar dados entre as telas do
/// entregador enquanto não existe integração com backend/Firebase
/// (mesmo padrão do EstabelecimentoService).
///
/// - `nomeEntregador`, `avaliacao`: preenchidos no login/cadastro do
///   entregador.
/// - `disponivel`: alternado pelo próprio entregador na Tela Principal.
/// - `ganhosHoje`, `entregasHoje`: devem ser calculados a partir das
///   entregas concluídas no dia assim que existir uma lista real de
///   entregas vinda do backend (hoje ficam como valores simples,
///   como placeholder).
/// - `entregas`: pedidos atribuídos a esse entregador (aceitos ou
///   entregues). Preenchida conforme o app for atribuindo pedidos —
///   por enquanto começa vazia.
class EntregadorService {
  EntregadorService._();

  static final EntregadorService instance = EntregadorService._();

  /// Nome do entregador logado.
  String nomeEntregador = "";

  /// Cidade do entregador (ex: "Santa Rita do Sapucaí - MG"),
  /// exibida na Tela de Perfil.
  String cidadeEntregador = "";

  /// URL/caminho da foto de perfil do entregador.
  /// Vazio = mostra um avatar padrão.
  String fotoUrl = "";

  /// Avaliação média do entregador (ex: 4.8).
  double avaliacao = 0;

  /// Se o entregador está disponível para receber novas entregas.
  bool disponivel = true;

  /// Ganhos do entregador no dia atual.
  double ganhosHoje = 0;

  /// Quantidade de entregas realizadas no dia atual.
  int entregasHoje = 0;

  /// Pedidos atribuídos a esse entregador.
  final List<Pedido> entregas = [];

  /// ============================================================
  /// LISTAS DERIVADAS — usadas na Tela de Entregas
  /// ============================================================

  List<Pedido> get entregasPendentes => entregas
      .where((e) =>
          e.status == StatusPedido.pendente ||
          e.status == StatusPedido.aceito)
      .toList();

  List<Pedido> get entregasConcluidas =>
      entregas.where((e) => e.status == StatusPedido.entregue).toList();

  List<Pedido> get entregasCanceladas =>
      entregas.where((e) => e.status == StatusPedido.cancelado).toList();
}