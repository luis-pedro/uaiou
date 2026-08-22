import 'package:flutter/foundation.dart';

import '../modelos/dinheiro.dart';
import '../rede/erros_api.dart';
import '../../others/pedido.dart';
import 'repositorio_pedidos.dart';

/// ===============================================================
/// PUBLICAR PEDIDO — RF-A10.1/RF-A10.2/RF-A10.3/RF-A10.4/RNF-A10.1
/// ===============================================================
///
/// Cria o pedido em `POST /orders`. Segue o mesmo padrão de reentrância
/// de `ControladorCadastro`/`ControladorVitrine`: o campo `_enviando`
/// em memória, não a reconstrução da tela, é o que impede um segundo
/// `POST` a partir de um duplo toque (RNF-A10.1).
class ControladorPublicarPedido extends ChangeNotifier {
  final RepositorioPedidos _repositorio;

  ControladorPublicarPedido(this._repositorio);

  bool _enviando = false;
  bool get enviando => _enviando;

  /// Mensagem de negócio da última tentativa (RF-A10.4:
  /// `INSUFFICIENT_CREDITS` sem oferta de compra; `UNGEOCODABLE_ADDRESS`
  /// aponta pro campo de endereço).
  String? _erro;
  String? get erro => _erro;

  /// `true` quando o erro é falta de crédito — a tela usa isto para
  /// mostrar o caminho de suporte, nunca um botão de comprar (a v1 não
  /// vende crédito no app).
  bool _semCredito = false;
  bool get semCredito => _semCredito;

  bool _enderecoInvalido = false;
  bool get enderecoInvalido => _enderecoInvalido;

  void limparErro() {
    if (_erro == null) return;
    _erro = null;
    _semCredito = false;
    _enderecoInvalido = false;
    notifyListeners();
  }

  /// Devolve o pedido criado, ou `null` em falha (mensagem em [erro]).
  Future<Pedido?> publicar({
    required Dinheiro valorProposto,
    required String rua,
    required String numero,
    required String bairro,
    required double? lat,
    required double? lng,
    required String nomeRecebedor,
    String? complemento,
    String? telefoneRecebedor,
    DateTime? prazoEsperado,
  }) async {
    if (_enviando) return null;

    // RF-A10.3 — sem ponto marcado no mapa não publica: endereço
    // errado consome crédito e produz entrega impossível.
    if (lat == null || lng == null) {
      _erro = 'Marque o ponto de entrega no mapa antes de publicar.';
      _enderecoInvalido = true;
      notifyListeners();
      return null;
    }

    _enviando = true;
    _erro = null;
    _semCredito = false;
    _enderecoInvalido = false;
    notifyListeners();

    try {
      final pedido = await _repositorio.publicar(
        valorProposto: valorProposto,
        rua: rua,
        numero: numero,
        bairro: bairro,
        lat: lat,
        lng: lng,
        nomeRecebedor: nomeRecebedor,
        complemento: complemento,
        telefoneRecebedor: telefoneRecebedor,
        prazoEsperado: prazoEsperado,
      );
      return pedido;
    } on RegraDeNegocio catch (erro) {
      _erro = erro.mensagemParaUsuario;
      _semCredito = erro.codigo == 'INSUFFICIENT_CREDITS';
      _enderecoInvalido = erro.codigo == 'UNGEOCODABLE_ADDRESS';
      return null;
    } on ErroApi catch (erro) {
      _erro = erro.mensagemParaUsuario;
      return null;
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }
}
