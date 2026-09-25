import 'dart:async';

/// Com o app aberto, de quanto em quanto tempo as listas e o detalhe
/// já carregados se reconsultam mesmo sem push.
const Duration intervaloAtualizacaoPedidos = Duration(seconds: 15);

/// ===============================================================
/// SINAL DE PEDIDOS
/// ===============================================================
///
/// Avisa que o estado dos pedidos no servidor pode ter mudado. Antes,
/// cada lista só carregava no `initState` da sua tela, e o pedido
/// atualizado só aparecia trocando de tela.
///
/// Quem avisa:
/// - `ReceptorPush`: push com o app aberto, volta do segundo plano e
///   a cada [intervaloAtualizacaoPedidos] em primeiro plano (rede de
///   segurança para push perdido);
/// - os controladores, depois de uma ação que muda um pedido.
///
/// [ListaDePedidos] e [ControladorDetalhePedido] escutam e recarregam
/// em silêncio o que já tinham carregado.
class SinalPedidos {
  SinalPedidos._();

  static final SinalPedidos instancia = SinalPedidos._();

  final StreamController<Object?> _eventos = StreamController.broadcast();

  /// Cada evento carrega quem avisou (`null` = externo), para o
  /// emissor não recarregar de novo o que acabou de recarregar.
  Stream<Object?> get eventos => _eventos.stream;

  void avisar({Object? origem}) => _eventos.add(origem);
}
