// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dental_tips_screen.dart';
import 'dental_scan_screen.dart';
import '../location/screens/smart_clinic_screen.dart';
import '../login/services/auth_service.dart';
import '../login/screens/login_screen.dart';
import '../dental_dictionary/screens/dental_dictionary_screen.dart';
import '../admin/services/role_service.dart';
import '../admin/widgets/admin_guard.dart';
// import '../admin/screens/admin_dashboard_screen.dart';

const Color _kPrimary      = Color(0xFF3D3D8F);
const Color _kPrimaryDark  = Color(0xFF2A2A6E);
const Color _kPrimaryLight = Color(0xFF5C5CAF);
const Color _kAccent       = Color(0xFF8888C8);
const Color _kSurface      = Color(0xFFF0F0FA);
const Color _kLightFill    = Color(0xFFD0D0F0);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<bool> _isAdminFuture = _checkIsAdmin();

  Future<bool> _checkIsAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final user = await RoleService().getCurrentUserData(uid);
    return user?.isAdmin ?? false;
  }

  void _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        RoleService().clearCache();
        await AuthService().signOut();
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cerrar sesión: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _openAdmin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminGuard(
          child: _AdminPlaceholder(),
          // child: AdminDashboardScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salud Dental'),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<bool>(
          future: _isAdminFuture,
          builder: (context, snap) {
            final isAdmin = snap.data ?? false;

            final cards = <Widget>[
              _MenuCard(
                title: 'Análisis con IA',
                icon: Icons.biotech_outlined,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DentalScanScreen())),
              ),
              _MenuCard(
                title: 'Consejos Dentales',
                icon: Icons.tips_and_updates_outlined,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DentalTipsScreen())),
              ),
              _MenuCard(
                title: 'Clínicas Cercanas',
                icon: Icons.location_on_outlined,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SmartClinicScreen())),
              ),
              _MenuCard(
                title: 'Diccionario Dental',
                icon: Icons.menu_book_outlined,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const DentalDictionaryScreen())),
              ),
              if (isAdmin) _AdminCard(onTap: () => _openAdmin(context)),
            ];

            return GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.95,
              children: cards,
            );
          },
        ),
      ),
    );
  }
}

// ── Card de administración ─────────────────────────────────────
class _AdminCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AdminCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: _kPrimaryDark.withAlpha(80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _kPrimaryDark,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withAlpha(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge "Admin" alineado arriba a la derecha
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withAlpha(60), width: 1),
                  ),
                  child: const Text(
                    'Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              // Ícono — misma estructura que _MenuCard
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withAlpha(50), width: 1),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Panel Admin',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Card normal ────────────────────────────────────────────────
class _MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: _kPrimary.withAlpha(40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kLightFill, width: 1),
                ),
                child: Icon(icon, size: 32, color: _kPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A3E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Placeholder hasta crear AdminDashboardScreen ───────────────
class _AdminPlaceholder extends StatelessWidget {
  const _AdminPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin'),
        backgroundColor: _kPrimaryDark,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 72, color: _kAccent),
            SizedBox(height: 12),
            Text(
              'Panel de administración',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _kPrimaryDark,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Próximo paso: estadísticas y exportación',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}