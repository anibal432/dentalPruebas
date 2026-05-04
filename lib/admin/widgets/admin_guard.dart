// lib/admin/widgets/admin_guard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/role_service.dart';

// Paleta institucional
const Color _kPrimary     = Color(0xFF3D3D8F);
const Color _kPrimaryDark = Color(0xFF2A2A6E);

/// Envuelve cualquier pantalla admin.
/// Si el usuario NO es admin, muestra pantalla de acceso denegado.
class AdminGuard extends StatelessWidget {
  final Widget child;
  const AdminGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const _AccessDenied();

    return FutureBuilder(
      future: RoleService().getCurrentUserData(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: _kPrimary),
            ),
          );
        }
        final user = snapshot.data;
        if (user == null || !user.isAdmin) {
          return const _AccessDenied();
        }
        return child;
      },
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso restringido'),
        backgroundColor: _kPrimaryDark,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'No tienes permisos de administrador',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}