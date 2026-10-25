import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:uaiou/core/cadastro/controlador_cadastro.dart';
import 'package:uaiou/core/cadastro/rascunho_cadastro.dart';
import 'package:uaiou/screens/widgets/campo_cadastro.dart';
import 'package:uaiou/screens/widgets/esqueleto_cadastro.dart';

class CadastroEntregador3 extends StatefulWidget {
  const CadastroEntregador3({super.key});

  @override
  State<CadastroEntregador3> createState() => _CadastroEntregador3State();
}

class _CadastroEntregador3State extends State<CadastroEntregador3> {
  bool _mostrarErros = false;

  bool esconderSenha = true;
  bool esconderConfirmacao = true;

  /// RF-A04.1 — o envio acontece só aqui, na confirmação final.
  Future<void> _concluir(
    BuildContext context,
    RascunhoCadastro rascunho,
  ) async {
    setState(() => _mostrarErros = true);
    if (!rascunho.passoValido(PassoCadastro.credenciais)) return;

    final controlador = context.read<ControladorCadastro>();
    final concluido = await controlador.concluir(rascunho);
    if (!context.mounted) return;

    if (concluido) {
      // A raiz observa a sessão e já mostra a tela de análise
      // (RF-A04.8); esta tela só precisa sair da pilha.
      Navigator.of(context).popUntil((rota) => rota.isFirst);
      return;
    }

    // RF-A04.4 — erro cuja origem é outro passo devolve o usuário
    // ao passo certo, em vez de falhar genericamente aqui.
    final falha = controlador.falha;
    if (falha?.passo != null && falha!.passo != PassoCadastro.credenciais) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rascunho = context.watch<RascunhoCadastro>();
    final cadastro = context.watch<ControladorCadastro>();
    final erros = _mostrarErros
        ? rascunho.validar(PassoCadastro.credenciais)
        : const <String, String>{};

    return EsqueletoCadastro(
      passo: 3,
      titulo: 'Crie seu acesso',
      subtitulo: 'É com este usuário e senha que você entra no app.',
      rotuloBotao: 'Criar conta',
      carregando: cadastro.enviando,
      aoAvancar: cadastro.enviando ? null : () => _concluir(context, rascunho),
      filhos: [
        CampoCadastro(
          rotulo: 'Usuário',
          exemplo: 'seu_usuario',
          valorInicial: rascunho.login,
          aoMudar: (v) => rascunho.login = v,
          erro: erros['Usuário'],
        ),

        const SizedBox(height: 14),
        CampoCadastro(
          rotulo: 'Senha',
          valorInicial: rascunho.senha,
          aoMudar: (v) => rascunho.senha = v,
          senha: true,
          erro: erros['Senha'],
        ),

        const SizedBox(height: 14),
        CampoCadastro(
          rotulo: 'Confirme a senha',
          valorInicial: rascunho.confirmacaoDeSenha,
          aoMudar: (v) => rascunho.confirmacaoDeSenha = v,
          senha: true,
          erro: erros['Confirme a senha'],
        ),

        const SizedBox(height: 15),

        // Erro do servidor, exibido como veio (RF-A04.3).
        if (cadastro.falha != null) AvisoDeErro(cadastro.falha!.mensagem),

        const SizedBox(height: 10),
      ],
    );
  }
}
