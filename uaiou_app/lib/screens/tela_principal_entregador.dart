import 'package:flutter/material.dart';

import 'package:uaiou/screens/widgets/dialogo_padrao.dart';
import 'package:uaiou/core/tema/cores.dart';
import 'package:uaiou/screens/widgets/ui.dart';
import 'package:uaiou/screens/casca_principal.dart';
import 'package:provider/provider.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:uaiou/screens/widgets/camada_mapa_base.dart';
import 'package:latlong2/latlong.dart';

import 'package:uaiou/core/gamificacao/controlador_score.dart';
import 'package:uaiou/core/ganhos/controlador_ganhos.dart';
import 'package:uaiou/core/modelos/dinheiro.dart';
import 'package:uaiou/core/notificacoes/controlador_notificacoes.dart';
import 'package:uaiou/core/pedidos/controlador_vitrine.dart';
import 'package:uaiou/core/presenca/controlador_presenca.dart';
import 'package:uaiou/core/rotas/controlador_rota.dart';
import 'package:uaiou/core/rotas/modelo_rota.dart';
import 'package:uaiou/others/entregador_service.dart';
import 'package:uaiou/others/pedido.dart';
import 'package:uaiou/screens/widgets/aviso_flutuante.dart';
import 'package:uaiou/screens/tela_roteiro.dart';
import 'package:uaiou/screens/widgets/painel_rota.dart';
import 'package:uaiou/screens/widgets/visao_carregavel.dart';

class TelaPrincipalEntregador extends StatefulWidget {
  const TelaPrincipalEntregador({super.key});

  @override
  State<TelaPrincipalEntregador> createState() =>
      _TelaPrincipalEntregadorState();
}

class _TelaPrincipalEntregadorState extends State<TelaPrincipalEntregador> {
  // Cor principal do app (laranja)
  static const Color corPrincipal = CoresUaiou.principal;

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

  /// Já levou à entrega ativa desde que o app abriu.
  static bool _jaPriorizou = false;

