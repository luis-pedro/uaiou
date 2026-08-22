import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/documentos/estado_documentos.dart';
import 'package:uaiou/screens/widgets/lista_de_documentos.dart';

/// Documentos do cadastro, acessível a partir do perfil mesmo depois
/// de aprovado (RF-A05.7) — `tela_status_conta.dart` só mostra isto
/// enquanto a conta está `pending`/`rejected`.
class TelaDocumentos extends StatefulWidget {
  const TelaDocumentos({super.key});

  static const Color corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  @override
  State<TelaDocumentos> createState() => _TelaDocumentosState();
}

class _TelaDocumentosState extends State<TelaDocumentos> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EstadoDocumentos>().carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: TelaDocumentos.corPrincipal,
        foregroundColor: Colors.white,
        title: const Text('Documentos'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: const ListaDeDocumentos(),
        ),
      ),
    );
  }
}
