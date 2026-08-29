import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/entregas/controlador_entrega.dart';
import 'package:uaiou/core/entregas/modelo_entrega.dart';
import 'package:uaiou/core/presenca/controlador_presenca.dart';
import 'package:uaiou/core/rotas/controlador_rota.dart';
import 'package:uaiou/core/uploads/seletor_de_imagem.dart';
import 'package:uaiou/screens/tela_navegacao.dart';
import 'package:uaiou/screens/widgets/aviso_flutuante.dart';
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
  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);
  static const Color corSucesso = Color.fromRGBO(108, 201, 80, 1);

  final TextEditingController _codigoController = TextEditingController();
  bool _pediuAbertura = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RNF-A08.2 — sempre busca do servidor ao entrar na tela, nunca só
    // o que já está em memória.
    if (!_pediuAbertura) {
      _pediuAbertura = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ControladorEntrega>().abrir(widget.pedidoId);
        // RNF-A14.1 — uma rota por abertura de tela, à parte do
        // polling de estado: o traçado não muda a cada 10 segundos.
        context.read<ControladorRota>().carregar(widget.pedidoId);
      });
    }
  }

  @override
  void dispose() {
    // RF-A08.3 — o polling não deve continuar depois que a tela fecha.
    context.read<ControladorEntrega>().fechar();
    _codigoController.dispose();
    super.dispose();
  }

  /// Guarda de repetição: `build` roda a cada tique do polling (10s), e
  /// sem isto o mesmo erro reapareceria de dez em dez segundos.
  String? _erroJaAvisado;

  @override
  Widget build(BuildContext context) {
    final controlador = context.watch<ControladorEntrega>();
    _avisarErro(controlador);

    return Scaffold(
      backgroundColor: Colors.white,
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
                  const Icon(Icons.cloud_off, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    erro.mensagemParaUsuario,
                    textAlign: TextAlign.center,
                  ),
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

    // RF-A14.1 — o mapa é a tela, e o resto flutua por cima numa folha
    // arrastável: rodando, o que importa é o caminho; chegando, o
    // entregador puxa a folha e o código toma a tela. A ordem de
    // prioridade muda com a mão dele, não com a nossa aposta.
    return Stack(
      children: [
        Positioned.fill(child: _buildRota(context)),
        DraggableScrollableSheet(
          initialChildSize: .34,
          minChildSize: .16,
          maxChildSize: .92,
          builder: (contexto, rolagem) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -2)),
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
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                _buildGeofence(entrega),
                const SizedBox(height: 16),
                _buildAcoesDeNavegacao(context),
                const SizedBox(height: 20),
                if (entrega.podeFinalizar)
                  _buildCartaoCodigo(context, controlador, entrega),
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

  /// Entrar na navegação é ação deliberada ("agora eu vou"), por isso
  /// vive na folha e não sobre o mapa — RNF-A14.2: alvo grande.
  Widget _buildAcoesDeNavegacao(BuildContext context) {
    final rota = context.watch<ControladorRota>().rota;
    if (rota == null || !rota.temTracado) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TelaNavegacao(pedidoId: widget.pedidoId),
          ),
        ),
        icon: const Icon(Icons.navigation),
        label: const Text('Iniciar navegação'),
        style: ElevatedButton.styleFrom(
          backgroundColor: corPrincipal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
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
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/entregas_entregador'),
                child: const Text('Voltar às entregas', style: TextStyle(fontSize: 16)),
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

    if (rota == null || !rota.temTracado) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
        child: Row(
          children: [
            Icon(Icons.map_outlined, color: Colors.grey.shade600),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                rota?.trajeto.explicacao ?? 'Carregando o trajeto…',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
        color: dentro ? corSucesso.withValues(alpha: .12) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dentro ? corSucesso : Colors.grey.shade400),
      ),
      child: Row(
        children: [
          Icon(
            dentro ? Icons.location_on : Icons.location_searching,
            color: dentro ? corSucesso : Colors.grey.shade600,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color.fromRGBO(94, 94, 94, 1)),
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
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _codigoController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, letterSpacing: 6),
            decoration: const InputDecoration(
              counterText: '',
              border: OutlineInputBorder(),
              hintText: '000000',
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
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              onPressed: controlador.enviando
                  ? null
                  : () => _finalizarPorCodigo(context, controlador),
              child: controlador.enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
  ) async {
    final codigo = _codigoController.text.trim();
    if (codigo.length != 6) {
      mostrarAviso(context, 'Informe os 6 dígitos do código.', erro: true);
      return;
    }
    await controlador.finalizarComCodigo(codigo);
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
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent, color: Colors.orange.shade700),
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
          const Text(
            'O aplicativo atualiza sozinho assim que houver novidade — '
            'não é preciso ficar tentando o código.',
            style: TextStyle(fontSize: 13, color: Colors.black87),
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

  String _formatarHora(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  /// RF-A08.6/RF-A08.7 — só aparece quando `contestableReleased` vem
  /// `true`. Exige foto confirmada antes de oferecer o botão final.
  Widget _buildCartaoContestavel(BuildContext context, ControladorEntrega controlador) {
    final temFoto = controlador.uploadIdConfirmado != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
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
          const Text(
            'O código não chegou ao destinatário a tempo. Tire uma foto '
            'do local de entrega para comprovar.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
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
                onPressed: () => controlador.capturarEEnviarFoto(OrigemDaImagem.camera),
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
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              // RF-A08.6 — sem foto, sem botão utilizável.
              onPressed: (!temFoto || controlador.enviando)
                  ? null
                  : () => controlador.finalizarContestavel(),
              child: controlador.enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
    if (erro == null || erro == _erroJaAvisado) return;
    _erroJaAvisado = erro;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      mostrarAviso(context, erro, erro: true);
      controlador.limparErro();
    });
  }
}
