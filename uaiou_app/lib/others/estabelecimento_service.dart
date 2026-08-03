import 'pedido.dart';

/// ===============================================================
/// ESTADO DO ESTABELECIMENTO
/// ===============================================================
///
/// Singleton simples para compartilhar dados entre telas enquanto
/// não existe integração com backend/Firebase:
///
/// - `nomeRestaurante`: preenchido na tela de LOGIN do estabelecimento.
/// - `pedidos`: preenchido pela TELA PRINCIPAL quando o botão
///   "Pedir um entregador" é confirmado, e lido pela TELA DE PEDIDOS.
///
/// Quando o backend existir, essa classe pode passar a buscar/salvar
/// os dados remotamente (ex: Firestore) sem precisar mudar as telas
/// que a usam — elas só leem `instance.nomeRestaurante` e
/// `instance.pedidos`.
class EstabelecimentoService {
  EstabelecimentoService._();

  static final EstabelecimentoService instance = EstabelecimentoService._();

  /// Nome do estabelecimento logado.
  String nomeRestaurante = "";

  /// Lista de pedidos feitos pelo estabelecimento.
  final List<Pedido> pedidos = [];

  int _proximoNumeroPedido = 6246;

  /// Cria e adiciona um novo pedido.
  /// Chamado pelo botão "Pedir um entregador" na Tela Principal.
  Pedido adicionarPedido({
    required String bairro,
    required String rua,
    required String numero,
    double valor = 0,
  }) {
    final pedido = Pedido(
      numeroPedido: _proximoNumeroPedido++,
      bairro: bairro,
      rua: rua,
      numero: numero,
      valor: valor,
      status: StatusPedido.pendente,
    );

    // Pedido mais novo aparece primeiro na lista.
    pedidos.insert(0, pedido);
    return pedido;
  }

  /// ============================================================
  /// TOTAIS — usados na Tela de Atividades
  /// ============================================================

  List<Pedido> get pedidosEntregues =>
      pedidos.where((p) => p.status == StatusPedido.entregue).toList();

  List<Pedido> get pedidosCancelados =>
      pedidos.where((p) => p.status == StatusPedido.cancelado).toList();

  /// Soma o valor dos pedidos entregues feitos hoje.
  double get faturamentoHoje {
    final hoje = DateTime.now();

    return pedidos
        .where((p) =>
            p.status == StatusPedido.entregue &&
            p.data.year == hoje.year &&
            p.data.month == hoje.month &&
            p.data.day == hoje.day)
        .fold(0.0, (soma, p) => soma + p.valor);
  }
}