import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// ===============================================================
/// CONFIGURAÇÃO DO FIREBASE — projeto `uaiou-19b9e`
/// ===============================================================
///
/// Mesmo conteúdo do `google-services.json` (Android) e do
/// `GoogleService-Info.plist` (iOS), passado em Dart para não depender
/// do plugin Gradle do Google Services nem de arquivo referenciado no
/// projeto Xcode. Estas chaves são identificadores públicos de cliente,
/// não segredo — o que protege o projeto são as regras do Firebase e a
/// conta de serviço, que só o backend tem.
///
/// Regerar com `flutterfire configure` se um app for recriado no console.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase não configurado para $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBEGYmHpvZFmJmaw6YHpiTQAe0rO1xI1QY',
    appId: '1:1046458349726:android:6cf5c6e1f939181ddd638f',
    messagingSenderId: '1046458349726',
    projectId: 'uaiou-19b9e',
    storageBucket: 'uaiou-19b9e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDBCvXr-EOTb2yvILdj8HbDi1PXZrA_dVo',
    appId: '1:1046458349726:ios:a008110a5fe24595dd638f',
    messagingSenderId: '1046458349726',
    projectId: 'uaiou-19b9e',
    storageBucket: 'uaiou-19b9e.firebasestorage.app',
    iosBundleId: 'com.uaiou.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDOPmELgZ7qLOo7Id0sFfTkjQInthg1w2k',
    appId: '1:1046458349726:web:35edafb9d64f4f03dd638f',
    messagingSenderId: '1046458349726',
    projectId: 'uaiou-19b9e',
    authDomain: 'uaiou-19b9e.firebaseapp.com',
    storageBucket: 'uaiou-19b9e.firebasestorage.app',
    measurementId: 'G-W3KLDV5NEH',
  );
}
