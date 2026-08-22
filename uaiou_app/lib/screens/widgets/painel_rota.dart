import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:uaiou/core/rotas/controlador_rota.dart';
import 'package:uaiou/core/rotas/modelo_rota.dart';
import 'package:uaiou/screens/tela_navegacao.dart';
import 'package:uaiou/screens/widgets/mapa_rota.dart';

/// ===============================================================
/// PAINEL DE ROTA — A-14
/// ===============================================================
///
/// Um só painel para os dois lugares onde a rota aparece: a entrega em
/// andamento (A-08) e o detalhe do pedido antes do aceite (A-07). O
/// que muda entre eles é o que está em volta, não a forma de mostrar
/// caminho, distância e navegação.
///
/// **RF-A14.6 — sem rota, a tela continua funcionando.** Falha de
/// provedor vira uma linha de texto explicativa; não há botão de erro,
/// nem bloqueio, nem alarme. O entregador nunca fica impedido de
/// finalizar porque um traçado não carregou.
class PainelRota extends StatelessWidget {
  final ControladorRota controlador;

  /// Id do pedido — a navegação lê a rota do mesmo controlador, mas
  /// precisa saber de qual pedido ela é para poder recalcular.
  final String pedidoId;

  /// Posição do entregador (A-06), quando o chamador já a tem.
  final LatLng? posicaoAtual;

  /// Linha reta que a vitrine mostrou para este pedido (RF-11.7). Vem
  /// do chamador porque só ele sabe qual número o entregador acabou de
  /// ver na lista — é isso que RF-A14.5 pede para não confundir.
  final double? distanciaEmLinhaRetaKm;

  /// Altura do mapa embutido. O chamador decide: na entrega em
  /// andamento ele ocupa a maior parte da tela, na folha da vitrine
  /// divide espaço com o resumo do pedido.
  final double alturaDoMapa;

  const PainelRota({
    super.key,
    required this.controlador,
    required this.pedidoId,
    this.posicaoAtual,
    this.distanciaEmLinhaRetaKm,
    this.alturaDoMapa = 260,
  });

  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controlador,
      builder: (context, _) => controlador.estado.quando(
        carregando: _carregando,
        vazio: () => _semRota(context, 'Trajeto indisponível.'),
        // Erro de rota é informação, não interrupção: nenhuma outra
        // parte da tela depende disto.
        falhou: (_) => _semRota(
          context,
          'Não foi possível carregar o trajeto agora.',
          comTentarNovamente: true,
        ),
        pronto: (rota) => _buildRota(context, rota),
      ),
    );
  }

  Widget _carregando() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: corPrincipal),
      ),
    ),
  );

  Widget _semRota(
    BuildContext context,
    String mensagem, {
    bool comTentarNovamente = false,
  }) {
    return Row(
      children: [
        Icon(Icons.map_outlined, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            mensagem,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
        if (comTentarNovamente)
          TextButton(
            onPressed: controlador.recarregar,
            child: const Text('Tentar de novo'),
          ),
      ],
    );
  }

  Widget _buildRota(BuildContext context, RotaDoPedido rota) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rota.temTracado)
          MapaRota(
            rota: rota,
            posicaoAtual: posicaoAtual,
            altura: alturaDoMapa,
            aoExpandir: () => _abrirNavegacao(context),
          )
        else
          _semRota(context, rota.trajeto.explicacao),

        // RF-A14.5 — onde as duas medidas convivem, cada uma é dita
        // pelo nome. "2,1 km" da lista contra "3,0 km" da rota, sem
        // explicação, é chamado de suporte aberto.
        ..._comparacaoDeDistancias(rota),

        // RF-25.5 — a rota existe, mas não passa pela loja: dizer isso
        // evita o entregador achar que o app o mandou pular a retirada.
        if (rota.temTracado && !rota.trajeto.passaPelaRetirada) ...[
          const SizedBox(height: 8),
          _semRota(
            context,
            'O estabelecimento não marcou o ponto dele: o trajeto vai direto ao destino.',
          ),
        ],

        if (rota.temTracado) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _abrirNavegacao(context),
              icon: const Icon(Icons.navigation),
              label: const Text('Iniciar navegação'),
              style: ElevatedButton.styleFrom(
                backgroundColor: corPrincipal,
                foregroundColor: Colors.white,
                // RNF-A14.2: alvo grande, uso de rua com uma mão.
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _abrirNavegacao(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TelaNavegacao(pedidoId: pedidoId)),
    );
  }

  List<Widget> _comparacaoDeDistancias(RotaDoPedido rota) {
    final linhaReta = distanciaEmLinhaRetaKm ?? rota.distanciaEmLinhaRetaKm;
    final porVia = rota.trajeto.distanciaPorViaKm;
    if (linhaReta == null && porVia == null) return const [];

    return [
      const SizedBox(height: 10),
      Text(
        [
          if (porVia != null) '${porVia.toStringAsFixed(1)} km pelas ruas',
          if (linhaReta != null)
            '${linhaReta.toStringAsFixed(1)} km em linha reta (o número da lista)',
        ].join(' · '),
        style: const TextStyle(fontSize: 13, color: Colors.black87),
      ),
    ];
  }
}
