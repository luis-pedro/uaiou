import 'package:geolocator/geolocator.dart';

/// ===============================================================
/// LEITURA DE POSIÇÃO — RF-A06.2/RF-A06.3/RF-A06.6/RF-A06.7
/// ===============================================================
///
/// Abstrai `Geolocator` atrás de uma interface para que
/// `ControladorPresenca` seja testável com um fake: a Geolocation API
/// só existe dentro de um navegador de verdade, não em `flutter test`.
///
/// No Flutter Web, o `geolocator` delega a permissão ao prompt nativo
/// do próprio navegador — não há tela de permissão do app para
/// desenhar, só os estados que o navegador devolve.
class PosicaoLida {
  final double lat;
  final double lng;
  final double? precisao;

  const PosicaoLida({required this.lat, required this.lng, this.precisao});
}

abstract class LeitorDePosicao {
  Future<bool> servicoHabilitado();
  Future<bool> permissaoConcedida();
  Future<bool> pedirPermissao();
  Future<PosicaoLida> posicaoAtual();

  /// Emite uma leitura só quando o aparelho se moveu pelo menos
  /// [filtroDeDistanciaMetros] desde a última — é o próprio pacote
  /// resolvendo "parado no semáforo não gera tráfego" (RF-A06.3).
  Stream<PosicaoLida> stream({required int filtroDeDistanciaMetros});
}

class LeitorDePosicaoGeolocator implements LeitorDePosicao {
  const LeitorDePosicaoGeolocator();

  @override
  Future<bool> servicoHabilitado() => Geolocator.isLocationServiceEnabled();

  @override
  Future<bool> permissaoConcedida() async {
    final permissao = await Geolocator.checkPermission();
    return _concedida(permissao);
  }

  @override
  Future<bool> pedirPermissao() async {
    final permissao = await Geolocator.requestPermission();
    return _concedida(permissao);
  }

  bool _concedida(LocationPermission permissao) =>
      permissao == LocationPermission.always ||
      permissao == LocationPermission.whileInUse;

  @override
  Future<PosicaoLida> posicaoAtual() async {
    final posicao = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    return _paraPosicaoLida(posicao);
  }

  @override
  Stream<PosicaoLida> stream({required int filtroDeDistanciaMetros}) {
    // RF-A06.5: segundo plano com a aba minimizada/tela apagada não é
    // uma capacidade que o navegador expõe a uma página web comum —
    // isso exige app nativo (Android/iOS background location). O
    // stream aqui só emite enquanto a aba está aberta; não há como
    // fingir o contrário sem simular dado falso.
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        distanceFilter: filtroDeDistanciaMetros,
      ),
    ).map(_paraPosicaoLida);
  }

  PosicaoLida _paraPosicaoLida(Position posicao) => PosicaoLida(
    lat: posicao.latitude,
    lng: posicao.longitude,
    precisao: posicao.accuracy,
  );
}
