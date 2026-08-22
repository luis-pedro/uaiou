import '../rede/cliente_api.dart';

/// `PUT /me/availability`, `PUT /me/location` e o recorte de
/// disponibilidade de `GET /me` — `api/usuarios.md`.
class RepositorioPresenca {
  final ClienteApi _api;

  const RepositorioPresenca(this._api);

  /// RF-A06.1 — o estado exibido é o que **o servidor confirma**, não
  /// o que o app mandou.
  Future<bool> definirDisponibilidade(bool disponivel) async {
    final resposta = await _api.substituir(
      '/me/availability',
      corpo: {'available': disponivel},
    );
    if (resposta is Map && resposta['available'] is bool) {
      return resposta['available'] as bool;
    }
    return disponivel;
  }

  /// RF-A06.3 — 204, sem corpo de resposta.
  Future<void> enviarLocalizacao({
    required double lat,
    required double lng,
    double? precisao,
  }) {
    return _api.substituir(
      '/me/location',
      corpo: {'lat': lat, 'lng': lng, 'accuracy': ?precisao},
    );
  }

  /// RF-A06.8 — só o campo de disponibilidade de `GET /me`, para notar
  /// que o servidor expirou a presença por inatividade.
  Future<bool?> obterDisponibilidadeDoServidor() async {
    final resposta = await _api.obter('/me');
    if (resposta is Map && resposta['profile'] is Map) {
      final perfil = resposta['profile'] as Map;
      return perfil['available'] as bool?;
    }
    return null;
  }
}
