import 'package:flutter/material.dart';
 
import 'package:uaiou/screens/principal_login.dart';
 
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}
 
class MyApp extends StatelessWidget {
  const MyApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PrincipalLogin(),
      routes: {
        '/principal_login':(context) => PrincipalLogin(),
      },
    );
  }
}
 
 