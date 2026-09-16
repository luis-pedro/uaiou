import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';

/// ===============================================================
/// PUSH (FCM) — Android e iOS
/// ===============================================================
///
/// Contrato com o backend (`FcmPushSender.java`):
/// - `data` traz `notificationId`, `type`, `priority` e o payload do
///   evento (strings);
/// - canal Android `urgente` para `priority: urgent`, `geral` para o
///   resto. Os ids precisam bater com os do backend.
///
/// Web (Flutter Web) fica de fora: exige service worker + chave VAPID e
/// não entrega com o navegador fechado. Lá o registro continua com o
/// identificador local (ver `identificador_dispositivo.dart`) e a inbox
/// segue sendo a fonte — o painel web do estabelecimento é quem tem push
/// de navegador.
class TokenPush {
  final String valor;

  /// `android` ou `ios` — o que `RegisterDeviceRequest` aceita.
  final String plataforma;

  const TokenPush(this.valor, this.plataforma);
}

/// Toque em notificação ou chegada com o app aberto.
class EventoPush {
  final String? notificationId;
  final String? type;
  final bool urgente;
  final String? titulo;
  final String? corpo;
  final Map<String, String> dados;

  const EventoPush({
    this.notificationId,
    this.type,
    this.urgente = false,
    this.titulo,
    this.corpo,
    this.dados = const {},
  });
}

abstract interface class ServicoPush {
  /// `null` quando a plataforma não tem push ou o usuário negou a
  /// permissão — quem chama cai no identificador local.
  Future<TokenPush?> obterToken();

  Stream<TokenPush> get tokenRenovado;

  /// Push que chegou com o app em primeiro plano.
  Stream<EventoPush> get recebidas;

  /// Toque do usuário numa notificação (sistema ou local).
  Stream<EventoPush> get abertas;

  /// Toque que abriu o app a frio. Devolve uma vez só.
  EventoPush? consumirAberturaInicial();
}

const _canalUrgente = AndroidNotificationChannel(
  'urgente',
  'Urgente',
  description: 'Contingência de código, cancelamento, chegada do entregador.',
  importance: Importance.max,
);

const _canalGeral = AndroidNotificationChannel(
  'geral',
  'Pedidos e avisos',
  description: 'Novos pedidos, contrapropostas, ganhos e suporte.',
  importance: Importance.high,
);

/// Obrigatório pelo `firebase_messaging`: função de topo, fora de
/// qualquer classe. Não faz nada — com `notification` no corpo, o
/// próprio sistema mostra o aviso; a inbox é recarregada quando o app
/// volta.
@pragma('vm:entry-point')
Future<void> _aoReceberEmSegundoPlano(RemoteMessage mensagem) async {}

bool get pushSuportado =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

class ServicoPushFirebase implements ServicoPush {
  final FlutterLocalNotificationsPlugin _locais =
      FlutterLocalNotificationsPlugin();
  final StreamController<EventoPush> _recebidas = StreamController.broadcast();
  final StreamController<EventoPush> _abertas = StreamController.broadcast();

  /// Toque que abriu o app a frio, entregue ao primeiro ouvinte — o
  /// navegador ainda não existe quando [iniciar] roda.
  EventoPush? _aberturaInicial;

  ServicoPushFirebase._();

  /// Inicializa Firebase, canais e ouvintes. Falha aqui nunca derruba
  /// o app: devolve `null` e o app segue sem push, só com a inbox.
  static Future<ServicoPushFirebase?> iniciar() async {
    if (!pushSuportado) return null;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(_aoReceberEmSegundoPlano);
      final servico = ServicoPushFirebase._();
      await servico._configurar();
      return servico;
    } on Object catch (erro) {
      debugPrint('[push] indisponível: $erro');
      return null;
    }
  }

  Future<void> _configurar() async {
    await _locais.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permissão é pedida pelo FirebaseMessaging depois do login,
        // não na abertura do app.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (resposta) =>
          _abertas.add(_eventoDePayload(resposta.payload)),
    );

    final android = _locais
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_canalUrgente);
    await android?.createNotificationChannel(_canalGeral);

    // iOS mostra o banner mesmo com o app aberto; Android não, por isso
    // lá a notificação local é disparada em `_aoChegarAberto`.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    FirebaseMessaging.onMessage.listen(_aoChegarAberto);
    FirebaseMessaging.onMessageOpenedApp.listen(
      (mensagem) => _abertas.add(_evento(mensagem)),
    );

    final inicial = await FirebaseMessaging.instance.getInitialMessage();
    if (inicial != null) {
      _aberturaInicial = _evento(inicial);
    } else {
      final lancamento = await _locais.getNotificationAppLaunchDetails();
      if (lancamento?.didNotificationLaunchApp ?? false) {
        _aberturaInicial = _eventoDePayload(
          lancamento!.notificationResponse?.payload,
        );
      }
    }
  }

  Future<void> _aoChegarAberto(RemoteMessage mensagem) async {
    final evento = _evento(mensagem);
    _recebidas.add(evento);

    if (defaultTargetPlatform != TargetPlatform.android) return;
    final canal = evento.urgente ? _canalUrgente : _canalGeral;
    await _locais.show(
      id: (evento.notificationId ?? mensagem.messageId ?? '').hashCode,
      title: evento.titulo,
      body: evento.corpo,
      payload: evento.notificationId,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          canal.id,
          canal.name,
          channelDescription: canal.description,
          importance: canal.importance,
          priority: evento.urgente ? Priority.max : Priority.high,
        ),
      ),
    );
  }

  @override
  Future<TokenPush?> obterToken() async {
    final mensageria = FirebaseMessaging.instance;
    final permissao = await mensageria.requestPermission();
    if (permissao.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }
    final token = await mensageria.getToken();
    if (token == null || token.isEmpty) return null;
    return TokenPush(token, _plataforma);
  }

  @override
  Stream<TokenPush> get tokenRenovado => FirebaseMessaging
      .instance
      .onTokenRefresh
      .map((token) => TokenPush(token, _plataforma));

  @override
  Stream<EventoPush> get recebidas => _recebidas.stream;

  @override
  Stream<EventoPush> get abertas => _abertas.stream;

  @override
  EventoPush? consumirAberturaInicial() {
    final inicial = _aberturaInicial;
    _aberturaInicial = null;
    return inicial;
  }

  static String get _plataforma =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  static EventoPush _evento(RemoteMessage mensagem) {
    final dados = mensagem.data.map(
      (chave, valor) => MapEntry(chave, '$valor'),
    );
    return EventoPush(
      notificationId: dados['notificationId'],
      type: dados['type'],
      urgente: dados['priority'] == 'urgent',
      titulo: mensagem.notification?.title,
      corpo: mensagem.notification?.body,
      dados: dados,
    );
  }

  static EventoPush _eventoDePayload(String? notificationId) =>
      EventoPush(notificationId: notificationId);
}
