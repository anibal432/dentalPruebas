// lib/admin/models/app_user.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { user, admin }

class AppUser {
  final String uid;
  final String nombre;
  final String email;
  final UserRole role;

  const AppUser({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.role,
  });

  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      nombre: data['nombre'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] == 'admin' ? UserRole.admin : UserRole.user,
    );
  }
}