import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/perfil/controlador_perfil.dart';
import 'package:uaiou/core/perfil/repositorio_perfil.dart';
import 'package:uaiou/core/sessao/identidade.dart';
import 'package:uaiou/screens/widgets/campo_cadastro.dart';
import 'package:uaiou/screens/widgets/mapa_endereco.dart';

/// Edição por `PATCH /me` (RF-A05.2) — só campos cosméticos que o
/// backend realmente aceita (`ProfileService.patchMe`): nome,
/// telefone e, para estabelecimento, endereço. CPF/CNPJ/veículo não
/// aparecem aqui: são campos verificados, exigem upload de
/// comprovação e reabrem moderação — fora do escopo desta tela.
class TelaEditarPerfil extends StatefulWidget {
  const TelaEditarPerfil({super.key});

  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  @override
  State<TelaEditarPerfil> createState() => _TelaEditarPerfilState();
}

class _TelaEditarPerfilState extends State<TelaEditarPerfil> {
  final _nome = TextEditingController();
  final _telefone = TextEditingController();
  final _bairro = TextEditingController();
  final _rua = TextEditingController();
  final _numero = TextEditingController();
  final _cidade = TextEditingController();
  final _cep = TextEditingController();

  bool _inicializado = false;
  bool _salvando = false;
  double? _lat;
  double? _lng;

  @override
  void dispose() {
    for (final controle in [_nome, _telefone, _bairro, _rua, _numero, _cidade, _cep]) {
      controle.dispose();
    }
    super.dispose();
  }

  void _inicializar(ControladorPerfil controlador) {
    if (_inicializado) return;
    final perfil = controlador.estado.valorOuNulo;
    if (perfil == null) return;

    _nome.text = perfil.nomeExibicao;
    _telefone.text = perfil.telefone ?? '';
    final endereco = perfil.detalhes?.endereco;
    if (endereco != null) {
      _bairro.text = endereco.bairro ?? '';
      _rua.text = endereco.rua ?? '';
      _numero.text = endereco.numero ?? '';
      _cidade.text = endereco.cidade ?? '';
      _cep.text = endereco.cep ?? '';
      _lat = endereco.lat;
      _lng = endereco.lng;
    }
    _inicializado = true;
  }

  Future<void> _salvar(BuildContext context, ControladorPerfil controlador) async {
    final perfil = controlador.estado.valorOuNulo;
    if (perfil == null) return;

    final ehEstabelecimento = perfil.papel == Papel.estabelecimento;

    final edicao = diffDeEdicao(
      original: perfil,
      nomeExibicao: _nome.text.trim(),
      telefone: _telefone.text.trim(),
      bairro: ehEstabelecimento ? _bairro.text.trim() : null,
      rua: ehEstabelecimento ? _rua.text.trim() : null,
      numero: ehEstabelecimento ? _numero.text.trim() : null,
      cidade: ehEstabelecimento ? _cidade.text.trim() : null,
      cep: ehEstabelecimento ? _cep.text.trim() : null,
      lat: ehEstabelecimento ? _lat : null,
      lng: ehEstabelecimento ? _lng : null,
    );

    if (edicao == null) {
      if (context.mounted) Navigator.pop(context);
      return;
    }

    setState(() => _salvando = true);
    final salvou = await controlador.salvar(edicao);
    if (!context.mounted) return;
    setState(() => _salvando = false);

    if (salvou) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(controlador.ultimoErro ?? 'Não foi possível salvar.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controlador = context.watch<ControladorPerfil>();
    _inicializar(controlador);

    final perfil = controlador.estado.valorOuNulo;
    final ehEstabelecimento = perfil?.papel == Papel.estabelecimento;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: TelaEditarPerfil.corPrincipal,
        foregroundColor: Colors.white,
        title: const Text('Editar perfil'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CampoCadastro(
                rotulo: 'Nome',
                valorInicial: _nome.text,
                aoMudar: (v) => _nome.text = v,
              ),
              const SizedBox(height: 12),
              CampoCadastro(
                rotulo: 'Telefone',
                valorInicial: _telefone.text,
                teclado: TextInputType.phone,
                aoMudar: (v) => _telefone.text = v,
              ),
              if (ehEstabelecimento) ...[
                const SizedBox(height: 24),
                const Text(
                  'Endereço',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                CampoCadastro(
                  rotulo: 'Rua',
                  valorInicial: _rua.text,
                  aoMudar: (v) => _rua.text = v,
                ),
                const SizedBox(height: 12),
                CampoCadastro(
                  rotulo: 'Número',
                  valorInicial: _numero.text,
                  aoMudar: (v) => _numero.text = v,
                ),
                const SizedBox(height: 12),
                CampoCadastro(
                  rotulo: 'Bairro',
                  valorInicial: _bairro.text,
                  aoMudar: (v) => _bairro.text = v,
                ),
                const SizedBox(height: 12),
                CampoCadastro(
                  rotulo: 'Cidade',
                  valorInicial: _cidade.text,
                  aoMudar: (v) => _cidade.text = v,
                ),
                const SizedBox(height: 12),
                CampoCadastro(
                  rotulo: 'CEP',
                  valorInicial: _cep.text,
                  aoMudar: (v) => _cep.text = v,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Ponto no mapa',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'É o ponto de referência para orientar a retirada dos pedidos — não substitui o endereço em texto acima.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                MapaEndereco(
                  latInicial: _lat,
                  lngInicial: _lng,
                  aoMudar: (ponto) => setState(() {
                    _lat = ponto.latitude;
                    _lng = ponto.longitude;
                  }),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _salvando ? null : () => _salvar(context, controlador),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TelaEditarPerfil.corPrincipal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _salvando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
