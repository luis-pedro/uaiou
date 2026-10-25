import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/cadastro/rascunho_cadastro.dart';
import 'package:uaiou/core/sessao/identidade.dart';

import 'package:uaiou/core/tema/cores.dart';

/// ===============================================================
/// ESQUELETO DOS PASSOS DO CADASTRO
/// ===============================================================
///
/// Decisões vindas dos relatórios do Lazyweb sobre o fluxo de criar conta:
/// - a trilha mostra as três etapas **e a análise** que vem depois, para
///   ninguém descobrir a espera só no fim;
/// - o botão de avançar fica fixo no rodapé e sobe com o teclado — antes
///   ele ficava no fim da rolagem, escondido atrás do teclado;
/// - sem link "Voltar" competindo com o avanço: a seta do topo já volta;
/// - sair no primeiro passo pede confirmação, para não perder o que foi
///   digitado por um toque sem querer.
class EsqueletoCadastro extends StatelessWidget {
  const EsqueletoCadastro({
    super.key,
    required this.passo,
    required this.titulo,
    required this.filhos,
    required this.rotuloBotao,
    required this.aoAvancar,
    this.subtitulo,
    this.carregando = false,
    this.confirmarSaida = false,
  });

  /// 1, 2 ou 3.
  final int passo;
  final String titulo;
  final String? subtitulo;
  final List<Widget> filhos;
  final String rotuloBotao;
  final VoidCallback? aoAvancar;
  final bool carregando;
  final bool confirmarSaida;

  Future<bool> _podeSair(BuildContext context) async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Sair do cadastro?'),
        content: const Text(
          'O que você já preencheu fica guardado enquanto o app estiver aberto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Continuar cadastro'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    return sair ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final tela = Scaffold(
      // O tipo de conta fica no topo de todos os passos: quem está no meio
      // do cadastro nunca fica em dúvida sobre qual conta está criando.
      appBar: AppBar(
        centerTitle: true,
        title: _TituloDaConta(papel: context.watch<RascunhoCadastro>().papel),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil(
              (rota) => rota.settings.name == '/cadastro' || rota.isFirst,
            ),
            child: const Text('Trocar'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: IndicadorEtapasCadastro(passo: passo),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: cores.texto,
                        ),
                      ),
                      if (subtitulo != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitulo!,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            color: cores.textoSuave,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ...filhos,
                    ],
                  ),
                ),
                // Fixo no rodapé: o corpo encolhe com o teclado, então o
                // botão fica sempre visível logo acima dele.
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  decoration: BoxDecoration(
                    color: cores.fundo,
                    border: Border(top: BorderSide(color: cores.borda)),
                  ),
                  child: ElevatedButton(
                    onPressed: carregando ? null : aoAvancar,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: carregando
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(rotuloBotao),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!confirmarSaida) return tela;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (saiu, _) async {
        if (saiu) return;
        if (await _podeSair(context) && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: tela,
    );
  }
}

/// Trilha "Dados → Perfil → Acesso → Análise". A análise aparece desde o
/// primeiro passo: quem cria conta precisa saber que vai esperar aprovação.
class IndicadorEtapasCadastro extends StatelessWidget {
  const IndicadorEtapasCadastro({super.key, required this.passo});

  final int passo;

  static const _rotulos = ['Seus dados', 'Perfil', 'Acesso', 'Análise'];

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Row(
      children: [
        for (var i = 0; i < _rotulos.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < passo
                        ? CoresUaiou.principal
                        : CoresUaiou.principal.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _rotulos[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: i == passo - 1
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: i == passo - 1
                        ? CoresUaiou.principal
                        : cores.textoSuave,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Explicação curta abaixo de um campo sensível (CPF, nascimento).
class DicaDeCampo extends StatelessWidget {
  const DicaDeCampo(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 14,
            color: context.cores.textoSuave,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 12, color: context.cores.textoSuave),
            ),
          ),
        ],
      ),
    );
  }
}

class _TituloDaConta extends StatelessWidget {
  const _TituloDaConta({required this.papel});

  final Papel papel;

  @override
  Widget build(BuildContext context) {
    final entregador = papel == Papel.entregador;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: CoresUaiou.principal.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entregador ? 'Conta de entregador' : 'Conta de estabelecimento',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: CoresUaiou.principal,
            ),
          ),
        ],
      ),
    );
  }
}
