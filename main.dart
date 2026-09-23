// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login/screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'login/services/auth_service.dart';
import 'services/notification_service.dart';

// ── Colores institucionales globales ─────────────────────────
const Color kPrimary = Color(0xFF3D3D8F);
const Color kPrimaryLight = Color(0xFF5C5CAF);
const Color kPrimaryDark = Color(0xFF2A2A6E);

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

  // ── Inicializar notificaciones locales ─────────────────────
  try {
    final notificationService = NotificationService();

    await notificationService.init();

    debugPrint('✅ Notificaciones locales inicializadas');
  } catch (e) {
    debugPrint('❌ Error con las notificaciones: $e');
  }

  runApp(const DentalApp());
}

class DentalApp extends StatelessWidget {
  const DentalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App_AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimary,
          primary: kPrimary,
          secondary: kPrimaryLight,
          surface: Colors.white,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF0FAF9),

        // ── AppBar ────────────────────────────────────────────
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
        ),

        // ── ElevatedButton ────────────────────────────────────
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            shadowColor: kPrimary.withAlpha(100),
          ),
        ),

        // ── OutlinedButton ────────────────────────────────────
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kPrimary,
            side: const BorderSide(color: kPrimary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // ── TextButton ────────────────────────────────────────
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: kPrimary,
          ),
        ),

        // ── InputDecoration (TextFields) ──────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: kPrimary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
        ),

        // ── FloatingActionButton ──────────────────────────────
        floatingActionButtonTheme:
            const FloatingActionButtonThemeData(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
        ),

        // ── ProgressIndicator ─────────────────────────────────
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: kPrimary,
        ),

        // ── Chip (FilterChip) ─────────────────────────────────
        chipTheme: ChipThemeData(
          selectedColor: kPrimary.withAlpha(40),
          checkmarkColor: kPrimary,
          labelStyle: const TextStyle(fontSize: 13),
          backgroundColor: Colors.grey.shade100,
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
              child: CircularProgressIndicator(
                color: kPrimary,
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}