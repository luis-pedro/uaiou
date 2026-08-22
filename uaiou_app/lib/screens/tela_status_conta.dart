import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/documentos/estado_documentos.dart';
import 'package:uaiou/core/sessao/controlador_sessao.dart';
import 'package:uaiou/core/sessao/identidade.dart';
import 'package:uaiou/screens/widgets/lista_de_documentos.dart';

/// ===============================================================
/// CONTA SEM ACESSO À OPERAÇÃO — RF-A02.9
/// ===============================================================
///
/// Destino de quem autenticou mas tem `status != active`. Sem isto,
/// o usuário pendente cairia numa tela de operação vazia e sem
/// explicação.
///
/// ⚠️ A-04 (RF-A04.8) enriquece esta tela com o **estado de cada
/// documento** e o caminho de reenvio. Aqui ela apenas informa e
/// oferece saída.
class TelaStatusConta extends StatefulWidget {
  const TelaStatusConta({super.key});

  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  @override
  State<TelaStatusConta> createState() => _TelaStatusContaState();
}

class _TelaStatusContaState extends State<TelaStatusConta> {
  static const Color corPrincipal = TelaStatusConta.corPrincipal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EstadoDocumentos>().carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessao = context.watch<ControladorSessao>();
    final aparencia = _Aparencia.para(sessao.status, sessao.papel);

    /// Só faz sentido pedir documento de quem ainda está sendo
    /// avaliado. Conta suspensa ou banida não se resolve reenviando
    /// documento — resolve-se no suporte.
    final podeEnviarDocumentos =
        sessao.status == StatusConta.pendente ||
        sessao.status == StatusConta.rejeitado;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(aparencia.icone, size: 72, color: aparencia.cor),
                  const SizedBox(height: 24),
                  Text(
                    aparencia.titulo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(34, 34, 34, 1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    aparencia.descricao,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Color.fromRGBO(94, 94, 94, 1),
                    ),
                  ),
                  if (podeEnviarDocumentos) ...[
                    const SizedBox(height: 32),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Seus documentos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color.fromRGBO(34, 34, 34, 1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const ListaDeDocumentos(),
                  ],

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () async {
                        await context.read<ControladorSessao>().sair();
                        // Mesmo motivo do login: se esta tela veio da
                        // guarda de rota, ela está acima da raiz.
                        if (context.mounted) {
                          Navigator.of(
                            context,
                          ).popUntil((rota) => rota.isFirst);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: corPrincipal, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Sair da conta',
                        style: TextStyle(color: corPrincipal, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Aparencia {
  final IconData icone;
  final Color cor;
  final String titulo;
  final String descricao;

  const _Aparencia({
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.descricao,
  });

  static _Aparencia para(StatusConta status, Papel papel) {
    if (papel == Papel.admin) {
      return const _Aparencia(
        icone: Icons.desktop_windows_outlined,
        cor: Colors.blueGrey,
        titulo: 'Acesso pelo painel web',
        descricao:
            'Contas de administração são atendidas pelo painel web, '
            'não pelo aplicativo.',
      );
    }

    return switch (status) {
      StatusConta.pendente => const _Aparencia(
        icone: Icons.hourglass_top,
        cor: Colors.orange,
        titulo: 'Cadastro em análise',
        descricao:
            'Recebemos seus dados e estamos conferindo os documentos. '
            'Assim que a análise terminar, você poderá começar a usar o '
            'aplicativo.',
      ),
      StatusConta.rejeitado => const _Aparencia(
        icone: Icons.error_outline,
        cor: Colors.red,
        titulo: 'Cadastro não aprovado',
        descricao:
            'A análise apontou alguma pendência nos seus documentos. '
            'Você poderá reenviá-los para uma nova avaliação.',
      ),
      StatusConta.suspenso => const _Aparencia(
        icone: Icons.pause_circle_outline,
        cor: Colors.red,
        titulo: 'Conta suspensa',
        descricao:
            'Sua conta está temporariamente suspensa. Fale com o suporte '
            'para entender o motivo e o prazo.',
      ),
      StatusConta.banido => const _Aparencia(
        icone: Icons.block,
        cor: Colors.red,
        titulo: 'Conta bloqueada',
        descricao: 'Sua conta foi bloqueada. Fale com o suporte.',
      ),
      StatusConta.ativo || StatusConta.desconhecido => const _Aparencia(
        icone: Icons.help_outline,
        cor: Colors.grey,
        titulo: 'Não foi possível abrir o aplicativo',
        descricao:
            'Não conseguimos identificar o estado da sua conta. '
            'Entre novamente ou fale com o suporte.',
      ),
    };
  }
}
