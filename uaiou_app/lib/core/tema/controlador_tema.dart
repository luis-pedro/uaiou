import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ===============================================================
/// ESCOLHA DE TEMA
/// ===============================================================
///
/// O app segue o sistema por padrão — quem entrega à noite já fez essa escolha
/// uma vez. O que este controlador acrescenta é a exceção: quem quer o app
/// escuro num aparelho claro (ou o contrário) diz isso uma vez e o app lembra.
///
/// Guardado no mesmo cofre da sessão porque é o armazenamento que o app já tem;
/// não é segredo, e perder a preferência não quebra nada — daí o silêncio nas
/// falhas de leitura e escrita.
class ControladorTema extends ChangeNotifier {
  static const _chave = 'uaiou.tema';

  final FlutterSecureStorage _armazenamento;

  ControladorTema({FlutterSecureStorage? armazenamento})
    : _armazenamento = armazenamento ?? const FlutterSecureStorage();

  ThemeMode _modo = ThemeMode.system;
  ThemeMode get modo => _modo;

  /// Chamado na abertura do app, antes da primeira tela aparecer, para não
  /// haver um piscar de claro antes do escuro escolhido.
  Future<void> carregar() async {
    try {
      final guardado = await _armazenamento.read(key: _chave);
      final modo = _doTexto(guardado);
      if (modo != _modo) {
        _modo = modo;
        notifyListeners();
      }
    } on Object {
      // Cofre indisponível: segue o sistema, como se nunca tivesse escolhido.
    }
  }

  Future<void> definir(ThemeMode modo) async {
    if (modo == _modo) return;
    _modo = modo;
    notifyListeners();
    try {
      await _armazenamento.write(key: _chave, value: _paraTexto(modo));
    } on Object {
      // A tela já mudou; não conseguir lembrar é menos grave que travar a troca.
    }
  }

  /// Texto do botão no perfil — diz o que está valendo agora.
  String get rotulo => switch (_modo) {
    ThemeMode.light => 'Tema: claro',
    ThemeMode.dark => 'Tema: escuro',
    ThemeMode.system => 'Tema: do sistema',
  };

  static String _paraTexto(ThemeMode modo) => switch (modo) {
    ThemeMode.light => 'claro',
    ThemeMode.dark => 'escuro',
    ThemeMode.system => 'sistema',
  };

  static ThemeMode _doTexto(String? valor) => switch (valor) {
    'claro' => ThemeMode.light,
    'escuro' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
