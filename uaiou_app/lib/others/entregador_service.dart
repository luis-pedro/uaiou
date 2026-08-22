import 'package:flutter/foundation.dart';

import '../core/modelos/status_pedido.dart';
import '../core/pedidos/lista_de_pedidos.dart';
import '../core/pedidos/repositorio_pedidos.dart';
import '../core/sessao/controlador_sessao.dart';

/// ===============================================================
/// ESTADO DO ENTREGADOR — RF-A03.2
/// ===============================================================
///
/// Substitui o antigo `EntregadorService.instance`, um singleton
/// mutável que as telas liam direto e que nunca falhava — o que fazia
/// toda tela supor que o dado já estava lá.
///
/// Agora as listas vêm do servidor, cada uma com o próprio estado de
/// carga (RF-A03.5): o app **não** filtra uma lista local para
/// derivar "pendentes" e "concluídas", porque o recorte é do servidor.
class EstadoEntregador extends ChangeNotifier {
  final ControladorSessao _sessao;

  /// `GET /orders?status=accepted` — entregas em andamento.
  final ListaDePedidos emAndamento;

  /// `GET /orders?status=finalized` — histórico.
  final ListaDePedidos concluidas;

  EstadoEntregador({
    required RepositorioPedidos repositorio,
    required ControladorSessao sessao,
  }) : _sessao = sessao,
       emAndamento = ListaDePedidos(repositorio, recorte: StatusPedido.aceito),
       concluidas = ListaDePedidos(
         repositorio,
         recorte: StatusPedido.entregue,
       ) {
    // As listas são notificadores próprios. Sem repassar, uma tela que
    // observa apenas esta loja nunca sabe que a carga terminou — e
    // fica girando para sempre.
    emAndamento.addListener(notifyListeners);
    concluidas.addListener(notifyListeners);
  }

  @override
  void dispose() {
    emAndamento.removeListener(notifyListeners);
    concluidas.removeListener(notifyListeners);
    super.dispose();
  }

  /// Nome vem da sessão (A-02). Cidade e foto são de `GET /me`, que
  /// pertence a A-05.
  String get nome => _sessao.usuario?.nomeExibicao ?? '';

  // Nota do entregador (A-12) não vive mais aqui: o cabeçalho e o
  // perfil leem `GET /me/score` via `ControladorScore`, que sabe
  // distinguir "sem nota ainda" de "nota zero" — este estado não
  // precisa (nem deve) espelhar isso.

  /// ⚠️ **A-06.** Disponibilidade real é `PUT /me/availability`. Até
  /// lá o app não tem como saber, e não deve fingir que sabe.
  bool? get disponivel => null;

  // Ganhos e contagem de entregas vêm de `ControladorGanhos`
  // (`GET /me/earnings`) — A-09. Não são mais campos deste estado.

  Future<void> carregar() async {
    await Future.wait([emAndamento.carregar(), concluidas.carregar()]);
  }

  /// RF-A03.9 — descarta tudo no logout.
  void limpar() {
    emAndamento.limpar();
    concluidas.limpar();
    notifyListeners();
  }
}
