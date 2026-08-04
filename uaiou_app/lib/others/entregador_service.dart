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
class EntregadorService {
  EntregadorService._();

  static final EntregadorService instance = EntregadorService._();

  /// Nome do entregador logado.
  String nomeEntregador = "";

  /// Avaliação média do entregador (ex: 4.8).
  double avaliacao = 0;

  /// Se o entregador está disponível para receber novas entregas.
  bool disponivel = true;

  /// Ganhos do entregador no dia atual.
  double ganhosHoje = 0;

  /// Quantidade de entregas realizadas no dia atual.
  int entregasHoje = 0;
}