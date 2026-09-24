import 'package:flutter/material.dart';

import 'package:uaiou/core/tema/cores.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/entregas/controlador_entrega.dart';
import 'package:uaiou/core/formato/data.dart';
import 'package:uaiou/core/entregas/controlador_retirada.dart';
import 'package:uaiou/core/entregas/modelo_entrega.dart';
import 'package:uaiou/core/pedidos/motivos.dart';
import 'package:uaiou/core/pedidos/repositorio_pedidos.dart';
import 'package:uaiou/others/pedido.dart';
import 'package:uaiou/screens/widgets/avatar_rede.dart';
import 'package:uaiou/screens/widgets/dialogo_motivo.dart';
import 'package:uaiou/core/presenca/controlador_presenca.dart';
import 'package:uaiou/core/presenca/leitor_de_posicao.dart';
import 'package:uaiou/core/rotas/controlador_rota.dart';
import 'package:uaiou/core/feira/controlador_feira.dart';
import 'package:uaiou/core/rotas/modelo_rota.dart';
import 'package:uaiou/core/uploads/seletor_de_imagem.dart';
import 'package:uaiou/screens/widgets/aviso_flutuante.dart';
import 'package:uaiou/screens/widgets/instrucoes_de_rota.dart';
import 'package:uaiou/main.dart' show feiraNestaBranch;
import 'package:uaiou/screens/widgets/mapa_rota.dart';

/// ===============================================================
/// EXECUÇÃO DA ENTREGA — A-08
/// ===============================================================
///
/// A tela em si não decide nada: cada seção só aparece quando
/// [EstadoEntrega] a autoriza — geofence, código, contingência e
/// contestável vêm todos do `_links`/estado de `GET .../delivery`
/// (RF-A08.2/RF-A08.3/RF-A08.7). RNF-A08.1: alvos grandes, alto
/// contraste, uma mão só.
class TelaEntregaEmAndamento extends StatefulWidget {
  final String pedidoId;

  const TelaEntregaEmAndamento({super.key, required this.pedidoId});

  @override
  State<TelaEntregaEmAndamento> createState() => _TelaEntregaEmAndamentoState();
}

class _TelaEntregaEmAndamentoState extends State<TelaEntregaEmAndamento> {
  static const Color corPrincipal = CoresUaiou.principal;
  static const Color corSucesso = Color.fromRGBO(108, 201, 80, 1);

  final TextEditingController _codigoController = TextEditingController();
  final FocusNode _focoCodigo = FocusNode();
  final DraggableScrollableController _folha = DraggableScrollableController();
  bool _pediuAbertura = false;

  static const double _folhaInicial = .34;
  static const double _folhaMinima = .16;
  static const double _folhaMaxima = .92;

  // Guardados na abertura: `context.read` em `dispose` não é seguro.
  late ControladorEntrega _entrega;
  late ControladorRota _rota;
  late ControladorPresenca _presenca;

  /// Incrementado para o mapa voltar a seguir o entregador.
  int _pedidosDeSeguir = 0;
  PosicaoLida? _ultimaPosicaoTratada;

  /// Modo feira: o pedido, para o mapa saber onde é o estande e o ponto. No
  /// produto essas coordenadas vinham na rota, que aqui não é calculada.
  Pedido? _pedidoFeira;

  /// Modo feira: onde fica o estande, em palavras (escrito no painel).
  String? _descricaoEstande;
  String? _ultimoStatus;
  bool _jaAbriuAoChegar = false;

  @override
  void initState() {
    super.initState();
    // Teclado aberto com a folha baixa escondia o campo do código atrás
    // do próprio teclado: ao focar, a folha sobe inteira.
    _focoCodigo.addListener(() {
      if (_focoCodigo.hasFocus) _moverFolha(_folhaMaxima);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RNF-A08.2 — sempre busca do servidor ao entrar na tela, nunca só
    // o que já está em memória.
    if (!_pediuAbertura) {
      _pediuAbertura = true;
      _entrega = context.read<ControladorEntrega>();
      _rota = context.read<ControladorRota>();
      _presenca = context.read<ControladorPresenca>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _entrega.abrir(widget.pedidoId);
        // A rota sai do GPS do aparelho, não da última posição salva.
        _rota.carregar(widget.pedidoId, origem: _pontoAtual());
        // Durante a entrega a posição vai ao servidor mesmo sem
        // "Disponível": é dela que o geofence (e o botão de finalizar)
        // dependem.
        _presenca.addListener(_aoMudarPosicao);
        _presenca.acompanharEntrega();
        if (feiraNestaBranch) _carregarPedidoFeira();
      });
    }
  }

