// lib/screens/account_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/account_service.dart';
import '../login/screens/login_screen.dart';

// ── Paleta institucional ──────────────────────────────────────
const Color _kPrimary     = Color(0xFF3D3D8F);
const Color _kPrimaryDark = Color(0xFF2A2A6E);
const Color _kSurface     = Color(0xFFF0F0FA);
const Color _kLightFill   = Color(0xFFD0D0F0);
const Color _kDanger      = Color(0xFFE74C3C);

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _service = AccountService();
  bool _eliminando = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  Future<void> _confirmarEliminacion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Esta acción es permanente. Se borrarán tu perfil, tus '
          'recordatorios y no podrás recuperar tu cuenta. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kDanger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    await _eliminarCuenta();
  }

  Future<void> _eliminarCuenta({String? password}) async {
    setState(() => _eliminando = true);
    try {
      if (password != null) {
        await _service.reautenticar(password);
      }
      await _service.eliminarCuenta();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        setState(() => _eliminando = false);
        if (_service.metodoLoginActual == 'google.com') {
          await _reautenticarConGoogleYReintentar();
        } else {
          await _pedirPasswordYReintentar();
        }
        return;
      }
      if (!mounted) return;
      setState(() => _eliminando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _eliminando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// Firebase exige un login reciente para poder borrar la cuenta.
  /// Pide la contraseña al usuario y reintenta el borrado.
  Future<void> _pedirPasswordYReintentar() async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Confirma tu contraseña'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Contraseña',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (password != null && password.isNotEmpty) {
      await _eliminarCuenta(password: password);
    }
  }

  /// Para usuarios que iniciaron sesión con Google: abre el selector
  /// de cuenta, reautentica y reintenta el borrado.
  Future<void> _reautenticarConGoogleYReintentar() async {
    setState(() => _eliminando = true);
    try {
      await _service.reautenticarConGoogle();
      await _eliminarCuenta();
    } catch (e) {
      if (!mounted) return;
      setState(() => _eliminando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo verificar tu cuenta de Google: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: const Text('Mi Cuenta'),
        backgroundColor: _kPrimaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kLightFill),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: _kPrimary,
                  child: Icon(Icons.person, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _user?.displayName ?? 'Usuario',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _user?.email ?? '',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Zona de peligro',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: _kDanger),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kDanger.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Al eliminar tu cuenta se borrarán permanentemente tu '
                  'perfil y tus recordatorios. Esta acción no se puede deshacer.',
                  style:
                      TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _eliminando ? null : _confirmarEliminacion,
                    icon: _eliminando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.delete_forever_outlined),
                    label:
                        Text(_eliminando ? 'Eliminando...' : 'Eliminar cuenta'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kDanger,
                      side: const BorderSide(color: _kDanger),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}