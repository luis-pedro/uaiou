import '../rede/erros_api.dart';

/// ===============================================================
/// OS QUATRO CAMINHOS — RF-A03.3
/// ===============================================================
///
/// Antes de A-03, nenhuma tela tinha *carregando*, *vazio* ou *erro*:
/// a lista vazia dos singletons era indistinguível de "ainda não
/// carregou" e de "a requisição falhou". Três situações muito
/// diferentes para o usuário, desenhadas iguais.
///
/// Tipo selado para que a tela trate os quatro casos com `switch`
/// exaustivo — esquecer um vira erro de compilação, não tela branca.
sealed class Carregavel<T> {
  const Carregavel();

  /// Conteúdo, quando há. `null` nos demais estados.
  T? get valorOuNulo => switch (this) {
    Pronto<T>(:final valor) => valor,
    _ => null,
  };

  bool get carregando => this is Carregando<T>;
  bool get temConteudo => this is Pronto<T>;

  R quando<R>({
    required R Function() carregando,
    required R Function(T valor) pronto,
    required R Function() vazio,
    required R Function(ErroApi erro) falhou,
  }) => switch (this) {
    Carregando<T>() => carregando(),
    Pronto<T>(:final valor) => pronto(valor),
    Vazio<T>() => vazio(),
    Falhou<T>(:final erro) => falhou(erro),
  };
}

/// Primeira carga em andamento. **Não** é usado em recarga: recarregar
/// mantém o conteúdo na tela e sinaliza o progresso por outro meio,
/// senão a lista pisca a cada gesto de puxar.
class Carregando<T> extends Carregavel<T> {
  const Carregando();
}

class Pronto<T> extends Carregavel<T> {
  final T valor;
  const Pronto(this.valor);
}

/// Carregou com sucesso e não há o que mostrar.
///
/// [motivo] permite explicar *por que* está vazio quando o servidor
/// diz — o `warning: LOCATION_STALE` de `GET /orders`, por exemplo,
/// significa "sua posição está velha demais", não "não há pedidos".
class Vazio<T> extends Carregavel<T> {
  final String? motivo;
  const Vazio([this.motivo]);
}

class Falhou<T> extends Carregavel<T> {
  final ErroApi erro;
  const Falhou(this.erro);
}
