import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sessao.dart';

/// ===============================================================
/// COFRE DA SESSÃO — RF-A02.4
/// ===============================================================
///
/// Credencial vai para o armazenamento cifrado do sistema — Keychain
/// no iOS, Keystore no Android. **`SharedPreferences` é proibido**:
/// é texto puro, legível em aparelho comprometido ou com backup
/// habilitado.
///
/// No **web** não existe equivalente real: o pacote cai em
/// `localStorage`, que qualquer script da página lê. Isso é aceitável
/// só em desenvolvimento — ver RNF-A02.3 e A-13.
abstract interface class CofreSessao {
  Future<Sessao?> ler();
  Future<void> gravar(Sessao sessao);
  Future<void> limpar();
}

class CofreSessaoSeguro implements CofreSessao {
  static const _chave = 'uaiou.sessao';

  final FlutterSecureStorage _armazenamento;

  CofreSessaoSeguro({FlutterSecureStorage? armazenamento})
    : _armazenamento =
          armazenamento ??
          const FlutterSecureStorage(
            // O padrão do Android já é AES-GCM com a chave protegida
            // no Keystore — não há o que endurecer aqui.
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              // Legível só depois do primeiro desbloqueio do
              // aparelho, e nunca sai em backup para outro aparelho.
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  @override
  Future<Sessao?> ler() async {
    try {
      return Sessao.deJsonTexto(await _armazenamento.read(key: _chave));
    } on Object {
      // Cofre indisponível ou conteúdo ilegível: trata como sem
      // sessão. Travar a abertura do app por causa disso seria pior.
      return null;
    }
  }

  @override
  Future<void> gravar(Sessao sessao) async {
    await _armazenamento.write(key: _chave, value: sessao.paraJsonTexto());
  }

  @override
  Future<void> limpar() async {
    await _armazenamento.delete(key: _chave);
  }
}

/// Cofre em memória, para teste.
class CofreSessaoEmMemoria implements CofreSessao {
  Sessao? _sessao;

  CofreSessaoEmMemoria([this._sessao]);

  @override
  Future<Sessao?> ler() async => _sessao;

  @override
  Future<void> gravar(Sessao sessao) async => _sessao = sessao;

  @override
  Future<void> limpar() async => _sessao = null;
}
