import 'package:flutter/material.dart';
import 'package:uaiou/screens/principal_login.dart';
import 'package:uaiou/screens/login_screen.dart';
import 'package:uaiou/screens/tela_cadastro.dart';

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
        '/login': (context) => const LoginScreen(),
        '/cadastro': (context) => const TelaCadastro(),
      },
    );
  }
}