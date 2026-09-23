// lib/services/account_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'notification_service.dart';

class AccountService {
  static final AccountService _instance = AccountService._internal();
  factory AccountService() => _instance;
  AccountService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── google_sign_in v6.x: misma configuración que AuthService ───
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '287875927706-ut5514lnn65opqfbmldqcft1kv0ahbjp.apps.googleusercontent.com',
  );

  /// Con qué método inició sesión el usuario actual: 'password',
  /// 'google.com', u otro id de provider. Null si no hay sesión.
  String? get metodoLoginActual {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.providerData.isEmpty) return null;
    return user.providerData.first.providerId;
  }

  /// Reautentica al usuario con email y contraseña.
  /// Firebase exige un login reciente antes de poder borrar la cuenta.
  Future<void> reautenticar(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No hay un usuario con sesión iniciada');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  /// Reautentica al usuario que inició sesión con Google.
  /// Abre el selector de cuenta de Google; el usuario debe elegir
  /// la misma cuenta con la que inició sesión originalmente.
  Future<void> reautenticarConGoogle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No hay un usuario con sesión iniciada');
    }

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Reautenticación con Google cancelada');
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await user.reauthenticateWithCredential(credential);
  }

  /// Borra los datos del usuario en Firestore (perfil y recordatorios),
  /// cancela sus notificaciones locales y luego borra la cuenta en
  /// Firebase Authentication.
  ///
  /// Puede lanzar [FirebaseAuthException] con código 'requires-recent-login'
  /// si Firebase exige reautenticación; en ese caso, el llamador debe
  /// pedir la contraseña y usar [reautenticar] antes de reintentar.
  Future<void> eliminarCuenta() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No hay un usuario con sesión iniciada');
    }
    final uid = user.uid;

    try {
      await _borrarDatosFirestore(uid);
    } catch (e) {
      debugPrint('⚠️ No se pudieron borrar todos los datos de Firestore: $e');
      // No detenemos el flujo: preferimos borrar la cuenta aunque
      // la limpieza de datos falle parcialmente.
    }

    try {
      await NotificationService().cancelarTodas();
    } catch (e) {
      debugPrint('⚠️ No se pudieron cancelar las notificaciones: $e');
    }

    // Esta línea puede lanzar 'requires-recent-login'.
    await user.delete();
  }

  Future<void> _borrarDatosFirestore(String uid) async {
    // Borra la subcolección de recordatorios del usuario.
    final recordatorios = await _db
        .collection('usuarios')
        .doc(uid)
        .collection('recordatorios')
        .get();
    for (final doc in recordatorios.docs) {
      await doc.reference.delete();
    }

    // Borra el documento de perfil del usuario.
    await _db.collection('usuarios').doc(uid).delete();
  }
}