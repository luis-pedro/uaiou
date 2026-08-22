import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ===============================================================
/// IDENTIFICADOR DO DISPOSITIVO — RF-A11.1/RF-A11.2
/// ===============================================================
///
/// Web não tem token de push real (ver `controlador_notificacoes.dart`
/// para a limitação completa): não há FCM/APNs por trás. O que existe
/// é um identificador estável gerado uma vez por instalação do
/// navegador e reaproveitado — é o que o app manda como `pushToken`
/// em `POST /me/devices`, honesto sobre o que é: uma chave de sessão
/// do navegador, não um token de push capaz de receber notificação
/// com o app fechado.
///
/// Guarda também o `id` que o servidor devolveu no último registro
/// (`DeviceResponse.id`), para a baixa em `DELETE /me/devices/{id}`
/// no logout (RF-A11.2) — inclusive depois de reabrir o app, por isso
/// persiste em vez de viver só em memória.
abstract interface class IdentificadorDispositivo {
  /// Cria o identificador local na primeira chamada e devolve o mesmo
  /// valor nas seguintes.
  Future<String> obterOuCriarLocal();

  /// `id` do último registro aceito pelo servidor, ou `null` se não há
  /// dispositivo registrado no momento.
  Future<String?> lerRegistroAtual();

  Future<void> gravarRegistroAtual(String id);

  Future<void> limparRegistroAtual();
}

class IdentificadorDispositivoSeguro implements IdentificadorDispositivo {
  static const _chaveLocal = 'uaiou.dispositivo.id';
  static const _chaveRegistro = 'uaiou.dispositivo.registroId';

  final FlutterSecureStorage _armazenamento;

  IdentificadorDispositivoSeguro({FlutterSecureStorage? armazenamento})
    : _armazenamento = armazenamento ?? const FlutterSecureStorage();

  @override
  Future<String> obterOuCriarLocal() async {
    try {
      final existente = await _armazenamento.read(key: _chaveLocal);
      if (existente != null && existente.isNotEmpty) return existente;

      final novo = _gerarIdentificador();
      await _armazenamento.write(key: _chaveLocal, value: novo);
      return novo;
    } on Object {
      // Cofre indisponível: gera um identificador só para esta sessão
      // de memória. Não é ideal (não sobrevive a reload), mas não
      // impede o registro do dispositivo agora.
      return _gerarIdentificador();
    }
  }

  @override
  Future<String?> lerRegistroAtual() async {
    try {
      return await _armazenamento.read(key: _chaveRegistro);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> gravarRegistroAtual(String id) async {
    try {
      await _armazenamento.write(key: _chaveRegistro, value: id);
    } on Object {
      // Falha ao persistir o id do registro não pode travar o login.
    }
  }

  @override
  Future<void> limparRegistroAtual() async {
    try {
      await _armazenamento.delete(key: _chaveRegistro);
    } on Object {
      // Sem o que fazer: seguimos com o logout local mesmo assim.
    }
  }

  static String _gerarIdentificador() {
    final aleatorio = Random.secure();
    final bytes = List<int>.generate(16, (_) => aleatorio.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Em memória, para teste.
class IdentificadorDispositivoEmMemoria implements IdentificadorDispositivo {
  String? _local;
  String? _registro;

  @override
  Future<String> obterOuCriarLocal() async =>
      _local ??= 'dispositivo-teste-${identityHashCode(this)}';

  @override
  Future<String?> lerRegistroAtual() async => _registro;

  @override
  Future<void> gravarRegistroAtual(String id) async => _registro = id;

  @override
  Future<void> limparRegistroAtual() async => _registro = null;
}