  /// RF-A08.9 — com entrega ativa (`accepted`), **abrir o app** leva
  /// direto a ela em vez da tela principal.
  ///
  /// Uma vez por abertura, não a cada visita à Principal: redirecionar
  /// sempre deixava quem tem entrega em andamento sem acesso à vitrine —
  /// e sem vitrine não há como pegar um segundo pedido.
  Future<void> _priorizarEntregaEmAndamento() async {
    final estado = context.read<EstadoEntregador>();
    // Carrega sempre: além do redirecionamento, é esta lista que decide se
    // o card da vitrine oferece a prévia do roteiro.
    await estado.emAndamento.carregar();
    if (!mounted || _jaPriorizou) return;
    _jaPriorizou = true;
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
          // Barra flutuante do topo: nota à esquerda, estado e avisos à
          // direita. Os ganhos desceram para o painel, junto dos pedidos —
          // o topo do mapa fica livre para o mapa.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    _buildAvaliacao(),
                    const Spacer(),
                    _buildStatusDisponibilidade(),
                    const SizedBox(width: 8),
                    _buildAvisos(),
                  ],
                ),
              ),
            ),
          ),
          _buildControlesDoMapa(),
          _buildPainelVitrine(),
        ],
      ),
    );
  }

  /// Controle de rua à direita do mapa: recentrar. Fica na altura
  /// do polegar, fora da área da folha de pedidos.
  Widget _buildControlesDoMapa() {
    return Positioned(
      right: 16,
      top: MediaQuery.paddingOf(context).top + 84,
      child: Column(
        children: [
          _botaoDoMapa(
            icone: Icons.my_location_rounded,
            rotulo: 'Centralizar',
            aoTocar: _centralizar,
          ),
        ],
      ),
    );
  }

  Widget _botaoDoMapa({
    required IconData icone,
    required String rotulo,
    required VoidCallback aoTocar,
    Color? cor,
  }) {
    final cores = context.cores;
    return Column(
      children: [
        Material(
          color: cores.superficie,
          shape: const CircleBorder(),
          elevation: 3,
          shadowColor: cores.sombra,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: aoTocar,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(icone, color: cor ?? cores.texto, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          rotulo,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: cores.texto,
            shadows: [Shadow(color: cores.superficie, blurRadius: 6)],
          ),
        ),
      ],
    );
  }

  void _centralizar() {
    final posicao = context.read<ControladorPresenca>().posicaoAtual;
    if (posicao == null) {
      context.read<ControladorPresenca>().lerPosicaoInicial();
      mostrarAviso(context, 'Buscando sua localização…');
      return;
    }
    _mapController.move(LatLng(posicao.lat, posicao.lng), 16);
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
          const CamadaMapaBase(),

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
    return Padding(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.cores.superficie,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: context.cores.sombra,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
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
              context.watch<ControladorScore>().score?.valor.replaceAll(
                    '.',
                    ',',
                  ) ??
                  "—",
              style: TextStyle(
                color: context.cores.texto,
                fontSize: 15,
                fontWeight: FontWeight.w700,
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

    const Color corTexto = Colors.white;

    final Color corFundo = disponivel
        ? CoresUaiou.principal
        : const Color(0xFF292524);

    return Padding(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: enviando
            ? null
            : () => _alternarDisponibilidade(presenca, !disponivel),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: corFundo,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: context.cores.sombra,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
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
                    color: disponivel ? Colors.white : const Color(0xFFA8A29E),
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 10),
              Text(
                disponivel ? "Online" : "Offline",
                style: const TextStyle(
                  color: corTexto,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
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

  Widget _buildGanhosCompactos() {
    final resumo = context.watch<ControladorGanhos>().resumo;
    final cores = context.cores;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pushNamed(context, '/extrato_ganhos'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const IconeTingido(
              Icons.account_balance_wallet_outlined,
              tamanho: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ganhos do período',
                    style: TextStyle(fontSize: 12, color: cores.textoSuave),
                  ),
                  Text(
                    resumo.total.formatarBRL(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: cores.texto,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'A receber ',
              style: TextStyle(fontSize: 12, color: cores.textoSuave),
            ),
            Text(
              resumo.receivable.formatarBRL(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cores.atencao,
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cores.textoSuave),
          ],
        ),
      ),
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
      initialChildSize: 0.45,
      minChildSize: 0.22,
      maxChildSize: 0.92,
      builder: (context, controlador) => Container(
        decoration: BoxDecoration(
          color: context.cores.superficie,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: context.cores.sombra,
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
              padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: context.cores.borda,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _buildGanhosCompactos(),
                const SizedBox(height: 8),
                Divider(color: context.cores.borda),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Pedidos disponíveis",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.cores.texto,
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
                        .map(
                          (pedido) => _buildCardPedidoVitrine(pedido, vitrine),
                        )
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
    final enviando = context.watch<ControladorPresenca>().enviando;
    final cores = context.cores;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: BoxDecoration(
          color: cores.superficie,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: cores.sombra,
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cores.borda,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              "Pronto para rodar?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: cores.texto,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Fique online e receba pedidos da sua região.",
              style: TextStyle(color: cores.textoSuave, fontSize: 15),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: enviando
                    ? null
                    : () => _alternarDisponibilidade(
                        context.read<ControladorPresenca>(),
                        true,
                      ),
                style: ElevatedButton.styleFrom(
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                icon: enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.power_settings_new_rounded, size: 24),
                label: const Text("Ficar online"),
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: cores.borda),
            _buildGanhosCompactos(),
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
        color: context.cores.superficie,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.cores.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconeTingido(Icons.storefront_rounded, tamanho: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pedido.nomeEstabelecimento?.isNotEmpty == true
                      ? pedido.nomeEstabelecimento!
                      : "Pedido ${pedido.rotuloCurto}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.cores.texto,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // RNF-A07.2 — valor sempre pelo tipo Dinheiro.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: CoresUaiou.principal.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  pedido.freteProposto.formatarBRL(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: CoresUaiou.principal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pedido.distanciaKm != null
                ? "${pedido.enderecoResumido} · ${pedido.distanciaKm!.toStringAsFixed(1)} km"
                : pedido.enderecoResumido,
            style: TextStyle(fontSize: 13, color: context.cores.textoSuave),
          ),
          // Quanto o entregador vai rodar no total: até a loja e dela até
          // o cliente. Linha reta, por isso o "~".
          if (pedido.distanciaTotalKm != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.route, size: 16, color: corPrincipal),
                const SizedBox(width: 4),
                Text(
                  "Percurso total ~${pedido.distanciaTotalKm!.toStringAsFixed(1)} km",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.cores.texto,
                  ),
                ),
              ],
            ),
          ],
          // RF-A14.4 — a distância que decide o aceite é a por via, e
          // ela custa uma chamada ao provedor: fica atrás de um toque,
          // por pedido, em vez de entrar na listagem inteira (RF-25.7).
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _abrirRota(pedido),
              icon: const Icon(Icons.alt_route, size: 18),
              label: Text(
                context.read<EstadoEntregador>().emAndamento.itens.isNotEmpty
                    ? 'Ver como fica no seu roteiro'
                    : 'Ver trajeto e distância real',
              ),
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
                Icon(
                  Icons.hourglass_top,
                  size: 16,
                  color: context.cores.atencao,
                ),
                const SizedBox(width: 6),
                Text(
                  "Contraproposta enviada — aguardando o estabelecimento",
                  style: TextStyle(fontSize: 12, color: context.cores.atencao),
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
                      style: OutlinedButton.styleFrom(
                        foregroundColor: corPrincipal,
                      ),
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
                  if (podeContrapropor && !propostaPendente)
                    const SizedBox(width: 10),
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
    // Já carregando outras entregas, a pergunta que importa é "como fica
    // o meu roteiro com este também?" — não o trajeto do pedido isolado.
    if (context.read<EstadoEntregador>().emAndamento.itens.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TelaRoteiro(candidato: pedido)),
      );
      return;
    }
    final rota = context.read<ControladorRota>();
    final posicao = context.read<ControladorPresenca>().posicaoAtual;
    rota.carregar(
      pedido.id,
      origem: posicao == null ? null : PontoGeo(posicao.lat, posicao.lng),
    );

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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                pedido.enderecoResumido,
                style: TextStyle(fontSize: 13, color: context.cores.textoSuave),
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
      if (!CascaPrincipal.irPara(context, 1)) {
        Navigator.pushReplacementNamed(context, '/entregas_entregador');
      }
    }
  }

  Future<void> _abrirDialogoContraoferta(
    Pedido pedido,
    ControladorVitrine vitrine,
  ) async {
    final controladorTexto = TextEditingController();
    final valor = await showDialog<Dinheiro>(
      context: context,
      builder: (dialogContext) => DialogoPadrao(
        titulo: "Contrapropor frete",
        icone: Icons.request_quote_outlined,
        conteudo: TextField(
          controller: controladorTexto,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: "R\$ ",
            hintText: "0,00",
          ),
          autofocus: true,
        ),
        rotuloConfirmar: "Enviar",
        aoConfirmar: () {
          // Aceita vírgula, formato comum de digitação em pt-BR;
          // `Dinheiro` só entende ponto decimal.
          final bruto = controladorTexto.text.trim().replaceAll(',', '.');
          final dinheiro = Dinheiro.tentarDeString(bruto);
          Navigator.pop(dialogContext, dinheiro);
        },
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

  /// RF-A11.7 — avisos no canto superior esquerdo, ao lado da nota, em
  /// vez de item da barra inferior: os quatro itens que sobraram lá são
  /// **lugares onde se fica** (principal, entregas, atividades, perfil),
  /// e avisos é uma consulta rápida da qual se volta. O contador
  /// continua vindo de `meta.unread` do servidor, nunca somado aqui.
  Widget _buildAvisos() => BotaoAvisos(
    naoLidas: context.watch<ControladorNotificacoes>().naoLidas,
    flutuante: true,
  );
}
