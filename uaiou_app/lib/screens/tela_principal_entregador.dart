import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:uaiou/core/gamificacao/controlador_score.dart';
import 'package:uaiou/core/ganhos/controlador_ganhos.dart';
import 'package:uaiou/core/modelos/dinheiro.dart';
import 'package:uaiou/core/notificacoes/controlador_notificacoes.dart';
import 'package:uaiou/core/pedidos/controlador_vitrine.dart';
import 'package:uaiou/core/presenca/controlador_presenca.dart';
import 'package:uaiou/core/rotas/controlador_rota.dart';
import 'package:uaiou/others/entregador_service.dart';
import 'package:uaiou/others/pedido.dart';
import 'package:uaiou/screens/widgets/aviso_flutuante.dart';
import 'package:uaiou/screens/widgets/painel_rota.dart';
import 'package:uaiou/screens/widgets/visao_carregavel.dart';

class TelaPrincipalEntregador extends StatefulWidget {
  const TelaPrincipalEntregador({super.key});

  @override
  State<TelaPrincipalEntregador> createState() =>
      _TelaPrincipalEntregadorState();
}

class _TelaPrincipalEntregadorState extends State<TelaPrincipalEntregador> {
  int paginaAtual = 0;

  // Cor principal do app (laranja)
  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  // Santa Rita do Sapucaí — só o ponto de partida enquanto a primeira
  // leitura real do aparelho não chega (RF-A06.2).
  static const LatLng _centroPadrao = LatLng(-22.2526, -45.7033);

  final MapController _mapController = MapController();
  bool _pediuLeituraInicial = false;

