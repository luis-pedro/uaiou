import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/avaliacoes/controlador_avaliacoes.dart';
import 'package:uaiou/core/avaliacoes/repositorio_avaliacoes.dart';
import 'package:uaiou/core/bloqueios/estado_bloqueios.dart';
import 'package:uaiou/core/bloqueios/repositorio_bloqueios.dart';
import 'package:uaiou/core/cadastro/controlador_cadastro.dart';
import 'package:uaiou/core/cadastro/rascunho_cadastro.dart';
import 'package:uaiou/core/documentos/estado_documentos.dart';
import 'package:uaiou/core/entregas/controlador_entrega.dart';
import 'package:uaiou/core/entregas/repositorio_entregas.dart';
import 'package:uaiou/core/estatisticas/controlador_estatisticas.dart';
import 'package:uaiou/core/estatisticas/repositorio_estatisticas.dart';
import 'package:uaiou/core/gamificacao/controlador_score.dart';
import 'package:uaiou/core/gamificacao/repositorio_score.dart';
import 'package:uaiou/core/ganhos/controlador_ganhos.dart';
import 'package:uaiou/core/ganhos/repositorio_ganhos.dart';
import 'package:uaiou/core/notificacoes/controlador_notificacoes.dart';
import 'package:uaiou/core/notificacoes/controlador_preferencias_notificacao.dart';
import 'package:uaiou/core/notificacoes/identificador_dispositivo.dart';
import 'package:uaiou/core/notificacoes/repositorio_dispositivo.dart';
import 'package:uaiou/core/notificacoes/repositorio_notificacoes.dart';
import 'package:uaiou/core/pagar/controlador_payables.dart';
import 'package:uaiou/core/pagar/repositorio_payables.dart';
import 'package:uaiou/core/pedidos/controlador_vitrine.dart';
import 'package:uaiou/core/pedidos/repositorio_pedidos.dart';
import 'package:uaiou/core/perfil/controlador_perfil.dart';
import 'package:uaiou/core/perfil/repositorio_perfil.dart';
import 'package:uaiou/core/presenca/controlador_presenca.dart';
import 'package:uaiou/core/presenca/repositorio_presenca.dart';
import 'package:uaiou/core/rotas/controlador_rota.dart';
import 'package:uaiou/core/rotas/repositorio_rotas.dart';
import 'package:uaiou/core/uploads/repositorio_uploads.dart';
import 'package:uaiou/core/uploads/seletor_de_imagem.dart';
import 'package:uaiou/core/rede/cliente_api.dart';
import 'package:uaiou/core/sessao/cofre_sessao.dart';
import 'package:uaiou/core/sessao/controlador_sessao.dart';
import 'package:uaiou/core/sessao/identidade.dart';
import 'package:uaiou/core/sessao/repositorio_auth.dart';
import 'package:uaiou/others/entregador_service.dart';
import 'package:uaiou/others/estabelecimento_service.dart';
import 'package:uaiou/core/config/ambiente.dart';

//TELAS PRINCIPAIS DE LOGIN
import 'package:uaiou/screens/principal_login.dart';
import 'package:uaiou/screens/login_screen.dart';
import 'package:uaiou/screens/tela_bloqueios.dart';
import 'package:uaiou/screens/tela_cadastro.dart';
import 'package:uaiou/screens/tela_documentos.dart';
import 'package:uaiou/screens/tela_editar_perfil.dart';
import 'package:uaiou/screens/tela_notificacoes.dart';
import 'package:uaiou/screens/tela_preferencias_notificacao.dart';
import 'package:uaiou/screens/tela_status_conta.dart';
import 'package:uaiou/screens/tela_avaliacoes.dart';

//TELAS DE CADASTRO - ENTREGADOR
import 'package:uaiou/screens/tela_cadastro_entregador1.dart';
import 'package:uaiou/screens/tela_cadastro_entregador2.dart';
import 'package:uaiou/screens/tela_cadastro_entregador3.dart';