  @override
  void dispose() {
    // RF-A08.3 — o polling não deve continuar depois que a tela fecha.
    _entrega.fechar();
    _presenca.removeListener(_aoMudarPosicao);
    _presenca.pararAcompanhamentoDeEntrega();
    _retirada?.removeListener(_avisarRetirada);
    _retirada?.dispose();
    _codigoController.dispose();
    _focoCodigo.dispose();
    _folha.dispose();
    super.dispose();
  }

  Future<void> _carregarPedidoFeira() async {
    try {
      final pedido = await context.read<RepositorioPedidos>().obter(
        widget.pedidoId,
      );
      if (mounted) setState(() => _pedidoFeira = pedido);
    } catch (_) {
      // Mapa sem pinos é degradação aceitável: as etapas em texto e o botão
      // de finalizar continuam, e é por eles que a entrega acontece.
    }
    if (!mounted) return;
    final estande = await context.read<ControladorFeira>().estande();
    if (mounted) setState(() => _descricaoEstande = estande?.descricao);
  }

  PontoGeo? _pontoAtual() {
    final posicao = _presenca.posicaoAtual;
    return posicao == null ? null : PontoGeo(posicao.lat, posicao.lng);
  }

  /// Posição nova: a rota confere se saiu do traçado e o estado da
  /// entrega é consultado na hora, para o botão de finalizar aparecer
  /// assim que o entregador chega — sem esperar o próximo polling.
  void _aoMudarPosicao() {
    final posicao = _presenca.posicaoAtual;
    if (posicao == null || identical(posicao, _ultimaPosicaoTratada)) return;
    _ultimaPosicaoTratada = posicao;
    _rota.acompanhar(PontoGeo(posicao.lat, posicao.lng));
    // Dá tempo do `PUT /me/location` chegar antes de reler o geofence.
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) _entrega.atualizarAgora();
    });
  }

  void _moverFolha(double tamanho) {
    if (!_folha.isAttached) return;
    _folha.animateTo(
      tamanho,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  /// Reage a mudanças de estado vindas do polling, depois do quadro.
  void _reagirAoEstado(EstadoEntrega entrega) {
    final status = entrega.status;
    final anterior = _ultimoStatus;
    _ultimoStatus = status;

    // Coleta confirmada: a rota agora deve ir direto ao destino, sem
    // passar de novo pelo estabelecimento.
    if (anterior == 'accepted' && status == 'picked_up') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rota.recarregar(origem: _pontoAtual());
      });
    }

    // Chegou ao destino: a folha sobe sozinha com o código à vista.
    if (entrega.podeFinalizar && !_jaAbriuAoChegar) {
      _jaAbriuAoChegar = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _moverFolha(.62);
        mostrarAviso(
          context,
          feiraNestaBranch
              ? 'Você chegou ao ponto. Finalize para receber o prêmio.'
              : 'Você chegou. Peça o código ao destinatário.',
        );
      });
    }
  }

  /// A-15 — só existe durante a fase de retirada.
  ControladorRetirada? _retirada;

  ControladorRetirada? _sincronizarRetirada(bool emRetirada) {
    if (emRetirada && _retirada == null) {
      _retirada = ControladorRetirada(
        context.read<RepositorioPedidos>(),
        pedidoId: widget.pedidoId,
      )..addListener(_avisarRetirada);
      _retirada!.abrir();
    } else if (!emRetirada && _retirada != null) {
      // Coleta confirmada: a fase acabou. Descarta depois do quadro,
      // nunca durante o build.
      final antigo = _retirada!;
      _retirada = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        antigo.removeListener(_avisarRetirada);
        antigo.dispose();
      });
    }
    return _retirada;
  }

  void _avisarRetirada() {
    final retirada = _retirada;
    if (retirada == null || !mounted) return;
    final erro = retirada.erro;
    final aviso = retirada.aviso;
    if (erro == null && aviso == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      mostrarAviso(context, erro ?? aviso!, erro: erro != null);
      retirada.limparMensagens();
    });
  }

  /// RF-A15.8 a RF-A15.12 e RF-A15.15 — ir à loja, esperar a
  /// confirmação, pedir reaviso ou desistir.
  Widget _buildRetirada(BuildContext context, ControladorRetirada retirada) {
    return ListenableBuilder(
      listenable: retirada,
      builder: (context, _) {
        final pedido = retirada.pedido;
        if (pedido == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: corPrincipal),
            ),
          );
        }
        final chegou = pedido.chegouEm != null;
        final esperaMin = chegou
            ? DateTime.now().difference(pedido.chegouEm!).inMinutes
            : 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: chegou
                    ? context.cores.coleta.withValues(alpha: .14)
                    : context.cores.superficieSuave,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: chegou ? context.cores.coleta : context.cores.borda,
                ),
              ),
              child: Row(
                children: [
                  AvatarRede(
                    url: pedido.logoEstabelecimento,
                    icone: chegou ? Icons.storefront : Icons.two_wheeler,
                    raio: 24,
                    corFundo: chegou ? Colors.teal : context.cores.textoSuave,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      chegou
                          ? 'Aguardando o estabelecimento confirmar a coleta'
                                '${esperaMin > 0 ? ' — há $esperaMin min' : ''}.'
                          : 'Vá até ${pedido.nomeEstabelecimento ?? 'o estabelecimento'} '
                                'para retirar o pedido ${pedido.rotuloCurto}.',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (retirada.podeRegistrarChegada) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: retirada.enviando ? null : retirada.registrarChegada,
                icon: const Icon(Icons.where_to_vote),
                label: const Text('Cheguei ao estabelecimento'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (retirada.reavisoLiberado) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: retirada.enviando ? null : retirada.pedirNovoAviso,
                icon: const Icon(Icons.notifications_active),
                label: const Text('Avisar o estabelecimento de novo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.cores.coleta,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
            if (retirada.podeDesistir) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: retirada.enviando
                    ? null
                    : () => _desistir(context, retirada),
                icon: Icon(Icons.close, color: context.cores.perigo),
                label: Text(
                  'Desistir da entrega',
                  style: TextStyle(color: context.cores.perigo),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// RF-A15.15 — avisa antes o que a desistência custa ao entregador.
  Future<void> _desistir(
    BuildContext context,
    ControladorRetirada retirada,
  ) async {
    final chegou = retirada.pedido?.chegouEm != null;
    final escolha = await escolherMotivo<MotivoDesistencia>(
      context,
      titulo: 'Desistir da entrega',
      opcoes: feiraNestaBranch
          ? MotivoDesistencia.paraFeira
          : MotivoDesistencia.values,
      rotulo: (m) => m.rotulo,
      exigeObservacao: (m) => m.exigeObservacao,
      textoConfirmar: 'Desistir',
      aviso: feiraNestaBranch
          ? 'O prêmio volta para a mesa e o pedido pode ser pego de novo, '
                'inclusive por você. Desistir não tira pontos.'
          : chegou
          ? 'A desistência conta no seu score em dobro, porque você já está '
                'no estabelecimento, e no limite de 3 por dia. Se o '
                'estabelecimento está demorando mais de 15 minutos, escolha '
                '"Estabelecimento demorando": aí não há penalidade.'
          : 'A desistência conta no seu score e no limite de 3 por dia. O '
                'pedido volta a ser oferecido a outros entregadores.',
    );
    if (escolha == null || !mounted) return;
    final ok = await retirada.desistir(
      escolha.motivo,
      observacao: escolha.observacao,
    );
    if (ok && mounted) {
      mostrarAviso(this.context, 'Você desistiu da entrega.');
      Navigator.pushReplacementNamed(this.context, '/entregas_entregador');
    }
  }

  /// RF-A15.11 — cancelamento recebido: a navegação para, a entrega sai
  /// do andamento. A taxa, quando houver, aparece em Ganhos.
  Widget _buildCancelada(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel, size: 72, color: context.cores.perigo),
            const SizedBox(height: 16),
            const Text(
              'O estabelecimento cancelou este pedido.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Se você já estava no estabelecimento, a taxa de cancelamento '
              'aparece nos seus ganhos.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: corPrincipal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  '/entregas_entregador',
                ),
                child: const Text(
                  'Voltar às entregas',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Guarda de repetição: `build` roda a cada tique do polling (10s), e
  /// sem isto o mesmo erro reapareceria de dez em dez segundos.
  String? _erroJaAvisado;

  @override
  Widget build(BuildContext context) {
    final controlador = context.watch<ControladorEntrega>();
    _avisarErro(controlador);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
        title: const Text('Entrega em andamento'),
      ),
      body: SafeArea(
        child: controlador.estado.quando(
          carregando: () => const Center(
            child: CircularProgressIndicator(color: corPrincipal),
          ),
          pronto: (entrega) => _buildConteudo(context, controlador, entrega),
          vazio: () => const Center(child: Text('Entrega não encontrada.')),
          falhou: (erro) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 48, color: context.cores.perigo),
                  const SizedBox(height: 16),
                  Text(erro.mensagemParaUsuario, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => controlador.abrir(widget.pedidoId),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConteudo(
    BuildContext context,
    ControladorEntrega controlador,
    EstadoEntrega entrega,
  ) {
    if (entrega.finalizada) return _buildFinalizada(context);
    if (entrega.status == 'cancelled') return _buildCancelada(context);

    // RF-A15.8 — a fase vem do status do pedido, nunca da sequência de
    // telas: `accepted` é retirada, `picked_up` é entrega.
    final emRetirada = entrega.status == 'accepted';
    final retirada = _sincronizarRetirada(emRetirada);
    _reagirAoEstado(entrega);

    // O código fica visível quando o servidor libera a finalização — e
    // continua visível se o entregador já começou a digitar, mesmo que
    // um ciclo de polling com GPS impreciso tire o link por 10s. Antes o
    // campo sumia no meio da digitação. Quem valida a posição continua
    // sendo o servidor, com a leitura enviada junto do código.
    final mostrarCodigo =
        entrega.podeFinalizar ||
        (entrega.status == 'picked_up' &&
            !entrega.contestavelDisponivel &&
            (_codigoController.text.isNotEmpty || _focoCodigo.hasFocus));

    final rota = context.watch<ControladorRota>().rota;
    final posicao = context.watch<ControladorPresenca>().posicaoAtual;
    final ponto = posicao == null ? null : PontoGeo(posicao.lat, posicao.lng);

    // RF-A14.1 — o mapa é a tela, e o resto flutua por cima numa folha
    // arrastável: rodando, o que importa é o caminho (com a manobra no
    // alto, como na navegação); chegando, a folha sobe com o código.
    return Stack(
      children: [
        Positioned.fill(child: _buildRota(context)),
        if (rota != null && rota.temTracado)
          Positioned(
            top: 12,
            left: 12,
            // Deixa livre a coluna de botões do mapa, à direita.
            right: 68,
            child: CartaoDaManobra(trajeto: rota.trajeto, posicao: ponto),
          ),
        DraggableScrollableSheet(
          controller: _folha,
          initialChildSize: _folhaInicial,
          minChildSize: _folhaMinima,
          maxChildSize: _folhaMaxima,
          builder: (contexto, rolagem) => Container(
            decoration: BoxDecoration(
              color: context.cores.superficie,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: context.cores.sombra,
                  blurRadius: 12,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: ListView(
              controller: rolagem,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: context.cores.borda,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                // Modo feira: as duas etapas ficam no topo da folha o tempo
                // todo, marcando em qual você está. É o que substitui a rota
                // dizendo "primeiro a loja, depois o destino".
                if (feiraNestaBranch) ...[
                  _buildEtapasFeira(context, retirada == null),
                  const SizedBox(height: 16),
                ],
                if (retirada != null) ...[
                  if (!feiraNestaBranch) ...[
                    _buildResumoDaNavegacao(context, ponto),
                    const SizedBox(height: 16),
                  ],
                  _buildRetirada(context, retirada),
                ] else ...[
                  // Chegou: finalizar vem antes de tudo, sem precisar
                  // rolar a folha.
                  if (feiraNestaBranch) ...[
                    _buildCartaoFeira(context, entrega),
                    const SizedBox(height: 16),
                  ] else if (mostrarCodigo) ...[
                    _buildCartaoCodigo(context, controlador, entrega),
                    const SizedBox(height: 16),
                  ],
                  _buildGeofence(entrega),
                  const SizedBox(height: 16),
                  _buildResumoDaNavegacao(context, ponto),
                ],
                if (entrega.contestavelDisponivel) ...[
                  const SizedBox(height: 20),
                  _buildCartaoContestavel(context, controlador),
                ],
                if (entrega.podeAcionarContingencia &&
                    !entrega.contestavelDisponivel) ...[
                  const SizedBox(height: 20),
                  _buildCartaoContingencia(context, controlador, entrega),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// O que antes exigia abrir a tela de navegação à parte: quanto falta,
  /// recalcular a partir do GPS, a lista de instruções e o modo seguir.
  /// Tudo na mesma tela onde se finaliza — RNF-A14.2: alvos grandes.
  Widget _buildResumoDaNavegacao(BuildContext context, PontoGeo? posicao) {
    final controladorRota = context.watch<ControladorRota>();
    final rota = controladorRota.rota;
    if (rota == null || !rota.temTracado) return const SizedBox.shrink();

    final trajeto = rota.trajeto;
    final restante = trajeto.metrosRestantes(posicao);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restante != null
                        ? 'Faltam ${formatarDistancia(restante)}'
                        : '${trajeto.distanciaPorViaKm?.toStringAsFixed(1) ?? '–'} km pelas ruas',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    [
                      if (trajeto.duracaoMinutos != null)
                        '${trajeto.duracaoMinutos} min',
                      trajeto.passaPelaRetirada
                          ? 'passando pelo estabelecimento'
                          : 'direto ao destino',
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.cores.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Recalcular a partir daqui',
              onPressed: controladorRota.buscando
                  ? null
                  : () => controladorRota.recarregar(origem: posicao),
              icon: controladorRota.buscando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
            if (trajeto.passos.length > 1)
              IconButton(
                tooltip: 'Ver todas as instruções',
                onPressed: () => mostrarPassosDaRota(context, trajeto),
                icon: const Icon(Icons.list),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () {
            FocusScope.of(context).unfocus();
            setState(() => _pedidosDeSeguir++);
            _moverFolha(_folhaMinima);
          },
          icon: const Icon(Icons.navigation),
          label: const Text('Navegar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: corPrincipal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinalizada(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 72, color: corSucesso),
            const SizedBox(height: 16),
            const Text(
              'Entrega finalizada!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: corPrincipal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  '/entregas_entregador',
                ),
                child: const Text(
                  'Voltar às entregas',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// RF-A14.1 — o caminho ocupa a tela inteira, atrás da folha.
  ///
  /// **RF-A14.6**: sem rota (provedor fora do ar, loja sem ponto no
  /// mapa) isto vira um fundo neutro com o motivo escrito — e a folha
  /// por cima continua inteira, com geofence, código e finalização
  /// funcionando. Nada aqui bloqueia entregar.
  Widget _buildRota(BuildContext context) {
    final posicao = context.watch<ControladorPresenca>().posicaoAtual;
    final rota = context.watch<ControladorRota>().rota;

    // Modo feira (docs/feira/): não existe trajeto calculado, e cair no ramo
    // de baixo deixava "Carregando o trajeto…" na tela para sempre. Aqui o
    // mapa mostra o que de fato importa num salão: você, o estande e o ponto.
    if (feiraNestaBranch) return _buildMapaFeira(context);

    if (rota == null || !rota.temTracado) {
      return Container(
        color: context.cores.superficieSuave,
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
        child: Row(
          children: [
            Icon(Icons.map_outlined, color: context.cores.textoSuave),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                rota?.trajeto.explicacao ?? 'Carregando o trajeto…',
                style: TextStyle(fontSize: 13, color: context.cores.textoSuave),
              ),
            ),
          ],
        ),
      );
    }

    return MapaRota(
      rota: rota,
      posicaoAtual: posicao == null ? null : LatLng(posicao.lat, posicao.lng),
      preencher: true,
      seguirDesdeOInicio: true,
      mostrarLegenda: false,
      pedidosDeSeguir: _pedidosDeSeguir,
    );
  }

  /// RF-A08.3 — a distância é só orientação; a autoridade é a resposta
  /// da API em `completion`, nunca este cálculo.
  Widget _buildGeofence(EstadoEntrega entrega) {
    final geofence = entrega.geofence;
    final dentro = geofence.dentro;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dentro
            ? corSucesso.withValues(alpha: .12)
            : context.cores.superficieSuave,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dentro ? corSucesso : context.cores.borda),
      ),
      child: Row(
        children: [
          Icon(
            dentro ? Icons.location_on : Icons.location_searching,
            color: dentro ? corSucesso : context.cores.textoSuave,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              dentro
                  ? 'Você está no local de entrega.'
                  : geofence.distanciaMetros != null
                  ? 'Aproxime-se para finalizar — faltam ${geofence.distanciaMetros}m.'
                  : 'Aproxime-se do local de entrega.',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Modo feira (docs/feira/): o mapa do salão, sem trajeto.
  ///
  /// Duas pernas, e a tela diz em qual você está: primeiro o estande do UaiOu
  /// para retirar, depois o ponto de entrega. O pino da etapa atual é o
  /// colorido; o da outra fica apagado, para não haver dúvida de para onde ir
  /// agora — era exatamente isso que o traçado dizia no produto.
  Widget _buildMapaFeira(BuildContext context) {
    final posicao = context.watch<ControladorPresenca>().posicaoAtual;
    final rota = _rotaDoSalao();

    if (rota == null) {
      // Só enquanto o pedido não chegou do servidor. Não é o estado "sem
      // trajeto" do produto, que ficava preso em "Carregando o trajeto…".
      return Container(color: context.cores.superficieSuave);
    }

    return MapaRota(
      rota: rota,
      posicaoAtual: posicao == null ? null : LatLng(posicao.lat, posicao.lng),
      preencher: true,
      seguirDesdeOInicio: true,
      mostrarLegenda: false,
      pedidosDeSeguir: _pedidosDeSeguir,
      mostrarTracado: false,
    );
  }

  /// Modo feira (docs/feira/): o trajeto montado aqui, sem provedor de rota.
  ///
  /// O mapa 3D de navegação continua sendo o do produto — é ele que segue o
  /// entregador, gira com o rumo e mostra a posição ao vivo, e é o que dá a
  /// cara de app de entrega. O que sai é só a CONSULTA ao provedor: num salão,
  /// o caminho por ruas não existe, então a geometria é a reta das duas
  /// pernas (estande → ponto), que a poucos metros é o próprio caminho.
  ///
  /// A posição ao vivo NÃO entra na geometria de propósito: ela muda a cada
  /// leitura de GPS, e o mapa redesenha o traçado sempre que a rota troca de
  /// identidade — o caminho ficaria piscando. Quem anda no mapa é o ponteiro,
  /// alimentado por `posicaoAtual`; o traçado é o par de pontos fixos.
  RotaDoPedido? _rotaDoSalao() {
    final pedido = _pedidoFeira;
    if (pedido == null) return null;

    final estande = pedido.estabelecimentoLat != null
        ? PontoGeo(pedido.estabelecimentoLat!, pedido.estabelecimentoLong!)
        : null;
    final ponto = pedido.latitude != null
        ? PontoGeo(pedido.latitude!, pedido.longitude!)
        : null;
    if (ponto == null || estande == null) return null;

    return RotaDoPedido(
      orderId: widget.pedidoId,
      trajeto: Trajeto(
        disponivel: true,
        passaPelaRetirada: true,
        geometria: [estande, ponto],
      ),
    );
  }

  /// A instrução em palavras, no topo da folha: qual é a etapa agora. Sem isto
  /// alguém que pega o pedido vai direto ao ponto e trava lá — no produto quem
  /// dizia "passe na loja primeiro" era o traçado da rota.
  Widget _buildEtapasFeira(BuildContext context, bool coletado) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cores.superficieSuave,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _buildEtapa(
            context,
            numero: '1',
            titulo: 'Passe no estande do UaiOu',
            local: _descricaoEstande,
            detalhe: 'O operador confirma a retirada e libera sua entrega.',
            ativa: !coletado,
            concluida: coletado,
            icone: Icons.storefront,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(
              Icons.keyboard_arrow_down,
              color: context.cores.textoSuave,
            ),
          ),
          _buildEtapa(
            context,
            numero: '2',
            titulo: 'Leve até o ponto de entrega',
            local: _pedidoFeira?.bairro,
            detalhe: 'Chegando lá, finalize para receber o prêmio.',
            ativa: coletado,
            concluida: false,
            icone: Icons.card_giftcard,
          ),
        ],
      ),
    );
  }

  Widget _buildEtapa(
    BuildContext context, {
    required String numero,
    required String titulo,
    String? local,
    required String detalhe,
    required bool ativa,
    required bool concluida,
    required IconData icone,
  }) {
    final cor = concluida
        ? context.cores.positivo
        : ativa
        ? corPrincipal
        : context.cores.textoSuave;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: cor.withValues(alpha: ativa || concluida ? 1 : .35),
          child: Icon(
            concluida ? Icons.check : icone,
            size: 17,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$numero. $titulo',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: ativa ? FontWeight.bold : FontWeight.w500,
                  color: ativa ? context.cores.texto : context.cores.textoSuave,
                ),
              ),
              if (local != null && local.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.place, size: 15, color: cor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          local,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: ativa
                                ? context.cores.texto
                                : context.cores.textoSuave,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                detalhe,
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.cores.textoSuave,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Modo feira (docs/feira/01-fluxos.md): finaliza sem código.
  ///
  /// No produto quem prova a entrega é o destinatário, ditando o OTP. Num
  /// salão não há ninguém esperando no ponto, então a prova é o código fixo
  /// que o operador deixou escrito lá, junto com o raio — o servidor confere
  /// os dois. O botão fica habilitado mesmo fora do raio: GPS dentro de
  /// pavilhão erra, e "chegue mais perto" é melhor que um botão morto.
  Widget _buildCartaoFeira(BuildContext context, EstadoEntrega entrega) {
    final feira = context.watch<ControladorFeira>();
    final dentro = entrega.geofence.dentro;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cores.superficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cores.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            dentro
                ? 'Você chegou ao ponto. Digite o código escrito lá.'
                : 'No ponto marcado há um código. Digite-o para finalizar.',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          // O código fixo do pedido, deixado pelo operador no ponto: é a
          // prova de que o jogador chegou, no lugar do OTP do destinatário.
          TextField(
            controller: _codigoController,
            focusNode: _focoCodigo,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: const InputDecoration(
              hintText: 'Código',
              counterText: '',
            ),
            onSubmitted: (_) => _finalizarNaFeira(),
          ),
          if (feira.erro != null) ...[
            const SizedBox(height: 10),
            Text(
              feira.erro!,
              style: TextStyle(color: context.cores.perigo, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: feira.carregando ? null : _finalizarNaFeira,
              style: ElevatedButton.styleFrom(
                backgroundColor: corPrincipal,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.card_giftcard),
              label: Text(
                feira.carregando ? 'Finalizando…' : 'Finalizar entrega',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finalizarNaFeira() async {
    final feira = context.read<ControladorFeira>();
    final captura = await feira.finalizarEntrega(
      widget.pedidoId,
      codigo: _codigoController.text.trim(),
    );
    if (!mounted || captura == null) return;

    feira.comprovanteExibido();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (contexto) => AlertDialog(
        icon: const Icon(Icons.celebration, size: 40),
        title: const Text('Entrega concluída!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              captura.recompensa,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Mostre esta tela no estande do UaiOu para retirar.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/principal_entregador');
  }

  /// RF-A08.4 — finaliza por código. Só aparece quando o servidor
  /// oferece `completion` (dentro do geofence).
  Widget _buildCartaoCodigo(
    BuildContext context,
    ControladorEntrega controlador,
    EstadoEntrega entrega,
  ) {
    final tentativas = entrega.codigo.tentativasRestantes;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cores.superficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cores.textoSuave),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Código do destinatário',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (tentativas != null) ...[
            const SizedBox(height: 4),
            Text(
              '$tentativas tentativa(s) restante(s)',
              style: TextStyle(fontSize: 13, color: context.cores.textoSuave),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _codigoController,
            focusNode: _focoCodigo,
            // Rebuild a cada dígito mantém o cartão visível enquanto há
            // texto (ver `mostrarCodigo`).
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _finalizarPorCodigo(
              context,
              controlador,
              entrega.codigo.tamanho,
            ),
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.number,
            // RF-A08.4 — o tamanho é do servidor (`deliveryCode.length`); fixá-lo aqui foi o que
            // impediu o entregador de digitar o código real.
            maxLength: entrega.codigo.tamanho,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, letterSpacing: 8),
            decoration: InputDecoration(
              counterText: '',
              border: const OutlineInputBorder(),
              hintText: '0' * entrega.codigo.tamanho,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: corSucesso,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: controlador.enviando
                  ? null
                  : () => _finalizarPorCodigo(
                      context,
                      controlador,
                      entrega.codigo.tamanho,
                    ),
              child: controlador.enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Finalizar entrega'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: controlador.solicitandoRecuperacao
                  ? null
                  : () => controlador.acionarContingencia(),
              child: const Text('Não recebi o código'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finalizarPorCodigo(
    BuildContext context,
    ControladorEntrega controlador,
    int tamanho,
  ) async {
    final codigo = _codigoController.text.trim();
    if (codigo.length != tamanho) {
      mostrarAviso(
        context,
        'Informe os $tamanho dígitos do código.',
        erro: true,
      );
      return;
    }
    if (controlador.enviando) return;
    FocusScope.of(context).unfocus();
    await controlador.finalizarComCodigo(
      codigo,
      posicaoConhecida: _presenca.posicaoAtual,
    );
  }

  /// RF-A08.5 — degrau atual da escada de contingência.
  Widget _buildCartaoContingencia(
    BuildContext context,
    ControladorEntrega controlador,
    EstadoEntrega entrega,
  ) {
    final contingencia = entrega.contingencia;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cores.atencao.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cores.atencao),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent, color: context.cores.atencao),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Aguardando o repasse do código',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (contingencia.degrau != null)
            Text('Degrau atual: ${contingencia.degrau}'),
          if (contingencia.prazoDoEstabelecimento != null)
            Text(
              'Prazo até '
              '${_formatarHora(contingencia.prazoDoEstabelecimento!)}',
            ),
          const SizedBox(height: 10),
          Text(
            'O aplicativo atualiza sozinho assim que houver novidade — '
            'não é preciso ficar tentando o código.',
            style: TextStyle(fontSize: 13, color: context.cores.texto),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: controlador.solicitandoRecuperacao
                  ? null
                  : () => controlador.acionarContingencia(),
              child: const Text('Verificar novamente'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatarHora(DateTime dt) => formatarHora(dt);

  /// RF-A08.6/RF-A08.7 — só aparece quando `contestableReleased` vem
  /// `true`. Exige foto confirmada antes de oferecer o botão final.
  Widget _buildCartaoContestavel(
    BuildContext context,
    ControladorEntrega controlador,
  ) {
    final temFoto = controlador.uploadIdConfirmado != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cores.superficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: corPrincipal, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Finalização por foto',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'O código não chegou ao destinatário a tempo. Tire uma foto '
            'do local de entrega para comprovar.',
            style: TextStyle(fontSize: 13, color: context.cores.textoSuave),
          ),
          const SizedBox(height: 14),
          if (controlador.enviandoFoto)
            Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    value: controlador.progressoFoto,
                    color: corPrincipal,
                  ),
                  const SizedBox(height: 8),
                  const Text('Enviando foto...'),
                ],
              ),
            )
          else if (temFoto)
            Row(
              children: [
                const Icon(Icons.check_circle, color: corSucesso),
                const SizedBox(width: 8),
                const Expanded(child: Text('Foto enviada.')),
                TextButton(
                  onPressed: controlador.descartarFoto,
                  child: const Text('Trocar'),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    controlador.capturarEEnviarFoto(OrigemDaImagem.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Tirar foto'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: corPrincipal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: corSucesso,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // RF-A08.6 — sem foto, sem botão utilizável.
              onPressed: (!temFoto || controlador.enviando)
                  ? null
                  : () => controlador.finalizarContestavel(
                      posicaoConhecida: _presenca.posicaoAtual,
                    ),
              child: controlador.enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Finalizar com foto'),
            ),
          ),
        ],
      ),
    );
  }

  /// O erro da finalização (código errado, falha de rede) sobe como
  /// aviso no alto à esquerda, e não mais como cartão no fim da folha:
  /// lá embaixo ele disputava espaço com o botão de finalizar e ficava
  /// fora de vista quando a folha estava recolhida.
  void _avisarErro(ControladorEntrega controlador) {
    final erro = controlador.erro;
    if (erro == null) {
      // Erro consumido: o próximo, mesmo com o mesmo texto (código errado
      // duas vezes), precisa aparecer. Antes ele era engolido e o
      // entregador achava que o botão não fazia nada.
      _erroJaAvisado = null;
      return;
    }
    if (erro == _erroJaAvisado) return;
    _erroJaAvisado = erro;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      mostrarAviso(context, erro, erro: true);
      controlador.limparErro();
    });
  }
}
