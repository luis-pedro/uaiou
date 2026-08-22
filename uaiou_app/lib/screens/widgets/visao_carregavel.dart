import 'package:flutter/material.dart';

import 'package:uaiou/core/estado/carregavel.dart';

/// Renderiza os quatro caminhos de [Carregavel] — RF-A03.3.
///
/// Uma tela que use isto não tem como esquecer um estado.
class VisaoCarregavel<T> extends StatelessWidget {
  final Carregavel<T> estado;
  final Widget Function(T valor) construir;

  /// Chamado pelo botão de nova tentativa do estado de erro.
  final Future<void> Function() aoTentarNovamente;

  final String textoVazio;
  final IconData iconeVazio;

  const VisaoCarregavel({
    super.key,
    required this.estado,
    required this.construir,
    required this.aoTentarNovamente,
    this.textoVazio = 'Nada por aqui ainda',
    this.iconeVazio = Icons.inbox_outlined,
  });

  static const Color _corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  @override
  Widget build(BuildContext context) {
    return estado.quando(
      carregando: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: _corPrincipal),
        ),
      ),
      pronto: construir,
      vazio: () => _Aviso(
        icone: iconeVazio,
        cor: Colors.grey,
        titulo: textoVazio,
        // Vazio com motivo do servidor (ex.: LOCATION_STALE) explica
        // por que a lista veio vazia, em vez de deixar o usuário achar
        // que não há trabalho disponível.
        detalhe: switch (estado) {
          Vazio<T>(:final motivo) => motivo,
          _ => null,
        },
      ),
      falhou: (erro) => _Aviso(
        icone: Icons.cloud_off,
        cor: Colors.red,
        titulo: 'Não foi possível carregar',
        detalhe: erro.mensagemParaUsuario,
        aoTentarNovamente: aoTentarNovamente,
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String titulo;
  final String? detalhe;
  final Future<void> Function()? aoTentarNovamente;

  const _Aviso({
    required this.icone,
    required this.cor,
    required this.titulo,
    this.detalhe,
    this.aoTentarNovamente,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: cor),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color.fromRGBO(94, 94, 94, 1),
              ),
            ),
            if (detalhe != null) ...[
              const SizedBox(height: 8),
              Text(
                detalhe!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
            if (aoTentarNovamente != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: aoTentarNovamente,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: VisaoCarregavel._corPrincipal,
                  side: const BorderSide(color: VisaoCarregavel._corPrincipal),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
