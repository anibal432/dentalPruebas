// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login/screens/login_screen.dart';
import 'screens/home_screen.dart'; // ✅ Asegúrate de importar HomeScreen
import 'login/services/auth_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
 
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase inicializado correctamente');
  } catch (e) {
    debugPrint('❌ Error inicializando Firebase: $e');
  }

  runApp(const DentalApp());
}

class DentalApp extends StatelessWidget {
  const DentalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dental AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.teal),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // ✅ CORREGIDO: Redirigir a HomeScreen en lugar de DentalTipsScreen
          return const HomeScreen();
        } else {
          // Usuario no autenticado
          return const LoginScreen();
        }
      },
    );
  }
}
