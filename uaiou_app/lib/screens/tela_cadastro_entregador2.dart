import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uaiou/screens/widgets/mascara_entrada.dart';

import 'package:provider/provider.dart';

import 'package:uaiou/core/cadastro/rascunho_cadastro.dart';
import 'package:uaiou/screens/widgets/campo_cadastro.dart';
import 'package:uaiou/screens/widgets/esqueleto_cadastro.dart';

class CadastroEntregador2 extends StatefulWidget {
  const CadastroEntregador2({super.key});

  @override
  State<CadastroEntregador2> createState() => _CadastroEntregador2State();
}

class _CadastroEntregador2State extends State<CadastroEntregador2> {
  /// Só mostra erro depois da primeira tentativa de avançar —
  /// marcar campo vazio em vermelho antes de digitar é hostil.
  bool _mostrarErros = false;

  void _avancar(BuildContext context, RascunhoCadastro rascunho) {
    if (!rascunho.passoValido(PassoCadastro.perfil)) {
      setState(() => _mostrarErros = true);
      return;
    }
    Navigator.pushNamed(context, '/cadastro_entregador3');
  }

  @override
  Widget build(BuildContext context) {
    final rascunho = context.watch<RascunhoCadastro>();
    final erros = _mostrarErros
        ? rascunho.validar(PassoCadastro.perfil)
        : const <String, String>{};

    return EsqueletoCadastro(
      passo: 2,
      titulo: 'Sua moto e seu endereço',
      subtitulo:
          'A placa identifica você para o estabelecimento na hora da coleta.',
      rotuloBotao: 'Continuar',
      aoAvancar: () => _avancar(context, rascunho),
      filhos: [
        CampoCadastro(
          rotulo: 'Placa do veículo',
          exemplo: 'ABC1D23',
          mascara: const [MascaraPlaca()],
          valorInicial: rascunho.placa,
          aoMudar: (v) => rascunho.placa = v,
          erro: erros['Placa do veículo'],
        ),

        const SizedBox(height: 14),
        CampoCadastro(
          rotulo: 'Rua',
          exemplo: 'Rua Beija-Flor',
          valorInicial: rascunho.rua,
          aoMudar: (v) => rascunho.rua = v,
          erro: erros['Rua'],
        ),

        const SizedBox(height: 14),
        CampoCadastro(
          rotulo: 'Endereço',
          exemplo: 'Apto, bloco, referência',
          valorInicial: rascunho.enderecoComplemento,
          aoMudar: (v) => rascunho.enderecoComplemento = v,
          erro: erros['Endereço'],
        ),

        const SizedBox(height: 14),
        CampoCadastro(
          rotulo: 'Número',
          exemplo: '45',
          mascara: [FilteringTextInputFormatter.digitsOnly],
          valorInicial: rascunho.numero,
          aoMudar: (v) => rascunho.numero = v,
          teclado: TextInputType.number,
          erro: erros['Número'],
        ),

        const SizedBox(height: 14),
        CampoCadastro(
          rotulo: 'Cidade',
          exemplo: 'Santa Rita do Sapucaí',
          valorInicial: rascunho.cidade,
          aoMudar: (v) => rascunho.cidade = v,
          erro: erros['Cidade'],
        ),

        const SizedBox(height: 35),
      ],
    );
  }
}
