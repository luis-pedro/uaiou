import 'package:flutter/material.dart';

//TELAS PRINCIPAIS DE LOGIN
import 'package:uaiou/screens/principal_login.dart';
import 'package:uaiou/screens/login_screen.dart';
import 'package:uaiou/screens/tela_cadastro.dart';

//TELAS DE CADASTRO - ENTREGADOR
import 'package:uaiou/screens/tela_cadastro_entregador1.dart';
import 'package:uaiou/screens/tela_cadastro_entregador2.dart';
import 'package:uaiou/screens/tela_cadastro_entregador3.dart';

//TELAS DE CADASTRO - ESTABELECIMENTO
import 'package:uaiou/screens/tela_cadastro_estabelecimento1.dart';
import 'package:uaiou/screens/tela_cadastro_estabelecimento2.dart';
import 'package:uaiou/screens/tela_cadastro_estabelecimento3.dart';

//TELAS PRINCIPAIS - ENTREGADOR
import 'package:uaiou/screens/tela_principal_entregador.dart';
import 'package:uaiou/screens/tela_entregas_entregador.dart';

//TELAS PRINCIPAIS - ESTABELECIMENTO
import 'package:uaiou/screens/tela_principal_estabelecimento.dart';
import 'package:uaiou/screens/tela_estabelecimento_pedidos.dart';
import 'package:uaiou/screens/tela_atividade_estabelecimento.dart';
import 'package:uaiou/screens/tela_perfil_estabelecimento.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const PrincipalLogin(),

      routes: {
        // TELAS PRINCIPAIS DE LOGIN
        '/login': (context) => const LoginScreen(),
        '/cadastro': (context) => const TelaCadastro(),

        // TELAS DE CADASTRO
        // ENTREGADOR
        '/cadastro_entregador1': (context) => const CadastroEntregador1(),
        '/cadastro_entregador2': (context) => const CadastroEntregador2(),
        '/cadastro_entregador3': (context) => const CadastroEntregador3(),
        // ESTABELECIMENTO
        '/cadastro_estabelecimento1': (context) => const CadastroEstabelecimento1(),
        '/cadastro_estabelecimento2': (context) => const CadastroEstabelecimento2(),
        '/cadastro_estabelecimento3': (context) => const CadastroEstabelecimento3(),

        // TELAS PRINCIPAIS
        //ENTREGADOR
        '/principal_entregador': (context) => const TelaPrincipalEntregador(),
        '/entregas_entregador': (context) => const TelaEntregasEntregador(),

        //ESTABELECIMENTO
        '/principal_estabelecimento': (context) => const TelaPrincipalEstabelecimento(),
        '/pedidos_estabelecimento': (context) => const TelaPedidosEstabelecimento(),
        '/atividades_estabelecimento': (context) => const TelaAtividadesEstabelecimento(),
        '/perfil_estabelecimento': (context) => const TelaPerfilEstabelecimento(),
      },
    );
  }
}