//TELAS DE CADASTRO - ESTABELECIMENTO
import 'package:uaiou/screens/tela_cadastro_estabelecimento1.dart';
import 'package:uaiou/screens/tela_cadastro_estabelecimento2.dart';
import 'package:uaiou/screens/tela_cadastro_estabelecimento3.dart';

//TELAS PRINCIPAIS - ENTREGADOR
import 'package:uaiou/screens/tela_principal_entregador.dart';
import 'package:uaiou/screens/tela_entrega_em_andamento.dart';
import 'package:uaiou/screens/tela_entregas_entregador.dart';
import 'package:uaiou/screens/tela_atividade_entregador.dart';
import 'package:uaiou/screens/tela_extrato_ganhos.dart';
import 'package:uaiou/screens/tela_perfil_entregador.dart';

//TELAS PRINCIPAIS - ESTABELECIMENTO
import 'package:uaiou/screens/tela_principal_estabelecimento.dart';
import 'package:uaiou/screens/tela_estabelecimento_pedidos.dart';
import 'package:uaiou/screens/tela_atividade_estabelecimento.dart';
import 'package:uaiou/screens/tela_perfil_estabelecimento.dart';

/// RF-A13.8 — coleta mínima e local de falha não tratada.
///
/// Sem serviço de terceiro (Sentry, Crashlytics, etc.): integrar um
/// deles é decisão de produto/infra fora do escopo desta task — isto
/// é só o ponto de extensão, registrando tipo e stack **sem** payload
/// de requisição, token ou entrada de usuário.
void _registrarFalhaNaoTratada(Object erro, StackTrace pilha) {
  debugPrint('[falha não tratada] ${erro.runtimeType}: $erro\n$pilha');
}

/// RF-A13.2 — texto puro só é aceito em desenvolvimento. Um build de
/// distribuição (`kReleaseMode`) apontando para HTTP em vez de HTTPS
/// é erro de configuração de build, não algo para tentar rodar assim
/// mesmo: ele trava aqui, antes de montar qualquer tela normal.
bool get _configuracaoDeBuildInvalida =>
    !Ambiente.modoDesenvolvedor && Ambiente.usaTextoPuro;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    _registrarFalhaNaoTratada(details.exception, details.stack ?? StackTrace.empty);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (erro, pilha) {
    _registrarFalhaNaoTratada(erro, pilha);
    return true;
  };

  if (_configuracaoDeBuildInvalida) {
    runApp(const _AppConfiguracaoInvalida());
    return;
  }

  runApp(const MyApp());
}

