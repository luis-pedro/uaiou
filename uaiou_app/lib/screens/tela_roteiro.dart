import 'package:flutter/material.dart';

import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/presenca/controlador_presenca.dart';
import 'package:uaiou/core/rede/erros_api.dart';
import 'package:uaiou/core/rotas/modelo_rota.dart';
import 'package:uaiou/core/rotas/modelo_roteiro.dart';
import 'package:uaiou/core/rotas/repositorio_rotas.dart';
import 'package:uaiou/core/tema/cores.dart';
import 'package:uaiou/others/entregador_service.dart';
import 'package:uaiou/others/pedido.dart';
import 'package:uaiou/screens/widgets/instrucoes_de_rota.dart';
import 'package:uaiou/screens/widgets/mapa_rota.dart';

/// ===============================================================
/// ROTEIRO — todas as entregas em andamento num trajeto só
/// ===============================================================
///
/// Para quem aceitou mais de um pedido: mapa com o traçado completo e,
/// embaixo, as paradas na ordem sugerida pelo servidor — cada coleta
/// antes da sua entrega.
///
/// A navegação curva a curva continua sendo a de cada pedido
/// ([TelaNavegacao]); esta tela responde "por onde eu vou primeiro?".
/// Consulta sob demanda: abre, busca uma vez, e só refaz no botão
/// "Recalcular" (RNF-A14.1 — consumo com teto).
class TelaRoteiro extends StatefulWidget {
  const TelaRoteiro({super.key});

  @override
  State<TelaRoteiro> createState() => _TelaRoteiroState();
}

class _TelaRoteiroState extends State<TelaRoteiro> {
  static const Color corPrincipal = CoresUaiou.principal;

  RoteiroDoEntregador? _roteiro;
  ErroApi? _erro;
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buscar());
  }

  PontoGeo? _posicao() {
    final lida = context.read<ControladorPresenca>().posicaoAtual;
    return lida == null ? null : PontoGeo(lida.lat, lida.lng);
  }

  Future<void> _buscar() async {
    if (_buscando) return;
    setState(() => _buscando = true);
    try {
      final roteiro = await context.read<RepositorioRotas>().obterRoteiro(
        origem: _posicao(),
      );
      if (!mounted) return;
      setState(() {
        _roteiro = roteiro;
        _erro = null;
      });
    } on ErroApi catch (erro) {
      // Recálculo que falhou não apaga um roteiro bom já em mãos.
      if (mounted && _roteiro == null) setState(() => _erro = erro);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roteiro = _roteiro;
    final lida = context.watch<ControladorPresenca>().posicaoAtual;
    final posicao = lida == null ? null : PontoGeo(lida.lat, lida.lng);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
        title: const Text('Roteiro das entregas'),
        actions: [
          IconButton(
            tooltip: 'Recalcular a partir daqui',
            onPressed: _buscando ? null : _buscar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: roteiro == null
          ? _carregandoOuErro(context)
          : roteiro.semPedidos
          ? _aviso(context, 'Você não tem entregas em andamento.')
          : Column(
              children: [
                if (roteiro.temTracado)
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.42,
                    child: MapaRota(
                      rota: roteiro.comoRotaDoPedido(),
                      posicaoAtual: posicao == null
                          ? null
                          : LatLng(posicao.lat, posicao.lng),
                      preencher: true,
                    ),
                  )
                else
                  _faixa(context, roteiro.trajeto.explicacao),
                _resumo(context, roteiro),
                Expanded(child: _paradas(context, roteiro, posicao)),
              ],
            ),
    );
  }

  Widget _resumo(BuildContext context, RoteiroDoEntregador roteiro) {
    final trajeto = roteiro.trajeto;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${roteiro.paradas.length} paradas',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (trajeto.distanciaPorViaKm != null)
                Text(
                  '${trajeto.distanciaPorViaKm!.toStringAsFixed(1)} km'
                  '${trajeto.duracaoMinutos == null ? '' : ' · ${trajeto.duracaoMinutos} min'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.cores.textoSuave,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            roteiro.otimizado
                ? 'Ordem calculada pelo menor tempo, sempre coletando antes de entregar.'
                : 'Ordem de aceite dos pedidos, coletando antes de entregar.',
            style: TextStyle(fontSize: 12, color: context.cores.textoSuave),
          ),
          if (trajeto.passos.length > 1)
            TextButton.icon(
              onPressed: () => mostrarPassosDaRota(context, trajeto),
              icon: const Icon(Icons.list, size: 18),
              label: const Text('Ver todas as instruções'),
              style: TextButton.styleFrom(foregroundColor: corPrincipal),
            ),
          if (roteiro.atribuicao != null)
            Text(
              roteiro.atribuicao!,
              style: TextStyle(fontSize: 10, color: context.cores.textoSuave),
            ),
        ],
      ),
    );
  }

  Widget _paradas(
    BuildContext context,
    RoteiroDoEntregador roteiro,
    PontoGeo? posicao,
  ) {
    // Nome da loja e endereço vêm da lista que a tela de entregas já
    // carregou — o roteiro só traz ids e coordenadas.
    final pedidos = {
      for (final p in context.watch<EstadoEntregador>().emAndamento.itens)
        p.id: p,
    };
    final proxima = roteiro.proximaParadaDe(posicao);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: roteiro.paradas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final parada = roteiro.paradas[i];
        return _cartaoParada(
          context,
          ordem: i + 1,
          parada: parada,
          pedido: pedidos[parada.pedidoId],
          destaque: identical(parada, proxima),
        );
      },
    );
  }

  Widget _cartaoParada(
    BuildContext context, {
    required int ordem,
    required ParadaDoRoteiro parada,
    required Pedido? pedido,
    required bool destaque,
  }) {
    final coleta = parada.tipo == TipoParada.coleta;
    final nomeLoja = pedido?.nomeEstabelecimento?.isNotEmpty == true
        ? pedido!.nomeEstabelecimento!
        : 'Pedido ${pedido?.rotuloCurto ?? ''}'.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cores.superficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: destaque ? corPrincipal : context.cores.textoSuave,
          width: destaque ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: destaque ? corPrincipal : context.cores.textoSuave,
            foregroundColor: Colors.white,
            child: Text('$ordem', style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Icon(
            coleta ? Icons.storefront_outlined : Icons.location_on_outlined,
            color: corPrincipal,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coleta ? 'Coletar em $nomeLoja' : 'Entregar — $nomeLoja',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (!coleta && pedido != null)
                  Text(
                    pedido.enderecoResumido,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.cores.textoSuave,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                if (destaque)
                  const Text(
                    'Próxima parada',
                    style: TextStyle(fontSize: 12, color: corPrincipal),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _faixa(BuildContext context, String texto) {
    return Container(
      width: double.infinity,
      color: context.cores.textoSuave.withValues(alpha: 0.12),
      padding: const EdgeInsets.all(14),
      child: Text(
        '$texto As paradas abaixo continuam valendo.',
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _carregandoOuErro(BuildContext context) {
    final erro = _erro;
    if (erro == null) {
      return const Center(
        child: CircularProgressIndicator(color: corPrincipal),
      );
    }
    return _aviso(context, erro.mensagem, tentarDeNovo: true);
  }

  Widget _aviso(
    BuildContext context,
    String texto, {
    bool tentarDeNovo = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alt_route, size: 44, color: context.cores.textoSuave),
            const SizedBox(height: 14),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            if (tentarDeNovo) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _buscar,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar de novo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
