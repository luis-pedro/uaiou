import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/cadastro/rascunho_cadastro.dart';
import 'package:uaiou/core/cadastro/validadores.dart';
import 'package:uaiou/core/documentos/documento.dart';
import 'package:uaiou/core/sessao/identidade.dart';
import 'package:uaiou/core/uploads/repositorio_uploads.dart';

/// CPF e CNPJ válidos gerados pelo próprio algoritmo de verificação.
const _cpfValido = '390.533.447-05';
const _cnpjValido = '19.131.243/0001-97';

RascunhoCadastro _completo({Papel papel = Papel.entregador}) {
  return RascunhoCadastro()
    ..papel = papel
    ..nome = 'João Silva'
    ..email = 'joao@teste.com'
    ..cpf = _cpfValido
    ..cnpj = _cnpjValido
    ..placa = 'ABC1D23'
    ..login = 'joao.silva'
    ..senha = 'SenhaForte123'
    ..confirmacaoDeSenha = 'SenhaForte123';
}

void main() {
  group('validadores — RF-A04.3', () {
    test('CPF confere o dígito verificador', () {
      expect(validarCpf(_cpfValido), isNull);
      expect(validarCpf('39053344704'), 'CPF inválido.');
      expect(validarCpf('111.111.111-11'), 'CPF inválido.');
      expect(validarCpf('123'), 'CPF deve ter 11 dígitos.');
      expect(validarCpf(''), 'CPF é obrigatório.');
    });

    test('CNPJ confere o dígito verificador', () {
      expect(validarCnpj(_cnpjValido), isNull);
      expect(validarCnpj('19131243000198'), 'CNPJ inválido.');
      expect(validarCnpj('11.111.111/1111-11'), 'CNPJ inválido.');
    });

    test('e-mail exige forma mínima', () {
      expect(validarEmail('a@b.co'), isNull);
      expect(validarEmail('sem-arroba'), 'E-mail inválido.');
      expect(validarEmail('a@b'), 'E-mail inválido.');
    });

    test('senha respeita a faixa do contrato', () {
      expect(validarSenha('SenhaForte123'), isNull);
      expect(validarSenha('curta'), contains('8 caracteres'));
    });

    test('login respeita a faixa do contrato', () {
      expect(validarLogin('ze'), contains('3 caracteres'));
      expect(validarLogin('a' * 61), 'Usuário longo demais.');
      expect(validarLogin('joao.silva'), isNull);
    });

    test('placa aceita os dois formatos e é opcional', () {
      expect(validarPlaca('ABC1234'), isNull, reason: 'formato antigo');
      expect(validarPlaca('ABC1D23'), isNull, reason: 'Mercosul');
      expect(validarPlaca('ABC-1D23'), isNull, reason: 'com hífen');
      expect(validarPlaca(''), isNull, reason: 'não é exigida pelo contrato');
      expect(validarPlaca('XX'), 'Placa inválida.');
    });
  });

  group('rascunho — RF-A04.1', () {
    test('guarda o que foi digitado entre passos', () {
      final rascunho = RascunhoCadastro()..nome = 'Zé';
      expect(rascunho.nome, 'Zé');
      // Voltar um passo não pode perder o preenchido: o rascunho é o
      // dono do valor, não o TextField.
      expect(rascunho.passoValido(PassoCadastro.dadosPessoais), isFalse);
    });

    test('valida cada passo isoladamente', () {
      final rascunho = _completo();

      expect(rascunho.passoValido(PassoCadastro.dadosPessoais), isTrue);
      expect(rascunho.passoValido(PassoCadastro.perfil), isTrue);
      expect(rascunho.passoValido(PassoCadastro.credenciais), isTrue);
      expect(rascunho.primeiroPassoInvalido(), isNull);
    });

    test('senhas diferentes reprovam o passo 3', () {
      final rascunho = _completo()..confirmacaoDeSenha = 'outra';

      expect(rascunho.passoValido(PassoCadastro.credenciais), isFalse);
      expect(
        rascunho.validar(PassoCadastro.credenciais)['Confirme a senha'],
        'As senhas não conferem.',
      );
    });

    test('primeiroPassoInvalido aponta o passo de origem', () {
      final rascunho = _completo()..cpf = '123';
      expect(rascunho.primeiroPassoInvalido(), PassoCadastro.dadosPessoais);
    });

    test('estabelecimento exige CNPJ; entregador, não', () {
      final estab = _completo(papel: Papel.estabelecimento)..cnpj = '';
      expect(estab.passoValido(PassoCadastro.perfil), isFalse);

      final entregador = _completo()..cnpj = '';
      expect(entregador.passoValido(PassoCadastro.perfil), isTrue);
    });
  });

  group('corpo de POST /auth/registrations', () {
    test('entregador manda cpf e placa, sem cnpj', () {
      final json = _completo().paraJson();

      expect(json['role'], 'COURIER');
      expect(json['login'], 'joao.silva');
      expect(json['displayName'], 'João Silva');

      final perfil = json['profile'] as Map;
      expect(perfil['cpf'], '39053344705', reason: 'só dígitos');
      expect(perfil['vehiclePlate'], 'ABC1D23');
      expect(perfil.containsKey('cnpj'), isFalse);
    });

    test('estabelecimento manda cnpj e businessName, sem cpf', () {
      final json = _completo(papel: Papel.estabelecimento).paraJson();

      expect(json['role'], 'MERCHANT');
      final perfil = json['profile'] as Map;
      expect(perfil['cnpj'], '19131243000197');
      expect(perfil['businessName'], 'João Silva');
      expect(perfil.containsKey('cpf'), isFalse);
    });

    test('placa vazia não vai no corpo — é opcional no contrato', () {
      final json = (_completo()..placa = '').paraJson();
      expect((json['profile'] as Map).containsKey('vehiclePlate'), isFalse);
    });

    /// O protótipo coleta estes campos, mas `RegisterRequest` não tem
    /// onde guardá-los. Enviá-los seria descartado em silêncio.
    test('campos sem destino no contrato não são enviados', () {
      final json = (_completo()
            ..telefone = '35999999999'
            ..dataNascimento = '01/01/2000'
            ..rua = 'Rua A'
            ..cidade = 'Santa Rita')
          .paraJson();

      final texto = json.toString();
      expect(texto.contains('35999999999'), isFalse);
      expect(texto.contains('Rua A'), isFalse);
      expect(texto.contains('Santa Rita'), isFalse);
    });
  });

  group('situação documental — RF-A04.8', () {
    Map<String, dynamic> resposta({
      List<Map<String, dynamic>> documentos = const [],
      List<String> faltando = const [],
    }) =>
        {'documents': documentos, 'missingTypes': faltando};

    test('missingTypes diz o que a tela precisa pedir', () {
      final situacao = SituacaoDocumental.doJson(resposta(
        faltando: ['IDENTITY_DOCUMENT', 'DRIVER_LICENSE'],
      ));

      expect(situacao.faltando, [
        PropositoUpload.documentoIdentidade,
        PropositoUpload.cnh,
      ]);
      expect(situacao.completo, isFalse);
    });

    test('rejeitado expõe o motivo e volta para a fila de envio', () {
      final situacao = SituacaoDocumental.doJson(resposta(documentos: [
        {
          'id': 'd-1',
          'type': 'IDENTITY_DOCUMENT',
          'status': 'rejected',
          'rejectionReason': 'Foto ilegível.',
        }
      ]));

      expect(situacao.rejeitados.single.motivoDaRejeicao, 'Foto ilegível.');
      expect(situacao.aEnviar, contains(PropositoUpload.documentoIdentidade));
      expect(situacao.completo, isFalse);
    });

    test('superado não aparece como pendência', () {
      final situacao = SituacaoDocumental.doJson(resposta(documentos: [
        {'id': 'd-1', 'type': 'IDENTITY_DOCUMENT', 'status': 'superseded'},
        {'id': 'd-2', 'type': 'IDENTITY_DOCUMENT', 'status': 'pending'},
      ]));

      expect(situacao.vigentes.length, 1);
      expect(situacao.vigentes.single.status, StatusDocumento.pendente);
      expect(situacao.completo, isTrue, reason: 'nada falta, nada rejeitado');
    });

    test('tipo desconhecido não derruba a leitura', () {
      final situacao = SituacaoDocumental.doJson(resposta(
        faltando: ['ALGO_NOVO'],
      ));
      expect(situacao.faltando, isEmpty);
    });
  });
}