/// Tela de bloqueio da RF-A13.2 — nunca a UI normal, nunca crash
/// silencioso.
class _AppConfiguracaoInvalida extends StatelessWidget {
  const _AppConfiguracaoInvalida();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_outline, color: Colors.white, size: 48),
                SizedBox(height: 16),
                Text(
                  'Configuração de build inválida: HTTPS obrigatório '
                  'fora de desenvolvimento.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// RF-A13.6 — aceso quando o servidor exige atualização (426). Vive
/// fora da árvore de widgets porque [ClienteApi] é criado antes de
/// qualquer `BuildContext` existir.
final ValueNotifier<bool> _atualizacaoObrigatoria = ValueNotifier(false);

/// Rotas que exigem sessão ativa (RF-A02.10). O que não está aqui é
/// público: login, cadastro e as telas de cadastro em andamento.
const Set<String> _rotasDeOperacao = {
  '/principal_entregador',
  '/entregas_entregador',
  '/atividades_entregador',
  '/perfil_entregador',
  '/principal_estabelecimento',
  '/pedidos_estabelecimento',
  '/atividades_estabelecimento',
  '/perfil_estabelecimento',
  '/editar_perfil',
  '/documentos',
  '/bloqueios',
  '/entrega_em_andamento',
  '/extrato_ganhos',
  '/notificacoes',
  '/preferencias_notificacao',
  '/avaliacoes',
};

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Cliente e controlador nascem juntos e se conhecem: o
        // controlador É o ProvedorDeCredencial do cliente (RF-A01.3).
        Provider<ClienteApi>(
          create: (_) => ClienteApi(
            aoExigirAtualizacao: () => _atualizacaoObrigatoria.value = true,
          ),
        ),
        ChangeNotifierProvider<ControladorSessao>(
          create: (contexto) {
            final api = contexto.read<ClienteApi>();
            final controlador = ControladorSessao(
              auth: RepositorioAuth(api),
              cofre: CofreSessaoSeguro(),
              // RF-A11.1/RF-A11.2 — registro e baixa do dispositivo
              // acontecem dentro do próprio ciclo de vida da sessão.
              dispositivos: RepositorioDispositivo(api),
              identificadorDispositivo: IdentificadorDispositivoSeguro(),
            );
            api.credencial = controlador;
            // RF-A02.6 — sessão persistente entre aberturas.
            controlador.restaurar();
            return controlador;
          },
        ),
        Provider<RepositorioPedidos>(
          create: (contexto) => RepositorioPedidos(contexto.read<ClienteApi>()),
        ),
        Provider<SeletorDeImagem>(create: (_) => SeletorDeImagem()),

        // Cadastro (A-04) — o rascunho vive enquanto o assistente
        // estiver aberto e é descartado ao concluir.
        ChangeNotifierProvider<RascunhoCadastro>(
          create: (_) => RascunhoCadastro(),
        ),
        ChangeNotifierProvider<ControladorCadastro>(
          create: (contexto) => ControladorCadastro(
            cadastro: RepositorioCadastro(contexto.read<ClienteApi>()),
            sessao: contexto.read<ControladorSessao>(),
          ),
        ),
        ChangeNotifierProxyProvider<ControladorSessao, EstadoDocumentos>(
          create: (contexto) {
            final api = contexto.read<ClienteApi>();
            return EstadoDocumentos(
              documentos: RepositorioDocumentos(api),
              uploads: RepositorioUploads(api),
            );
          },
          update: (_, sessao, estado) =>
              _sincronizar(estado!, sessao, estado.limpar),
        ),
        // Perfil (A-05) — `GET /me` é a rota de bootstrap comum aos
        // dois papéis; a mesma loja serve as duas telas de perfil.
        ChangeNotifierProxyProvider<ControladorSessao, ControladorPerfil>(
          create: (contexto) => ControladorPerfil(
            repositorio: RepositorioPerfil(contexto.read<ClienteApi>()),
          ),
          update: (_, sessao, estado) =>
              _sincronizar(estado!, sessao, estado.limpar),
        ),
        // Presença (A-06) — disponibilidade e envio de posição, à
        // parte de `EstadoEntregador` porque envolve ciclo de vida de
        // stream (start/stop), não só dados de tela.
        ChangeNotifierProxyProvider<ControladorSessao, ControladorPresenca>(
          create: (contexto) => ControladorPresenca(
            repositorio: RepositorioPresenca(contexto.read<ClienteApi>()),
          ),
          update: (_, sessao, estado) =>
              _sincronizar(estado!, sessao, estado.limpar),
        ),
        ChangeNotifierProxyProvider<ControladorSessao, EstadoBloqueios>(
          create: (contexto) => EstadoBloqueios(
            repositorio: RepositorioBloqueios(contexto.read<ClienteApi>()),
          ),
          update: (_, sessao, estado) =>
              _sincronizar(estado!, sessao, estado.limpar),
        ),
        // As lojas dependem da sessão: trocam de conteúdo quando o
        // usuário entra ou sai (RF-A03.9).
        // Vitrine e aceite (A-07) — à parte de `EstadoEntregador`
        // porque tem reentrância e resultado por-tentativa que a lista
        // genérica de leitura não modela.
        ChangeNotifierProxyProvider<ControladorSessao, ControladorVitrine>(
          create: (contexto) =>
              ControladorVitrine(contexto.read<RepositorioPedidos>()),
          update: (_, sessao, estado) =>
              _sincronizar(estado!, sessao, estado.limpar),
        ),
        ChangeNotifierProxyProvider<ControladorSessao, EstadoEntregador>(
          create: (contexto) => EstadoEntregador(
            repositorio: contexto.read<RepositorioPedidos>(),
            sessao: contexto.read<ControladorSessao>(),
          ),
          update: (_, sessao, estado) =>
              _sincronizar(estado!, sessao, estado.limpar),
        ),
        // Execução da entrega (A-08) — geofence, código e contestável,
        // tudo lido de `_links` de `GET /orders/{id}/delivery`.
        Provider<RepositorioEntregas>(
          create: (contexto) => RepositorioEntregas(contexto.read<ClienteApi>()),
        ),
        ChangeNotifierProxyProvider<ControladorSessao, ControladorEntrega>(
          create: (contexto) => ControladorEntrega(
            repositorio: contexto.read<RepositorioEntregas>(),
            uploads: RepositorioUploads(contexto.read<ClienteApi>()),
            seletor: contexto.read<SeletorDeImagem>(),
          ),
          update: (_, sessao, estado) =>
              _sincronizar(estado!, sessao, estado.limpar),
        ),
        // Rota e navegação (A-14) — `GET /orders/{id}/route` (T-25).
        // Fora do controlador de entrega de propósito: rota é dado
        // estável e não pode pegar carona no polling de 10s dele
        // (RNF-A14.1).
        Provider<RepositorioRotas>(
          create: (contexto) => RepositorioRotas(contexto.read<ClienteApi>()),
        ),
        ChangeNotifierProxyProvider<ControladorSessao, ControladorRota>(
          create: (contexto) => ControladorRota(
            repositorio: contexto.read<RepositorioRotas>(),
          ),
          update: (_, sessao, estado) =>
              _sincronizar(estado!, sessao, estado.limpar),
        ),
        // Ganhos e acerto (A-09) — livro-razão do entregador
        // (`GET /me/earnings`, `POST /me/earnings/settlements`).
        Provider<RepositorioGanhos>(
          create: (contexto) => RepositorioGanhos(contexto.read<ClienteApi>()),
        ),
        ChangeNotifierProxyProvider<ControladorSessao, ControladorGanhos>(
          create: (contexto) => ControladorGanhos(
            repositorio: contexto.read<RepositorioGanhos>(),
          ),
          update: (_, sessao, estado) =>
              _sincronizar(estado!, sessao, estado.limpar),
        ),
        // Estatísticas do entregador (A-09/RF-A09.7) — `GET /me/stats`.
        Provider<RepositorioEstatisticas>(
          create: (contexto) => RepositorioEstatisticas(contexto.read<ClienteApi>()),
        ),
        ChangeNotifierProxyProvider<ControladorSessao, ControladorEstatisticas>(
          create: (contexto) => ControladorEstatisticas(
            repositorio: contexto.read<RepositorioEstatisticas>(),
          ),
          update: (_, sessao, estado) =>
              _sincronizar(estado!, sessao, estado.limpar),
        ),
        ChangeNotifierProxyProvider<ControladorSessao, EstadoEstabelecimento>(
          create: (contexto) => EstadoEstabelecimento(
            repositorio: contexto.read<RepositorioPedidos>(),
            sessao: contexto.read<ControladorSessao>(),
            estatisticas: contexto.read<RepositorioEstatisticas>(),
          ),
          update: (_, sessao, estado) =>
              _sincronizar(estado!, sessao, estado.limpar),
        ),
        // A pagar (A-10/RF-A10.9) — espelho de ganhos (A-09), do lado
        // do estabelecimento (`GET /me/payables`).
        Provider<RepositorioPayables>(
          create: (contexto) => RepositorioPayables(contexto.read<ClienteApi>()),
        ),
        ChangeNotifierProxyProvider<ControladorSessao, ControladorPayables>(
          create: (contexto) => ControladorPayables(
            repositorio: contexto.read<RepositorioPayables>(),
          ),
          update: (_, sessao, estado) =>
              _sincronizar(estado!, sessao, estado.limpar),
        ),
        // Notificações (A-11) — inbox e preferências servem os dois
        // papéis igualmente (`qualquer papel`, ver contrato).
        Provider<RepositorioNotificacoes>(
          create: (contexto) =>
              RepositorioNotificacoes(contexto.read<ClienteApi>()),
        ),
        ChangeNotifierProxyProvider<ControladorSessao, ControladorNotificacoes>(
          create: (contexto) => ControladorNotificacoes(
            repositorio: contexto.read<RepositorioNotificacoes>(),
          ),
          update: (_, sessao, estado) =>
              _sincronizar(estado!, sessao, estado.limpar),
        ),
        ChangeNotifierProxyProvider<
          ControladorSessao,
          ControladorPreferenciasNotificacao
        >(
          create: (contexto) => ControladorPreferenciasNotificacao(
            repositorio: contexto.read<RepositorioNotificacoes>(),
          ),
          update: (_, sessao, estado) =>
              _sincronizar(estado!, sessao, estado.limpar),
        ),
        // Score (A-12/RF-A12.4) — `GET /me/score`, compartilhado entre
        // o cabeçalho da principal e o card do perfil dos dois papéis.
        Provider<RepositorioScore>(
          create: (contexto) => RepositorioScore(contexto.read<ClienteApi>()),
        ),
        ChangeNotifierProxyProvider<ControladorSessao, ControladorScore>(
          create: (contexto) =>
              ControladorScore(repositorio: contexto.read<RepositorioScore>()),
          update: (_, sessao, estado) =>
              _sincronizar(estado!, sessao, estado.limpar),
        ),
        // Avaliações (A-12) — `POST /orders/{id}/reviews` e
        // `GET /me/reviews`, mútuo aos dois papéis.
        Provider<RepositorioAvaliacoes>(
          create: (contexto) => RepositorioAvaliacoes(contexto.read<ClienteApi>()),
        ),
        ChangeNotifierProxyProvider<ControladorSessao, ControladorAvaliacoes>(
          create: (contexto) => ControladorAvaliacoes(
            repositorio: contexto.read<RepositorioAvaliacoes>(),
          ),
          update: (_, sessao, estado) =>
              _sincronizar(estado!, sessao, estado.limpar),
        ),
      ],
      child: MaterialApp(
        title: 'UaiOu',
        debugShowCheckedModeBanner: false,
        home: const _Raiz(),
        onGenerateRoute: _gerarRota,
        // RF-A13.6 — qualquer tela, a qualquer momento: um 426 aciona
        // o bloqueio por cima de tudo, sem passar pelo tratamento de
        // erro genérico de cada tela.
        builder: (contexto, filho) => ValueListenableBuilder<bool>(
          valueListenable: _atualizacaoObrigatoria,
          builder: (_, exige, _) =>
              exige ? const _TelaAtualizacaoObrigatoria() : filho!,
        ),
      ),
    );
  }
}

