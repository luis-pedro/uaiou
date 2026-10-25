import 'dart:async';

import 'package:flutter/material.dart';

import 'package:uaiou/screens/widgets/dialogo_padrao.dart';
import 'package:uaiou/core/tema/cores.dart';
import 'package:uaiou/screens/casca_principal.dart';
import 'package:uaiou/screens/widgets/ui.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/notificacoes/controlador_notificacoes.dart';
import 'package:uaiou/core/pedidos/repositorio_pedidos.dart';
import 'package:uaiou/core/perfil/controlador_perfil.dart';
import 'package:uaiou/core/rede/erros_api.dart';
import 'package:uaiou/screens/tela_detalhe_pedido.dart';
import 'package:uaiou/screens/widgets/avatar_rede.dart';
import 'package:uaiou/screens/widgets/aviso_flutuante.dart';
import 'package:uaiou/others/estabelecimento_service.dart';
import 'package:uaiou/screens/tela_publicar_pedido.dart';

class TelaPrincipalEstabelecimento extends StatefulWidget {
  const TelaPrincipalEstabelecimento({super.key});

  @override
  State<TelaPrincipalEstabelecimento> createState() =>
      _TelaPrincipalEstabelecimentoState();
}

class _TelaPrincipalEstabelecimentoState
    extends State<TelaPrincipalEstabelecimento> {
  // Cor principal do app (laranja)
  static const Color corPrincipal = CoresUaiou.principal;

  /// RF-A15.1 — sem push nativo (ver `ControladorNotificacoes`), o
  /// aviso de chegada vem da inbox consultada periodicamente.
  static const Duration _intervaloAvisos = Duration(seconds: 15);

  Timer? _timerAvisos;
  ControladorNotificacoes? _notificacoes;

  /// Avisos de chegada já exibidos nesta sessão da tela — o mesmo aviso
  /// não reabre a cada consulta.
  final Set<String> _avisosDeChegadaExibidos = {};
  bool _dialogoAberto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Carrega `GET /me` para exibir o endereço de retirada real —
      // RF-A10.2: a origem do pedido é sempre o endereço do próprio
      // estabelecimento, não há campo de origem no contrato.
      context.read<ControladorPerfil>().carregar();
      // Contagem de "em andamento" do painel.
      context.read<EstadoEstabelecimento>().carregar();
      // RF-A11.7 — contador de não lidas no menu.
      _notificacoes = context.read<ControladorNotificacoes>()
        ..addListener(_verificarChegadas)
        ..carregar();
      _timerAvisos = Timer.periodic(
        _intervaloAvisos,
        (_) => _notificacoes?.recarregar(),
      );
    });
  }

  @override
  void dispose() {
    _timerAvisos?.cancel();
    _notificacoes?.removeListener(_verificarChegadas);
    super.dispose();
  }

  /// RF-A15.1/RF-A15.3 — um aviso por pedido, com identificação do
  /// entregador e a confirmação ali mesmo. Vários na fila abrem um de
  /// cada vez.
  void _verificarChegadas() {
    if (!mounted || _dialogoAberto) return;
    final pendente = _notificacoes?.notificacoes
        .where(
          (n) =>
              n.type == 'order.courier_arrived' &&
              !n.lida &&
              !_avisosDeChegadaExibidos.contains(n.id),
        )
        .firstOrNull;
    if (pendente == null) return;

    _avisosDeChegadaExibidos.add(pendente.id);
    final pedidoId = pendente.payload['orderId']?.toString();
    if (pedidoId == null) return;

    _dialogoAberto = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final acao = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (contexto) => DialogoPadrao(
          // RF-26.6 — a foto é o que separa um entregador do outro na porta.
          cabecalho: AvatarRede(
            url: pendente.payload['courierPhotoUrl']?.toString(),
            icone: Icons.delivery_dining,
            raio: 44,
            corFundo: CoresUaiou.principal,
          ),
          titulo: pendente.title,
          conteudo: Text(pendente.body, textAlign: TextAlign.center),
          rotuloCancelar: 'Depois',
          aoCancelar: () => Navigator.pop(contexto, 'depois'),
          acoesExtras: [
            TextButton(
              onPressed: () => Navigator.pop(contexto, 'ver'),
              child: const Text('Ver pedido'),
            ),
          ],
          rotuloConfirmar: 'Confirmar coleta',
          aoConfirmar: () => Navigator.pop(contexto, 'confirmar'),
        ),
      );
      _dialogoAberto = false;
      if (!mounted) return;

      unawaited(_notificacoes?.marcarLida(pendente.id));
      switch (acao) {
        case 'confirmar':
          await _confirmarColeta(pedidoId);
        case 'ver':
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TelaDetalhePedido(pedidoId: pedidoId),
            ),
          );
      }
      // Outro entregador pode ter chegado enquanto este aviso estava aberto.
      _verificarChegadas();
    });
  }

  Future<void> _confirmarColeta(String pedidoId) async {
    try {
      await context.read<RepositorioPedidos>().confirmarColeta(pedidoId);
      if (mounted) mostrarAviso(context, 'Coleta confirmada.');
    } on ErroApi catch (erro) {
      // RF-A15.7 — corrida perdida ou entregador fora do raio: a
      // mensagem do servidor explica.
      if (mounted) mostrarAviso(context, erro.mensagemParaUsuario, erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoEstabelecimento>();
    final nome = estado.nome;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: corPrincipal,
          onRefresh: estado.carregar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _saudacao(),
                          style: TextStyle(
                            fontSize: 14,
                            color: context.cores.textoSuave,
                          ),
                        ),
                        Text(
                          nome.isEmpty ? 'Olá!' : nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: context.cores.texto,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildAvisos(),
                ],
              ),
              const SizedBox(height: 20),
              _buildBotaoPedirEntregador(),
              const SizedBox(height: 20),
              const TituloSecao('Agora'),
              _buildResumoAndamento(estado),
            ],
          ),
        ),
      ),
    );
  }

  String _saudacao() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Bom dia';
    if (hora < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  /// Atalho para a aba Pedidos com a contagem do que está rodando agora.
  Widget _buildResumoAndamento(EstadoEstabelecimento estado) {
    final ativos = estado.pedidos.itens
        .where((pedido) => !pedido.status.encerrado)
        .length;
    return Cartao(
      aoTocar: () => CascaPrincipal.irPara(context, 1),
      filho: Row(
        children: [
          IconeTingido(
            Icons.local_shipping_outlined,
            cor: context.cores.informacao,
            tamanho: 44,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ativos == 0
                      ? 'Nenhuma entrega em andamento'
                      : ativos == 1
                      ? '1 entrega em andamento'
                      : '$ativos entregas em andamento',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.cores.texto,
                  ),
                ),
                Text(
                  'Acompanhe em Pedidos',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.cores.textoSuave,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.cores.textoSuave),
        ],
      ),
    );
  }

  /// O mapa mostrava sempre o centro de Santa Rita do Sapucaí, sem marcador
  /// nenhum — bonito e inútil. Agora mostra o ponto de retirada do próprio
  /// estabelecimento, que é de onde o entregador vai sair com o pacote.
  ///
  /// Enquanto o perfil não carrega (ou se a loja nunca marcou o ponto), fica no
  /// centro padrão da praça, sem pino: sem coordenada não há o que apontar.

  // CAMPO LOCALIZAÇÃO — informativo, lê `GET /me` (A-05). Não é
  // enviado ao servidor: `POST /orders` não tem campo de origem
  // (RF-A10.2), a retirada é sempre o endereço do próprio
  // estabelecimento.

  String _enderecoDeRetirada(BuildContext context) {
    final perfil = context.watch<ControladorPerfil>().estado.valorOuNulo;
    final endereco = perfil?.detalhes?.endereco;
    if (endereco == null || endereco.estaVazio) {
      return 'Endereço de retirada: cadastre no seu perfil.';
    }
    final partes = <String>[
      if (endereco.rua != null && endereco.rua!.isNotEmpty)
        [endereco.rua, endereco.numero].whereType<String>().join(', '),
      if (endereco.bairro != null && endereco.bairro!.isNotEmpty)
        endereco.bairro!,
    ];
    return partes.isEmpty
        ? 'Endereço de retirada: cadastre no seu perfil.'
        : partes.join(' — ');
  }

  /// RF-A11.7 — avisos no canto superior direito, em vez de item da
  /// barra inferior: os quatro itens que sobraram lá são **lugares onde
  /// se fica** (principal, pedidos, atividades, perfil), e avisos é uma
  /// consulta rápida da qual se volta. Mesmo tratamento já dado à tela
  /// do entregador. O contador continua vindo de `meta.unread` do
  /// servidor, nunca somado aqui.
  Widget _buildAvisos() =>
      BotaoAvisos(naoLidas: context.watch<ControladorNotificacoes>().naoLidas);

  // BOTÃO "PEDIR UM ENTREGADOR"
  /// "Criar entrega" como um despacho guiado (Lazyweb, hipótese
  /// "Despacho Guiado"): a retirada já vem preenchida do perfil e o
  /// próximo passo — o destino — fica escrito na tela, em vez de um "+"
  /// que o lojista precisava adivinhar.
  Widget _buildBotaoPedirEntregador() {
    final cores = context.cores;
    return Container(
      decoration: BoxDecoration(
        color: cores.superficie,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cores.borda),
        boxShadow: [
          BoxShadow(
            color: cores.sombra,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Criar entrega',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: cores.texto,
            ),
          ),
          const SizedBox(height: 14),
          _buildPassoComposer(
            numero: 1,
            titulo: 'Retirada',
            detalhe: _enderecoDeRetirada(context),
            acao: 'Alterar',
            aoTocar: () => Navigator.pushNamed(context, '/editar_perfil'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 2,
              height: 16,
              margin: const EdgeInsets.only(left: 15),
              color: cores.borda,
            ),
          ),
          _buildPassoComposer(
            numero: 2,
            titulo: 'Destino',
            detalhe: 'Endereço do cliente e valor do frete',
            aoTocar: _abrirFormularioPedido,
            ativo: true,
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _abrirFormularioPedido,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            icon: const Icon(Icons.two_wheeler_rounded),
            label: const Text('Chamar entregador'),
          ),
        ],
      ),
    );
  }

  Widget _buildPassoComposer({
    required int numero,
    required String titulo,
    required String detalhe,
    required VoidCallback aoTocar,
    String? acao,
    bool ativo = false,
  }) {
    final cores = context.cores;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ativo
                    ? corPrincipal
                    : corPrincipal.withValues(alpha: .12),
              ),
              child: Text(
                '$numero',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: ativo ? Colors.white : corPrincipal,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: cores.texto,
                    ),
                  ),
                  Text(
                    detalhe,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: cores.textoSuave),
                  ),
                ],
              ),
            ),
            if (acao != null)
              OutlinedButton(
                onPressed: aoTocar,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  foregroundColor: corPrincipal,
                  side: const BorderSide(color: corPrincipal),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(acao),
              )
            else
              Icon(Icons.chevron_right_rounded, color: cores.textoSuave),
          ],
        ),
      ),
    );
  }

  // RF-A10.1 — `POST /orders` real, na tela dedicada.
  Future<void> _abrirFormularioPedido() async {
    final publicado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TelaPublicarPedido()),
    );

    if (publicado == true && mounted) {
      // RF-A10.5 — a lista de pedidos passa a refletir o novo pedido
      // na próxima visita à tela de pedidos.
      unawaited(context.read<EstadoEstabelecimento>().carregar());
      mostrarAviso(context, 'Pedido publicado.');
    }
  }
}
