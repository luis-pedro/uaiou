import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/endereco/endereco_publico.dart';
import 'package:uaiou/core/modelos/dinheiro.dart';
import 'package:uaiou/core/pedidos/controlador_publicar_pedido.dart';
import 'package:uaiou/core/pedidos/repositorio_pedidos.dart';
import 'package:uaiou/screens/widgets/mapa_endereco.dart';

/// ===============================================================
/// PUBLICAR PEDIDO — RF-A10.1/RF-A10.2/RF-A10.3
/// ===============================================================
///
/// Substitui o diálogo de `tela_principal_estabelecimento.dart` que só
/// coletava texto e nunca chamava o servidor. `POST /orders` exige
/// coordenada resolvida (`ClientSuppliedGeocodingService.java` — o
/// backend não geocodifica endereço textual), por isso o formulário
/// usa [MapaEndereco]: o mesmo seletor de toque-marca-o-ponto já usado
/// no endereço do estabelecimento (A-05), aqui para o destino da
/// entrega.
class TelaPublicarPedido extends StatefulWidget {
  const TelaPublicarPedido({super.key});

  @override
  State<TelaPublicarPedido> createState() => _TelaPublicarPedidoState();
}

class _TelaPublicarPedidoState extends State<TelaPublicarPedido> {
  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  final _formKey = GlobalKey<FormState>();
  final _freteController = TextEditingController();
  final _ruaController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _bairroController = TextEditingController();
  final _nomeRecebedorController = TextEditingController();
  final _telefoneRecebedorController = TextEditingController();

  double? _lat;
  double? _lng;

  late final ControladorPublicarPedido _controlador;

  @override
  void initState() {
    super.initState();
    _controlador = ControladorPublicarPedido(
      context.read<RepositorioPedidos>(),
    );
  }

  @override
  void dispose() {
    _freteController.dispose();
    _ruaController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroController.dispose();
    _nomeRecebedorController.dispose();
    _telefoneRecebedorController.dispose();
    _controlador.dispose();
    super.dispose();
  }

  /// Chamado quando o fluxo `coordenada -> CEP -> ViaCEP` volta com um
  /// endereço para o ponto tocado. Sobrescreve rua e bairro — marcar
  /// outro ponto no mapa é justamente dizer "o destino é outro" —, mas
  /// **nunca** o número: nenhum CEP sabe o número da casa, e apagar o
  /// que o usuário já digitou é pior do que deixar em branco.
  void _preencherComEndereco(EnderecoPublico endereco) {
    setState(() {
      if (endereco.rua != null) _ruaController.text = endereco.rua!;
      if (endereco.bairro != null) _bairroController.text = endereco.bairro!;
    });
  }

  Future<void> _publicar() async {
    if (!_formKey.currentState!.validate()) return;

    final valor = Dinheiro.tentarDeString(
      _freteController.text.replaceAll(',', '.'),
    );
    if (valor == null || !valor.ePositivo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor de frete válido.')),
      );
      return;
    }

    final pedido = await _controlador.publicar(
      valorProposto: valor,
      rua: _ruaController.text.trim(),
      numero: _numeroController.text.trim(),
      bairro: _bairroController.text.trim(),
      complemento: _complementoController.text.trim().isEmpty
          ? null
          : _complementoController.text.trim(),
      lat: _lat,
      lng: _lng,
      nomeRecebedor: _nomeRecebedorController.text.trim(),
      telefoneRecebedor: _telefoneRecebedorController.text.trim().isEmpty
          ? null
          : _telefoneRecebedorController.text.trim(),
    );

    if (!mounted) return;

    if (pedido != null) {
      Navigator.pop(context, true);
      return;
    }

    // A recusa por falta de ponto no mapa (RF-A10.3) só era mostrada no
    // texto sob o [MapaEndereco], que num celular fica fora da tela na
    // hora do toque — a caixa vermelha acima do botão é justamente a que
    // se esconde quando `enderecoInvalido`. Sem isto, a tentativa que nem
    // chega a virar `POST /orders` não produz nenhum sinal visível: o
    // botão parece morto.
    final erro = _controlador.erro;
    if (erro != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
        title: const Text('Pedir um entregador'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controlador,
          builder: (context, _) => Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _rotulo('Valor do frete'),
                TextFormField(
                  controller: _freteController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _decoracao('Ex.: 6,00'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe o valor do frete.'
                      : null,
                ),
                const SizedBox(height: 18),

                _rotulo('Destino da entrega'),
                TextFormField(
                  controller: _ruaController,
                  decoration: _decoracao('Rua'),
                  validator: _obrigatorio,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _numeroController,
                        decoration: _decoracao('Número'),
                        validator: _obrigatorio,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _complementoController,
                        decoration: _decoracao('Complemento (opcional)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _bairroController,
                  decoration: _decoracao('Bairro'),
                  validator: _obrigatorio,
                ),
                const SizedBox(height: 14),

                // RF-A10.3 — confirmação visual do ponto antes de
                // publicar.
                MapaEndereco(
                  latInicial: _lat,
                  lngInicial: _lng,
                  aoMudar: (ponto) => setState(() {
                    _lat = ponto.latitude;
                    _lng = ponto.longitude;
                  }),
                  aoResolverEndereco: _preencherComEndereco,
                ),
                if (_controlador.enderecoInvalido)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _controlador.erro ?? 'Endereço inválido.',
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),

                const SizedBox(height: 20),
                _rotulo('Recebedor'),
                TextFormField(
                  controller: _nomeRecebedorController,
                  decoration: _decoracao('Nome de quem recebe'),
                  validator: _obrigatorio,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _telefoneRecebedorController,
                  keyboardType: TextInputType.phone,
                  decoration: _decoracao('Telefone (opcional)'),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sem telefone, o código de entrega só pode ser repassado '
                  'por você diretamente ao recebedor.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),

                const SizedBox(height: 24),

                if (_controlador.erro != null && !_controlador.enderecoInvalido)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _controlador.erro!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        // RF-A10.4 — mensagem de negócio, sem oferta de
                        // compra: a v1 não vende crédito no app.
                        if (_controlador.semCredito) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/perfil_estabelecimento',
                            ),
                            child: const Text(
                              'Ver meus créditos no perfil',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                ElevatedButton(
                  onPressed: _controlador.enviando ? null : _publicar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: corPrincipal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _controlador.enviando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Publicar pedido',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _obrigatorio(String? valor) =>
      (valor == null || valor.trim().isEmpty) ? 'Campo obrigatório.' : null;

  Widget _rotulo(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      texto,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
    ),
  );

  InputDecoration _decoracao(String rotulo) => InputDecoration(
    labelText: rotulo,
    filled: true,
    fillColor: Colors.grey.shade100,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}
