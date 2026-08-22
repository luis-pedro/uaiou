import '../rede/cliente_api.dart';
import '../rede/erros_api.dart';

/// `POST/GET/DELETE /me/devices` — `MeNotificationsController.java` +
/// `DeviceResponse.java` (RF-A11.1/RF-A11.2).
class DispositivoRegistrado {
  final String id;
  final String platform;
  final String? appVersion;
  final DateTime? lastUsedAt;

  const DispositivoRegistrado({
    required this.id,
    required this.platform,
    this.appVersion,
    this.lastUsedAt,
  });

  factory DispositivoRegistrado.doJson(Object? json) {
    final mapa = json is Map ? json : const {};
    return DispositivoRegistrado(
      id: mapa['id'] as String? ?? '',
      platform: mapa['platform'] as String? ?? '',
      appVersion: mapa['appVersion'] as String?,
      lastUsedAt: _dataLocal(mapa['lastUsedAt']),
    );
  }
}

DateTime? _dataLocal(Object? bruto) {
  if (bruto is! String) return null;
  return DateTime.tryParse(bruto)?.toLocal();
}

class RepositorioDispositivo {
  final ClienteApi _api;

  const RepositorioDispositivo(this._api);

  /// `platform: "web"` é aceito pelo backend real (regex
  /// `android|ios|web` em `RegisterDeviceRequest`), mesmo sem push
  /// efetivo por trás — ver `identificador_dispositivo.dart`.
  Future<DispositivoRegistrado> registrar({
    required String pushToken,
    String platform = 'web',
    String? appVersion,
  }) async {
    final resposta = await _api.criar(
      '/me/devices',
      corpo: {
        'platform': platform,
        'pushToken': pushToken,
        'appVersion': ?appVersion,
      },
    );
    if (resposta is! Map) {
      throw const ErroInesperado(
        mensagem: 'Resposta de registro de dispositivo fora do contrato.',
      );
    }
    return DispositivoRegistrado.doJson(resposta);
  }

  /// `GET /me/devices` devolve lista simples, sem paginação.
  Future<List<DispositivoRegistrado>> listar() async {
    final resposta = await _api.obter('/me/devices');
    if (resposta is! List) return const [];
    return resposta
        .whereType<Map>()
        .map(DispositivoRegistrado.doJson)
        .toList();
  }

  Future<void> remover(String id) => _api.remover('/me/devices/$id');
}
