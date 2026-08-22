/// ===============================================================
/// DINHEIRO — RF-A01.6
/// ===============================================================
///
/// O contrato entrega dinheiro como **string decimal** (`"6.00"`), e
/// este tipo é a única forma de representá-lo no app. `double` é
/// proibido para valor monetário: `0.1 + 0.2` não dá `0.3` em ponto
/// flutuante binário, e o extrato de ganhos é dinheiro que um
/// entregador vai cobrar de um estabelecimento.
///
/// Internamente guarda **centavos** em `int` — exato por construção
/// dentro da faixa que qualquer valor de frete alcança.
class Dinheiro implements Comparable<Dinheiro> {
  /// Valor em centavos. Negativo é permitido (ajuste, estorno).
  final int centavos;

  const Dinheiro.emCentavos(this.centavos);

  static const Dinheiro zero = Dinheiro.emCentavos(0);

  /// Converte a string decimal do contrato.
  ///
  /// Aceita `"6"`, `"6.0"`, `"6.00"`, `"-6.00"` e `"1234.56"`.
  /// Recusa o que não representa exatamente em centavos — melhor
  /// falhar na borda do que arredondar dinheiro em silêncio.
  factory Dinheiro.deString(String bruto) {
    final valor = tentarDeString(bruto);
    if (valor == null) {
      throw FormatException('Valor monetário inválido no contrato', bruto);
    }
    return valor;
  }

  /// Versão tolerante de [Dinheiro.deString]: devolve `null` em vez de
  /// lançar. Para campo opcional do contrato.
  static Dinheiro? tentarDeString(String? bruto) {
    if (bruto == null) return null;

    final texto = bruto.trim();
    if (texto.isEmpty) return null;

    final partes = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?$').firstMatch(texto);
    if (partes == null) return null;

    final negativo = partes.group(1) == '-';
    final inteiros = int.tryParse(partes.group(2)!);
    if (inteiros == null) return null;

    final fracao = partes.group(3) ?? '';

    // Além de duas casas, só zeros são aceitáveis: "6.000" é 6,00;
    // "6.005" não existe em centavos e não pode ser arredondado aqui.
    if (fracao.length > 2) {
      final excedente = fracao.substring(2);
      if (excedente.contains(RegExp(r'[1-9]'))) return null;
    }

    final centavosFracao = int.parse(fracao.padRight(2, '0').substring(0, 2));
    final total = inteiros * 100 + centavosFracao;

    return Dinheiro.emCentavos(negativo ? -total : total);
  }

  /// Serializa no formato que o contrato espera: `"6.00"`.
  String paraJson() {
    final sinal = centavos < 0 ? '-' : '';
    final absoluto = centavos.abs();
    final inteiros = absoluto ~/ 100;
    final resto = absoluto % 100;
    return '$sinal$inteiros.${resto.toString().padLeft(2, '0')}';
  }

  /// Formata para exibição em pt-BR: `R$ 1.234,56`.
  ///
  /// Feito à mão em vez de `NumberFormat` para não depender de
  /// inicialização de locale num tipo usado em toda tela de dinheiro.
  String formatarBRL() {
    final sinal = centavos < 0 ? '-' : '';
    final absoluto = centavos.abs();
    final inteiros = (absoluto ~/ 100).toString();
    final resto = (absoluto % 100).toString().padLeft(2, '0');

    final comMilhar = StringBuffer();
    for (var i = 0; i < inteiros.length; i++) {
      if (i > 0 && (inteiros.length - i) % 3 == 0) comMilhar.write('.');
      comMilhar.write(inteiros[i]);
    }

    return 'R\$ $sinal$comMilhar,$resto';
  }

  bool get eZero => centavos == 0;
  bool get ePositivo => centavos > 0;
  bool get eNegativo => centavos < 0;

  Dinheiro operator +(Dinheiro outro) =>
      Dinheiro.emCentavos(centavos + outro.centavos);

  Dinheiro operator -(Dinheiro outro) =>
      Dinheiro.emCentavos(centavos - outro.centavos);

  Dinheiro operator -() => Dinheiro.emCentavos(-centavos);

  /// Multiplicação por quantidade inteira (ex.: n entregas do mesmo valor).
  /// Não há divisão: repartir dinheiro exige política de arredondamento,
  /// e essa política é do servidor, não do app.
  Dinheiro operator *(int fator) => Dinheiro.emCentavos(centavos * fator);

  @override
  int compareTo(Dinheiro outro) => centavos.compareTo(outro.centavos);

  bool operator <(Dinheiro outro) => centavos < outro.centavos;
  bool operator <=(Dinheiro outro) => centavos <= outro.centavos;
  bool operator >(Dinheiro outro) => centavos > outro.centavos;
  bool operator >=(Dinheiro outro) => centavos >= outro.centavos;

  @override
  bool operator ==(Object other) =>
      other is Dinheiro && other.centavos == centavos;

  @override
  int get hashCode => centavos.hashCode;

  @override
  String toString() => paraJson();
}

/// Soma uma coleção de valores sem passar por `double`.
extension SomaDeDinheiro on Iterable<Dinheiro> {
  Dinheiro get soma => fold(Dinheiro.zero, (total, valor) => total + valor);
}
