// lib/admin/services/role_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';

class RoleService {
  static final RoleService _instance = RoleService._internal();
  factory RoleService() => _instance;
  RoleService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Cache en memoria para no releer Firestore en cada build
  AppUser? _cachedUser;

  Future<AppUser?> getCurrentUserData(String uid) async {
    // Si ya está en cache, regresa directo
    if (_cachedUser != null && _cachedUser!.uid == uid) {
      return _cachedUser;
    }
    try {
      final doc = await _db.collection('usuarios').doc(uid).get();
      if (!doc.exists) return null;
      _cachedUser = AppUser.fromFirestore(doc);
      return _cachedUser;
    } catch (e) {
      debugPrint('❌ RoleService error: $e');
      return null;
    }
  }

  // Llama esto al cerrar sesión para limpiar el cache
  void clearCache() => _cachedUser = null;

  // Útil para asignar admin manualmente desde la app (solo para pruebas)
  Future<void> setRole(String uid, UserRole role) async {
    await _db.collection('usuarios').doc(uid).update({
      'role': role == UserRole.admin ? 'admin' : 'user',
    });
    _cachedUser = null; // invalida cache
  }
}