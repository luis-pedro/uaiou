import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/cadastro/rascunho_cadastro.dart';
import 'package:uaiou/core/sessao/identidade.dart';
import 'package:uaiou/screens/widgets/campo_cadastro.dart';
import 'package:uaiou/screens/widgets/esqueleto_cadastro.dart';
import 'package:uaiou/screens/widgets/mascara_entrada.dart';

/// Passo 1 do cadastro: dados pessoais. O tipo de conta já foi escolhido na
/// tela de identidade (`TelaCadastro`) e aparece no topo de cada passo.
class TelaCadastroDados extends StatefulWidget {
  const TelaCadastroDados({super.key});

  @override
  State<TelaCadastroDados> createState() => _TelaCadastroDadosState();
}

class _TelaCadastroDadosState extends State<TelaCadastroDados> {
  /// Só mostra erro depois da primeira tentativa de avançar —
  /// marcar campo vazio em vermelho antes de digitar é hostil.
  bool _mostrarErros = false;

  void _avancar(RascunhoCadastro rascunho) {
    if (!rascunho.passoValido(PassoCadastro.dadosPessoais)) {
      setState(() => _mostrarErros = true);
      return;
    }
    Navigator.pushNamed(
      context,
      rascunho.papel == Papel.entregador
          ? '/cadastro_entregador2'
          : '/cadastro_estabelecimento2',
    );
  }

  @override
  Widget build(BuildContext context) {
    final rascunho = context.watch<RascunhoCadastro>();
    final erros = _mostrarErros
        ? rascunho.validar(PassoCadastro.dadosPessoais)
        : const <String, String>{};

    return EsqueletoCadastro(
      passo: 1,
      titulo: 'Seus dados',
      subtitulo: 'Leva uns 2 minutos. Depois a gente analisa seu cadastro.',
      rotuloBotao: 'Continuar',
      confirmarSaida: true,
      aoAvancar: () => _avancar(rascunho),
      filhos: [
        CampoCadastro(
          rotulo: 'Nome completo',
          exemplo: 'Como está no documento',
          valorInicial: rascunho.nome,
          aoMudar: (v) => rascunho.nome = v,
          erro: erros['Nome'],
        ),
        const SizedBox(height: 14),
        CampoCadastro(
          rotulo: 'E-mail',
          exemplo: 'voce@email.com',
          valorInicial: rascunho.email,
          aoMudar: (v) => rascunho.email = v,
          teclado: TextInputType.emailAddress,
          erro: erros['Email'],
        ),
        const SizedBox(height: 14),
        CampoCadastro(
          rotulo: 'Celular',
          exemplo: '(35) 99999-9999',
          mascara: [MascaraEntrada.telefone],
          valorInicial: rascunho.telefone,
          aoMudar: (v) => rascunho.telefone = v,
          teclado: TextInputType.phone,
          erro: erros['Telefone'],
        ),
        const SizedBox(height: 14),
        CampoCadastro(
          rotulo: 'Data de nascimento',
          exemplo: '31/12/1990',
          mascara: [MascaraEntrada.data],
          valorInicial: rascunho.dataNascimento,
          aoMudar: (v) => rascunho.dataNascimento = v,
          teclado: TextInputType.number,
          erro: erros['Data de nascimento'],
        ),
        const SizedBox(height: 14),
        CampoCadastro(
          rotulo: 'CPF',
          exemplo: '000.000.000-00',
          mascara: [MascaraEntrada.cpf],
          valorInicial: rascunho.cpf,
          aoMudar: (v) => rascunho.cpf = v,
          teclado: TextInputType.number,
          erro: erros['CPF'],
        ),
        const DicaDeCampo(
          'CPF e nascimento servem só para a análise do cadastro. '
          'Ninguém mais vê esses dados.',
        ),
      ],
    );
  }
}
