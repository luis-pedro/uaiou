/// Ponto de injeção do token no cliente HTTP.
///
/// **A-01 só define o contrato; quem o implementa é A-02.** Está aqui
/// para que o [ClienteApi] já nasça com o lugar certo para a
/// credencial — e não para que cada repositório invente o seu.
abstract interface class ProvedorDeCredencial {
  /// Token a enviar em `Authorization: Bearer`, ou `null` se não há
  /// sessão (rotas públicas: cadastro, login, recuperação de senha).
  Future<String?> tokenAtual();

  /// Tenta renovar a sessão depois de um 401.
  ///
  /// Devolve `true` se renovou — o cliente então **repete a
  /// requisição original uma única vez** (RF-A02.5). Requisições
  /// concorrentes devem compartilhar a mesma renovação, e essa
  /// coordenação é responsabilidade de quem implementa.
  Future<bool> renovar();

  /// Encerra a sessão local. Chamado quando a renovação falha.
  Future<void> encerrarSessao();
}

/// Implementação neutra usada até A-02 existir: sem token, sem
/// renovação. Deixa o app funcionar nas rotas públicas.
class SemCredencial implements ProvedorDeCredencial {
  const SemCredencial();

  @override
  Future<String?> tokenAtual() async => null;

  @override
  Future<bool> renovar() async => false;

  @override
  Future<void> encerrarSessao() async {}
}
