// lib/login/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../admin/services/stats_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Email y contraseña ────────────────────────────────────
  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (result.user != null) {
        await _registrarUsuario(result.user!, metodoLogin: 'password');
      }
      return result.user;
    } catch (e) {
      debugPrint('Error en login: $e');
      rethrow;
    }
  }

  Future<User?> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (result.user != null) {
        await _registrarUsuario(result.user!, metodoLogin: 'password');
      }
      return result.user;
    } catch (e) {
      debugPrint('Error en registro: $e');
      rethrow;
    }
  }

  // ── Recuperación de contraseña ────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('✅ Email de recuperación enviado a $email');
    } catch (e) {
      debugPrint('Error enviando email de recuperación: $e');
      rethrow;
    }
  }

  // ── Google Sign-In ────────────────────────────────────────
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      if (result.user != null) {
        await _registrarUsuario(result.user!, metodoLogin: 'google.com');
      }
      return result.user;
    } catch (e) {
      debugPrint('Error en Google Sign-In: $e');
      rethrow;
    }
  }

  // ── Registro en Firestore + inicio cronómetro ─────────────
  Future<void> _registrarUsuario(
    User user, {
    required String metodoLogin,
  }) async {
    try {
      final docRef = _db.collection('usuarios').doc(user.uid);
      final doc    = await docRef.get();
      final ahora  = FieldValue.serverTimestamp();

      if (!doc.exists) {
        await docRef.set({
          'uid':           user.uid,
          'nombre':        user.displayName ?? 'Sin nombre',
          'email':         user.email ?? '',
          'foto':          user.photoURL ?? '',
          'metodoLogin':   metodoLogin,
          'role':          'user',
          'primerIngreso': ahora,
          'ultimoIngreso': ahora,
          'totalIngresos': 1,
        });
        debugPrint('✅ Nuevo usuario registrado en Firestore');
      } else {
        await docRef.update({
          'ultimoIngreso': ahora,
          'totalIngresos': FieldValue.increment(1),
          if (user.displayName != null) 'nombre': user.displayName,
          if (user.photoURL    != null) 'foto':   user.photoURL,
        });
        debugPrint('✅ Ingreso registrado');
      }

      // Inicia el cronómetro de sesión
      StatsService().iniciarSesion();
    } catch (e) {
      debugPrint('Error registrando usuario en Firestore: $e');
    }
  }

  // ── Cerrar sesión ─────────────────────────────────────────
  Future<void> signOut() async {
    await StatsService().registrarSalida(); // guarda minutos antes de salir
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
}