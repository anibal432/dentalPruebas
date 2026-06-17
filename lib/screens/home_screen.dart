// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'dental_tips_screen.dart';
import 'dental_scan_screen.dart';
import '../location/screens/smart_clinic_screen.dart'; // ← usa la pantalla inteligente
import '../login/services/auth_service.dart';
import '../login/screens/login_screen.dart';
import '../dental_dictionary/screens/dental_dictionary_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _logout(BuildContext context) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content:
              const Text('¿Estás seguro que deseas cerrar sesión?'),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );

    if (confirm == true && context.mounted) {
      try {
        final authService = AuthService();
        await authService.signOut();
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Error al cerrar sesión: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dental AI'),
        backgroundColor:const Color(0xFF3D3D8F),
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
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.95,
          children: [
            _MenuCard(
              title: 'Análisis con IA',
              icon: Icons.biotech,
              color: const Color(0xFF3D3D8F),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const DentalScanScreen()),
              ),
            ),
            _MenuCard(
              title: 'Consejos Dentales',
              icon: Icons.tips_and_updates,
              color: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const DentalTipsScreen()),
              ),
            ),
            _MenuCard(
              title: 'Clínicas Cercanas',
              icon: Icons.location_on,
              color: Colors.green,
              // Abre SmartClinicScreen sin diagnóstico (modo normal)
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const SmartClinicScreen(),
                ),
              ),
            ),
            _MenuCard(
              title: 'Diccionario Dental',
              icon: Icons.menu_book,
              color: Colors.deepPurple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const DentalDictionaryScreen()),
              ),
            ),
            _MenuCard(
              title: 'Recordatorios',
              icon: Icons.notifications,
              color: Colors.orange,
              onTap: () => _showMessage(context, 'Próximamente'),
            ),
            _MenuCard(
              title: 'Mi Perfil',
              icon: Icons.person,
              color: Colors.purple,
              onTap: () => _showMessage(context, 'Próximamente'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2)),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(51),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}