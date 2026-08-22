import 'package:flutter_test/flutter_test.dart';
import 'package:uaiou/core/modelos/dinheiro.dart';

/// Critério de aceite 5 da A-01:
/// somar `"0.10"` dez vezes resulta exatamente `"1.00"`;
/// `"1234.56"` exibe `R$ 1.234,56`.
void main() {
  group('Dinheiro.deString', () {
    test('lê o formato do contrato', () {
      expect(Dinheiro.deString('6.00').centavos, 600);
      expect(Dinheiro.deString('0.10').centavos, 10);
      expect(Dinheiro.deString('1234.56').centavos, 123456);
    });

    test('aceita valor sem casas decimais', () {
      expect(Dinheiro.deString('6').centavos, 600);
      expect(Dinheiro.deString('6.0').centavos, 600);
    });

    test('aceita negativo', () {
      expect(Dinheiro.deString('-6.00').centavos, -600);
    });

    test('aceita zeros irrelevantes além de duas casas', () {
      expect(Dinheiro.deString('6.000').centavos, 600);
    });

    test('recusa precisão que não cabe em centavos', () {
      // Arredondar dinheiro em silêncio é pior que falhar na borda.
      expect(Dinheiro.tentarDeString('6.005'), isNull);
    });

    test('recusa lixo', () {
      expect(Dinheiro.tentarDeString('abc'), isNull);
      expect(Dinheiro.tentarDeString(''), isNull);
      expect(Dinheiro.tentarDeString(null), isNull);
      expect(Dinheiro.tentarDeString('6,00'), isNull);
    });
  });

  group('aritmética exata', () {
    test('somar "0.10" dez vezes dá exatamente "1.00"', () {
      final dezCentavos = Dinheiro.deString('0.10');

      var total = Dinheiro.zero;
      for (var i = 0; i < 10; i++) {
        total = total + dezCentavos;
      }

      expect(total.paraJson(), '1.00');
      expect(total, Dinheiro.deString('1.00'));
    });

    test('a mesma soma em double erraria', () {
      // Prova de por que RF-A01.6 proíbe double para dinheiro.
      var emDouble = 0.0;
      for (var i = 0; i < 10; i++) {
        emDouble += 0.10;
      }
      expect(emDouble == 1.0, isFalse);
    });

    test('soma de coleção', () {
      final valores = [
        Dinheiro.deString('6.00'),
        Dinheiro.deString('4.50'),
        Dinheiro.deString('0.01'),
      ];
      expect(valores.soma.paraJson(), '10.51');
    });

    test('subtração e negação', () {
      final a = Dinheiro.deString('10.00');
      final b = Dinheiro.deString('3.50');
      expect((a - b).paraJson(), '6.50');
      expect((-b).paraJson(), '-3.50');
    });

    test('multiplicação por quantidade', () {
      expect((Dinheiro.deString('6.00') * 3).paraJson(), '18.00');
    });
  });

  group('formatarBRL', () {
    test('formata com milhar e vírgula decimal', () {
      expect(Dinheiro.deString('1234.56').formatarBRL(), r'R$ 1.234,56');
    });

    test('formata valores pequenos', () {
      expect(Dinheiro.deString('0.10').formatarBRL(), r'R$ 0,10');
      expect(Dinheiro.zero.formatarBRL(), r'R$ 0,00');
    });

    test('formata milhões', () {
      expect(Dinheiro.deString('1234567.89').formatarBRL(),
          r'R$ 1.234.567,89');
    });

    test('formata negativo', () {
      expect(Dinheiro.deString('-1234.56').formatarBRL(), r'R$ -1.234,56');
    });
  });

  group('ida e volta com o contrato', () {
    test('paraJson reproduz o formato de entrada', () {
      for (final bruto in ['0.00', '0.10', '6.00', '1234.56', '-3.50']) {
        expect(Dinheiro.deString(bruto).paraJson(), bruto);
      }
    });
  });

  group('comparação', () {
    test('ordena por valor', () {
      final valores = [
        Dinheiro.deString('10.00'),
        Dinheiro.deString('0.10'),
        Dinheiro.deString('6.00'),
      ]..sort();

      expect(valores.map((v) => v.paraJson()).toList(),
          ['0.10', '6.00', '10.00']);
    });

    test('igualdade por valor', () {
      expect(Dinheiro.deString('6.00'), Dinheiro.deString('6.0'));
      expect(Dinheiro.deString('6.00').hashCode,
          Dinheiro.deString('6.0').hashCode);
    });
  });
}
