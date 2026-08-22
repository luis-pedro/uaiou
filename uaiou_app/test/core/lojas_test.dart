import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/estado/carregavel.dart';
import 'package:uaiou/core/estatisticas/repositorio_estatisticas.dart';
import 'package:uaiou/core/pedidos/repositorio_pedidos.dart';
import 'package:uaiou/core/rede/cliente_api.dart';
import 'package:uaiou/core/sessao/cofre_sessao.dart';
import 'package:uaiou/core/sessao/controlador_sessao.dart';
import 'package:uaiou/core/sessao/repositorio_auth.dart';
import 'package:uaiou/core/sessao/sessao.dart';
import 'package:uaiou/others/entregador_service.dart';
import 'package:uaiou/others/estabelecimento_service.dart';
import 'package:uaiou/others/pedido.dart';

ControladorSessao _sessaoCom({String papel = 'COURIER', String nome = 'Zé'}) {
  final api = ClienteApi(baseUrl: 'http://teste/api/v1');
  final sessao = Sessao.doJson({
    'accessToken': 'a',
    'refreshToken': 'r',
    'expiresIn': 900,
    'user': {
      'id': 'u-1',
      'role': papel,
      'status': 'active',
      'displayName': nome,
    },
  });
  return ControladorSessao(
    auth: RepositorioAuth(api),
    cofre: CofreSessaoEmMemoria(sessao),
  );
}

void main() {
  late RepositorioPedidos repositorio;
  late RepositorioEstatisticas estatisticas;

  setUp(() {
    final api = ClienteApi(baseUrl: 'http://teste/api/v1');
    repositorio = RepositorioPedidos(api);
    estatisticas = RepositorioEstatisticas(api);
  });

  /// Regressão do bug encontrado ao integrar A-03: as listas são
  /// notificadores próprios, e a loja precisa repassar. Sem isso, a
  /// tela que observa só a loja fica girando para sempre, mesmo com a
  /// requisição tendo voltado 200.
  group('a loja repassa a notificação das listas', () {
    test('entregador — as duas listas notificam a loja', () async {
      final sessao = _sessaoCom();
      await sessao.restaurar();
      final loja = EstadoEntregador(repositorio: repositorio, sessao: sessao);

      var avisos = 0;
      loja.addListener(() => avisos++);

      loja.emAndamento.limpar();
      expect(avisos, greaterThan(0), reason: 'lista em andamento');

      final antes = avisos;
      loja.concluidas.limpar();
      expect(avisos, greaterThan(antes), reason: 'lista de concluídas');
    });

    test('estabelecimento — a lista notifica a loja', () async {
      final sessao = _sessaoCom(papel: 'MERCHANT', nome: 'Bar');
      await sessao.restaurar();
      final loja = EstadoEstabelecimento(
        repositorio: repositorio,
        sessao: sessao,
        estatisticas: estatisticas,
      );

      var avisos = 0;
      loja.addListener(() => avisos++);

      loja.pedidos.limpar();

      expect(avisos, greaterThan(0));
    });
  });

  group('identidade vem da sessão (A-02)', () {
    test('entregador usa o nome de exibição do servidor', () async {
      final sessao = _sessaoCom(nome: 'João Silva');
      await sessao.restaurar();
      final loja = EstadoEntregador(repositorio: repositorio, sessao: sessao);

      expect(loja.nome, 'João Silva');
    });

    test('estabelecimento idem', () async {
      final sessao = _sessaoCom(papel: 'MERCHANT', nome: 'Bar do Zé');
      await sessao.restaurar();
      final loja = EstadoEstabelecimento(
        repositorio: repositorio,
        sessao: sessao,
        estatisticas: estatisticas,
      );

      expect(loja.nome, 'Bar do Zé');
    });
  });

  group('o que ainda não tem fonte é nulo, não zero', () {
    test('entregador não inventa ganhos nem disponibilidade', () async {
      final sessao = _sessaoCom();
      await sessao.restaurar();
      final loja = EstadoEntregador(repositorio: repositorio, sessao: sessao);

      // Zero seria uma afirmação — e falsa. Nulo diz "não sei ainda".
      // A nota saiu deste estado na A-12: agora vive em
      // `ControladorScore` (`GET /me/score`), coberto em
      // `avaliacoes_test.dart`.
      expect(loja.disponivel, isNull, reason: 'A-06');
    });

    test('estabelecimento não soma faturamento no cliente', () async {
      final sessao = _sessaoCom(papel: 'MERCHANT');
      await sessao.restaurar();
      final loja = EstadoEstabelecimento(
        repositorio: repositorio,
        sessao: sessao,
        estatisticas: estatisticas,
      );

      expect(loja.faturamentoHoje, isNull, reason: 'A-10 / RF-A10.10');
    });
  });

  group('limpar no logout — RF-A03.9', () {
    test('entregador descarta as duas listas', () async {
      final sessao = _sessaoCom();
      await sessao.restaurar();
      final loja = EstadoEntregador(repositorio: repositorio, sessao: sessao);

      loja.limpar();

      expect(loja.emAndamento.estado, isA<Carregando<List<Pedido>>>());
      expect(loja.concluidas.estado, isA<Carregando<List<Pedido>>>());
    });
  });

  group('ListaDePedidos é a unidade de recorte', () {
    test('cada lista guarda o próprio recorte', () {
      final loja = EstadoEntregador(
        repositorio: repositorio,
        sessao: _sessaoCom(),
      );

      expect(loja.emAndamento.recorte?.paraContrato, 'accepted');
      expect(loja.concluidas.recorte?.paraContrato, 'finalized');
    });

    test('estabelecimento não força recorte — o servidor decide', () {
      final loja = EstadoEstabelecimento(
        repositorio: repositorio,
        sessao: _sessaoCom(papel: 'MERCHANT'),
        estatisticas: estatisticas,
      );

      expect(loja.pedidos.recorte, isNull);
    });
  });
}
