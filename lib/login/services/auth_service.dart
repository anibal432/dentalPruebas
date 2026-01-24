// lib/login/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // ✅ AGREGAR PARA debugPrint

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Iniciar sesión con email y contraseña
  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      debugPrint('Error en login: $e'); // ✅ CAMBIAR print POR debugPrint
      rethrow;
    }
  }

  // Registrar nuevo usuario
  Future<User?> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      debugPrint('Error en registro: $e'); // ✅ CAMBIAR print POR debugPrint
      rethrow;
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Verificar estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Obtener usuario actual
  User? get currentUser => _auth.currentUser;
}