  // RF-A07.9 — a vitrine só é buscada enquanto disponível. Este flag
  // evita chamar `carregar()` a cada rebuild; vira `false` de novo
  // quando o entregador cai para indisponível, para recarregar limpo
  // na próxima vez que ficar disponível.
  bool _vitrineCarregada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Uma vez por abertura da tela: busca a posição para centrar o
    // mapa e checa se o servidor já derrubou a presença (RF-A06.8).
    if (!_pediuLeituraInicial) {
      _pediuLeituraInicial = true;
      final presenca = context.read<ControladorPresenca>();
      presenca.lerPosicaoInicial();
      presenca.recarregarDoServidor();
      _priorizarEntregaEmAndamento();
      // RF-A09.1 — o card de ganhos é alimentado por `GET /me/earnings`,
      // nunca por soma feita no cliente.
      context.read<ControladorGanhos>().carregar();
      // RF-A11.7 — contador de não lidas no menu, alimentado por
      // `meta.unread` (nunca somado localmente).
      context.read<ControladorNotificacoes>().carregar();
      // RF-A12.4 — nota do cabeçalho vem de `GET /me/score`.
      context.read<ControladorScore>().carregar();
    }
  }

  /// RF-A08.9 — com entrega ativa (`accepted`), abrir o app leva direto
  /// a ela em vez da tela principal.
  Future<void> _priorizarEntregaEmAndamento() async {
    final estado = context.read<EstadoEntregador>();
    await estado.emAndamento.carregar();
    if (!mounted) return;
    final itens = estado.emAndamento.itens;
    if (itens.isEmpty) return;
    final ativa = itens.first;
    Navigator.pushReplacementNamed(
      context,
      '/entrega_em_andamento',
      arguments: ativa.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMapa(),
          _buildAvaliacao(),
          _buildAvisos(),
          _buildStatusDisponibilidade(),
          _buildCardGanhos(),
          _buildPainelVitrine(),
          _buildMenuInferior(),
        ],
      ),
    );
  }

  // MAPA
  Widget _buildMapa() {
    final posicao = context.watch<ControladorPresenca>().posicaoAtual;
    final centro = posicao != null
        ? LatLng(posicao.lat, posicao.lng)
        : _centroPadrao;

    if (posicao != null) {
      // O mapa já foi construído com `initialCenter`; recentrar em
      // leituras seguintes precisa do controller, fora do build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _mapController.move(centro, _mapController.camera.zoom);
        } catch (_) {
          // Controller ainda não anexado no primeiro frame — ignora,
          // o próximo `notifyListeners` tenta de novo.
        }
      });
    }

    return Positioned.fill(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: _centroPadrao, initialZoom: 15),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.uaiou.app',
          ),

          // RF-A07.2 pede marcador por pedido elegível, mas
          // `GET /orders?status=published` não traz coordenadas do
          // pedido — só o bairro (`DestinationResponse.apenasBairro`,
          // conferido no DTO real: a vitrine devolve endereço completo
          // só depois do aceite, RF-11.6). Sem lat/lng não há posição
          // real para o pino; inventar uma seria mostrar informação
          // que o servidor não deu. Os pedidos aparecem no painel
          // abaixo, com o que o servidor realmente manda.
          MarkerLayer(
            markers: [
              if (posicao != null)
                Marker(
                  point: centro,
                  width: 45,
                  height: 45,
                  child: const Icon(
                    Icons.location_on,
                    color: corPrincipal,
                    size: 45,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // AVALIAÇÃO (canto superior esquerdo)
  Widget _buildAvaliacao() {
    return Positioned(
      top: 40,
      left: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: corPrincipal, size: 18),
            const SizedBox(width: 6),
            Text(
              // RF-A12.4/critério 8 de A-12 — nota vem de
              // `GET /me/score` (via `ControladorScore`, compartilhado
              // com o perfil), nunca do `double?` estático que o
              // singleton antigo (`EstadoEntregador.avaliacao`, sempre
              // nulo) expunha. Sem score ainda (entregador novo, 404),
              // mostra "—" em vez de "0,0", que seria uma afirmação
              // falsa de nota ruim.
              context.watch<ControladorScore>().score?.valor.replaceAll('.', ',') ?? "—",
              style: const TextStyle(
                color: Color.fromRGBO(94, 94, 94, 1),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // STATUS DE DISPONIBILIDADE (canto superior direito, tocável)
  Widget _buildStatusDisponibilidade() {
    // RF-A06.1 — o estado exibido é o confirmado pelo servidor, nunca
    // otimista: enquanto `enviando` é true, mostra progresso em vez de
    // já alternar a cor.
    final presenca = context.watch<ControladorPresenca>();
    final bool disponivel = presenca.disponivel;
    final bool enviando = presenca.enviando;

    final Color corTexto = disponivel
        ? const Color.fromRGBO(108, 201, 80, 1)
        : Colors.grey.shade300;

    final Color corFundo = disponivel
        ? const Color.fromRGBO(17, 76, 0, 0.73)
        : Colors.black.withValues(alpha: 0.55);

    final Color corBorda = disponivel
        ? const Color.fromRGBO(108, 201, 80, 1)
        : Colors.grey;

    return Positioned(
      top: 40,
      right: 20,
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: enviando ? null : () => _alternarDisponibilidade(presenca, !disponivel),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: corFundo,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: corBorda, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (enviando)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: corTexto,
                  ),
                )
              else
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: corTexto,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 10),
              Text(
                disponivel ? "Disponível" : "Indisponível",
                style: TextStyle(color: corTexto, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _alternarDisponibilidade(
    ControladorPresenca presenca,
    bool querDisponivel,
  ) async {
    await presenca.alternarDisponibilidade(querDisponivel);
    final erro = presenca.erro;
    if (erro != null && mounted) {
      mostrarAviso(context, erro, erro: true);
    }
  }

  // CARD DE GANHOS — RF-A09.1/RF-A09.2. "Ganhos de hoje" do protótipo
  // vira "total ganho no período": o servidor não expõe recorte diário
  // em `GET /me/earnings`, então o app não inventa um filtro de dia
  // que a API não oferece.
  Widget _buildCardGanhos() {
    final ganhos = context.watch<ControladorGanhos>();
    final resumo = ganhos.resumo;

    return Positioned(
      top: 95,
      left: 15,
      right: 15,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Ganhos do período",
                  style: TextStyle(
                    color: Color.fromRGBO(94, 94, 94, 1),
                    fontSize: 15,
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, '/extrato_ganhos'),
                  child: const Text(
                    "Ver extrato",
                    style: TextStyle(
                      color: corPrincipal,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              resumo.total.formatarBRL(),
              style: const TextStyle(
                color: Color.fromRGBO(34, 34, 34, 1),
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildRotuloGanho(
                    "A receber",
                    resumo.receivable.formatarBRL(),
                    Colors.orange.shade800,
                  ),
                ),
                Expanded(
                  child: _buildRotuloGanho(
                    "Recebido",
                    resumo.settled.formatarBRL(),
                    Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRotuloGanho(String rotulo, String valor, Color cor) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            "$rotulo $valor",
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: cor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  /// ============================================================
  /// VITRINE DE PEDIDOS — A-07
  /// ============================================================

  /// Painel deslizante com a vitrine (RF-A07.1/RF-A07.2), gated pela
  /// disponibilidade (RF-A07.9). A checagem cruza dois controladores
  /// de propósito: [ControladorPresenca] é quem sabe se está
  /// disponível, [ControladorVitrine] é quem sabe os pedidos — nenhum
  /// dos dois deveria depender do outro para essas responsabilidades.
  Widget _buildPainelVitrine() {
    final presenca = context.watch<ControladorPresenca>();

    if (!presenca.disponivel) {
      // Reseta para recarregar limpo na próxima vez que ficar
      // disponível, em vez de reaparecer com uma vitrine velha.
      _vitrineCarregada = false;
      return _buildVitrineIndisponivel();
    }

    final vitrine = context.watch<ControladorVitrine>();

    if (!_vitrineCarregada) {
      _vitrineCarregada = true;
      // RNF-A03.1 — carga tem ciclo de vida próprio; não dispara
      // requisição dentro de `build`.
      WidgetsBinding.instance.addPostFrameCallback((_) => vitrine.carregar());
    }

    _mostrarAvisoSeHouver(vitrine);

    return DraggableScrollableSheet(
      initialChildSize: 0.28,
      minChildSize: 0.12,
      maxChildSize: 0.92,
      builder: (context, controlador) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: ListenableBuilder(
          listenable: vitrine,
          builder: (context, _) => RefreshIndicator(
            // RF-A07.7 — gesto de recarregar.
            color: corPrincipal,
            onRefresh: vitrine.recarregar,
            child: ListView(
              controller: controlador,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Pedidos disponíveis",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color.fromRGBO(34, 34, 34, 1),
                      ),
                    ),
                    IconButton(
                      onPressed: vitrine.recarregar,
                      icon: const Icon(Icons.refresh, color: corPrincipal),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                VisaoCarregavel<List<Pedido>>(
                  estado: vitrine.pedidos.estado,
                  aoTentarNovamente: vitrine.carregar,
                  textoVazio: "Nenhum pedido por perto agora",
                  iconeVazio: Icons.local_shipping_outlined,
                  construir: (pedidos) => Column(
                    children: pedidos
                        .map((pedido) => _buildCardPedidoVitrine(pedido, vitrine))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// RF-A07.9 — estado explicando, com atalho pro toggle de
  /// disponibilidade em vez de um vazio mudo.
  Widget _buildVitrineIndisponivel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 85),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.visibility_off, color: Colors.grey.shade500),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Fique disponível para ver os pedidos por perto.",
                style: TextStyle(
                  color: Color.fromRGBO(94, 94, 94, 1),
                  fontSize: 14,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _alternarDisponibilidade(
                context.read<ControladorPresenca>(),
                true,
              ),
              child: const Text(
                "Ativar",
                style: TextStyle(color: corPrincipal, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mostra o aviso de RF-A07.4 (disputa perdida) ou de outra falha em
  /// um `SnackBar` e o descarta, para não repetir a cada rebuild.
  void _mostrarAvisoSeHouver(ControladorVitrine vitrine) {
    final aviso = vitrine.aviso;
    if (aviso == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      mostrarAviso(context, aviso);
      vitrine.limparAviso();
    });
  }

  Widget _buildCardPedidoVitrine(Pedido pedido, ControladorVitrine vitrine) {
    final podeAceitar = pedido.links.permite('assignment');
    final podeContrapropor = pedido.links.permite('counteroffers');
    final propostaPendente = vitrine.temPropostaPendente(pedido.id);
    final aceitandoEste = vitrine.aceitando(pedido.id);
    final contrapondoEste = vitrine.contrapondo(pedido.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color.fromRGBO(94, 94, 94, 1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pedido.nomeEstabelecimento?.isNotEmpty == true
                      ? pedido.nomeEstabelecimento!
                      : "Pedido ${pedido.rotuloCurto}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(34, 34, 34, 1),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // RNF-A07.2 — valor sempre pelo tipo Dinheiro.
              Text(
                pedido.freteProposto.formatarBRL(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: corPrincipal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pedido.distanciaKm != null
                ? "${pedido.enderecoResumido} · ${pedido.distanciaKm!.toStringAsFixed(1)} km"
                : pedido.enderecoResumido,
            style: const TextStyle(fontSize: 13, color: Color.fromRGBO(94, 94, 94, 1)),
          ),
          // RF-A14.4 — a distância que decide o aceite é a por via, e
          // ela custa uma chamada ao provedor: fica atrás de um toque,
          // por pedido, em vez de entrar na listagem inteira (RF-25.7).
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _abrirRota(pedido),
              icon: const Icon(Icons.alt_route, size: 18),
              label: const Text('Ver trajeto e distância real'),
              style: TextButton.styleFrom(
                foregroundColor: corPrincipal,
                padding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
          if (propostaPendente) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.hourglass_top, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Text(
                  "Contraproposta enviada — aguardando o estabelecimento",
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                ),
              ],
            ),
          ],
          if (podeAceitar || (podeContrapropor && !propostaPendente)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // RF-A07.6 — só aparece quando `_links` oferece.
                if (podeContrapropor && !propostaPendente)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: vitrine.haContrapropostaEmVoo
                          ? null
                          : () => _abrirDialogoContraoferta(pedido, vitrine),
                      style: OutlinedButton.styleFrom(foregroundColor: corPrincipal),
                      child: contrapondoEste
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Contrapropor"),
                    ),
                  ),
                if (podeAceitar) ...[
                  if (podeContrapropor && !propostaPendente) const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      // RNF-A07.1 — bloqueado enquanto há aceite em
                      // voo (deste ou de outro cartão: um só por vez).
                      onPressed: vitrine.haAceiteEmVoo
                          ? null
                          : () => _aceitarPedido(pedido, vitrine),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: corPrincipal,
                        foregroundColor: Colors.white,
                      ),
                      child: aceitandoEste
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("Aceitar"),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// RF-A14.4/RF-A14.5 — o detalhe antes do aceite: traçado, distância
  /// por via e, ao lado dela, a linha reta que a lista mostrou, cada
  /// uma com o nome. Uma abertura, uma rota (RNF-A14.1).
  Future<void> _abrirRota(Pedido pedido) async {
    final rota = context.read<ControladorRota>();
    final posicao = context.read<ControladorPresenca>().posicaoAtual;
    rota.carregar(pedido.id);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (contexto) => SafeArea(
        // Rolável: com o mapa alto, a folha passa da tela em aparelho
        // pequeno — e conteúdo cortado é pior que conteúdo rolável.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pedido.nomeEstabelecimento?.isNotEmpty == true
                    ? pedido.nomeEstabelecimento!
                    : 'Pedido ${pedido.rotuloCurto}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                pedido.enderecoResumido,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              PainelRota(
                controlador: rota,
                pedidoId: pedido.id,
                distanciaEmLinhaRetaKm: pedido.distanciaKm,
                posicaoAtual: posicao == null
                    ? null
                    : LatLng(posicao.lat, posicao.lng),
                alturaDoMapa: MediaQuery.sizeOf(context).height * .42,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _aceitarPedido(Pedido pedido, ControladorVitrine vitrine) async {
    final aceitou = await vitrine.aceitar(pedido.id);
    if (!mounted) return;

    final aviso = vitrine.aviso;
    if (aviso != null) {
      mostrarAviso(context, aviso);
      vitrine.limparAviso();
    }

    // RF-A07.8 — aceite não termina sem próximo passo visível.
    if (aceitou) {
      Navigator.pushReplacementNamed(context, '/entregas_entregador');
    }
  }

  Future<void> _abrirDialogoContraoferta(
    Pedido pedido,
    ControladorVitrine vitrine,
  ) async {
    final controladorTexto = TextEditingController();
    final valor = await showDialog<Dinheiro>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Contrapropor frete"),
        content: TextField(
          controller: controladorTexto,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: "R\$ ",
            hintText: "0,00",
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              // Aceita vírgula, formato comum de digitação em pt-BR;
              // `Dinheiro` só entende ponto decimal.
              final bruto = controladorTexto.text.trim().replaceAll(',', '.');
              final dinheiro = Dinheiro.tentarDeString(bruto);
              Navigator.pop(dialogContext, dinheiro);
            },
            child: const Text("Enviar"),
          ),
        ],
      ),
    );

    if (valor == null || !mounted) return;

    await vitrine.contrapropor(pedido.id, valor);
    if (!mounted) return;

    final aviso = vitrine.aviso;
    if (aviso != null) {
      mostrarAviso(context, aviso);
      vitrine.limparAviso();
    } else {
      mostrarAviso(context, "Contraproposta enviada.");
    }
  }

  /// ============================================================
  /// MENU INFERIOR
  /// ============================================================

  Widget _buildMenuInferior() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        width: double.infinity,
        height: 85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 15,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildItemMenu(index: 0, icone: Icons.home, texto: "Principal"),
              _buildItemMenu(
                index: 1,
                icone: Icons.local_shipping,
                texto: "Entregas",
              ),
              _buildItemMenu(
                index: 2,
                icone: Icons.list_alt,
                texto: "Atividades",
              ),
              _buildItemMenu(index: 4, icone: Icons.person, texto: "Perfil"),
            ],
          ),
        ),
      ),
    );
  }

  /// ============================================================
  /// ITEM DO MENU
  /// ============================================================

  Widget _buildItemMenu({
    required int index,
    required IconData icone,
    required String texto,
  }) {
    final bool selecionado = paginaAtual == index;

    final Color cor = selecionado ? corPrincipal : Colors.grey;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _onItemMenuTap(index),
      child: SizedBox(
        width: 85,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, color: cor, size: 27),
            const SizedBox(height: 5),
            Text(texto, style: TextStyle(color: cor, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  /// RF-A11.7 — avisos no canto superior esquerdo, ao lado da nota, em
  /// vez de item da barra inferior: os quatro itens que sobraram lá são
  /// **lugares onde se fica** (principal, entregas, atividades, perfil),
  /// e avisos é uma consulta rápida da qual se volta. O contador
  /// continua vindo de `meta.unread` do servidor, nunca somado aqui.
  Widget _buildAvisos() {
    final naoLidas = context.watch<ControladorNotificacoes>().naoLidas;

    return Positioned(
      top: 40,
      left: 100,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () => Navigator.pushNamed(context, '/notificacoes'),
          child: Padding(
            // RNF-A14.2/RNF-A08.1 — alvo grande: mesmo uso de rua do
            // resto da tela.
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  color: corPrincipal,
                  size: 22,
                ),
                if (naoLidas > 0)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        naoLidas > 99 ? "99+" : "$naoLidas",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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

  /// ============================================================
  /// NAVEGAÇÃO
  /// ============================================================

  void _onItemMenuTap(int index) {
    if (paginaAtual == index) return;

    setState(() {
      paginaAtual = index;
    });

    switch (index) {
      case 0:
        break;

      case 1:
        Navigator.pushReplacementNamed(context, '/entregas_entregador');
        break;

      case 2:
        Navigator.pushReplacementNamed(context, '/atividades_entregador');
        break;

      case 4:
        Navigator.pushReplacementNamed(context, '/perfil_entregador');
        break;
    }
  }
}