/// Bloqueio de tela cheia da RF-A13.6 — ver comentário em
/// [AtualizacaoObrigatoria] sobre o backend ainda não emitir isto.
class _TelaAtualizacaoObrigatoria extends StatelessWidget {
  const _TelaAtualizacaoObrigatoria();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(254, 98, 29, 1),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.system_update, color: Colors.white, size: 48),
              SizedBox(height: 16),
              Text(
                'Esta versão do UaiOu não é mais compatível com o '
                'servidor. Atualize o aplicativo para continuar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// RF-A03.9 — dado do usuário anterior não pode sobreviver à troca de
/// conta. Sair da sessão descarta o que as lojas carregaram.
T _sincronizar<T>(T loja, ControladorSessao sessao, void Function() limpar) {
  if (!sessao.autenticado) limpar();
  return loja;
}

/// Guarda de rota — RF-A02.10.
///
/// Antes de A-02, qualquer rota nomeada era alcançável a qualquer
/// momento, inclusive sem sessão.
Route<dynamic>? _gerarRota(RouteSettings configuracao) {
  final nome = configuracao.name;

  Widget construir(BuildContext contexto) {
    if (_rotasDeOperacao.contains(nome)) {
      final sessao = contexto.read<ControladorSessao>();
      if (!sessao.autenticado) return const LoginScreen();
      if (!sessao.podeOperar) return const TelaStatusConta();
    }

    // RF-A08.2 — a tela de execução recebe o id do pedido por
    // argumento de rota; sem ele não há o que abrir.
    if (nome == '/entrega_em_andamento') {
      final pedidoId = configuracao.arguments as String?;
      if (pedidoId == null) return const TelaEntregasEntregador();
      return TelaEntregaEmAndamento(pedidoId: pedidoId);
    }

    return _telas[nome]?.call(contexto) ?? const _Raiz();
  }

  return MaterialPageRoute<dynamic>(builder: construir, settings: configuracao);
}

final Map<String, WidgetBuilder> _telas = {
  // TELAS PRINCIPAIS DE LOGIN
  '/login': (_) => const LoginScreen(),
  '/cadastro': (_) => const TelaCadastro(),

  // TELAS DE CADASTRO — ENTREGADOR
  '/cadastro_entregador1': (_) => const CadastroEntregador1(),
  '/cadastro_entregador2': (_) => const CadastroEntregador2(),
  '/cadastro_entregador3': (_) => const CadastroEntregador3(),

  // TELAS DE CADASTRO — ESTABELECIMENTO
  '/cadastro_estabelecimento1': (_) => const CadastroEstabelecimento1(),
  '/cadastro_estabelecimento2': (_) => const CadastroEstabelecimento2(),
  '/cadastro_estabelecimento3': (_) => const CadastroEstabelecimento3(),

  // TELAS PRINCIPAIS — ENTREGADOR
  '/principal_entregador': (_) => const TelaPrincipalEntregador(),
  '/entregas_entregador': (_) => const TelaEntregasEntregador(),
  '/atividades_entregador': (_) => const TelaAtividadesEntregador(),
  '/perfil_entregador': (_) => const TelaPerfilEntregador(),

  // TELAS PRINCIPAIS — ESTABELECIMENTO
  '/principal_estabelecimento': (_) => const TelaPrincipalEstabelecimento(),
  '/pedidos_estabelecimento': (_) => const TelaPedidosEstabelecimento(),
  '/atividades_estabelecimento': (_) => const TelaAtividadesEstabelecimento(),
  '/perfil_estabelecimento': (_) => const TelaPerfilEstabelecimento(),

  // PERFIL (A-05) — comuns aos dois papéis.
  '/editar_perfil': (_) => const TelaEditarPerfil(),
  '/documentos': (_) => const TelaDocumentos(),
  '/bloqueios': (_) => const TelaBloqueios(),

  // GANHOS E ACERTO (A-09)
  '/extrato_ganhos': (_) => const TelaExtratoGanhos(),

  // NOTIFICAÇÕES (A-11)
  '/notificacoes': (_) => const TelaNotificacoes(),
  '/preferencias_notificacao': (_) => const TelaPreferenciasNotificacao(),

  // AVALIAÇÕES E SCORE (A-12) — comum aos dois papéis.
  '/avaliacoes': (_) => const TelaAvaliacoes(),
};

/// Decide a tela inicial a partir da sessão, e reage a mudanças dela.
///
/// É isto que faz o login e o logout navegarem sozinhos: nenhuma tela
/// chama `Navigator` depois de autenticar.
class _Raiz extends StatelessWidget {
  const _Raiz();

  @override
  Widget build(BuildContext context) {
    final sessao = context.watch<ControladorSessao>();

    return switch (sessao.fase) {
      FaseSessao.carregando => const _Splash(),
      FaseSessao.deslogado => const PrincipalLogin(),
      FaseSessao.autenticado => _paraUsuario(sessao),
    };
  }

  static Widget _paraUsuario(ControladorSessao sessao) {
    if (!sessao.podeOperar) return const TelaStatusConta();

    return switch (sessao.papel) {
      Papel.entregador => const TelaPrincipalEntregador(),
      Papel.estabelecimento => const TelaPrincipalEstabelecimento(),
      // Admin não tem área no app; papel desconhecido idem.
      Papel.admin || Papel.desconhecido => const TelaStatusConta(),
    };
  }
}

/// Mostrado enquanto o cofre é lido na abertura (RF-A02.6).
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color.fromRGBO(254, 98, 29, 1),
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
