// lib/screens/tip_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/dental_tip.dart';

// ── Paleta institucional ──────────────────────────────────────
const Color _kPrimaryDark  = Color(0xFF2A2A6E);
const Color _kPrimary      = Color(0xFF3D3D8F);
const Color _kPrimaryLight = Color(0xFF5C5CAF);
const Color _kLightFill    = Color(0xFFD0D0F0);
const Color _kSurface      = Color(0xFFF0F0FA);

class TipDetailScreen extends StatelessWidget {
  final DentalTip tip;

  const TipDetailScreen({super.key, required this.tip});

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'niños':
        return Icons.child_care;
      case 'adultos':
        return Icons.person_outline;
      case 'higiene':
      case 'higiene básica':
        return Icons.clean_hands_outlined;
      case 'prevención':
        return Icons.health_and_safety_outlined;
      case 'emergencias':
        return Icons.medical_services_outlined;
      case 'alimentación':
        return Icons.restaurant_outlined;
      default:
        return Icons.tips_and_updates_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryIcon = _getCategoryIcon(tip.category);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Detalle del Consejo'),
        backgroundColor: _kPrimaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header con gradiente institucional ────────────
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kPrimaryDark, _kPrimary, _kPrimaryLight],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(categoryIcon, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tip.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Contenido ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Título ───────────────────────────────────
                  Text(
                    tip.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      color: Color(0xFF1A1A3E),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: _kLightFill),
                  const SizedBox(height: 24),

                  // ── Cuerpo de la descripción ─────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kLightFill),
                      boxShadow: [
                        BoxShadow(
                          color: _kPrimary.withAlpha(15),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      tip.description,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.7,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Nota informativa ─────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kLightFill),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            color: _kPrimaryLight, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Recuerda que estos consejos son de carácter '
                            'informativo. Consulta siempre con tu dentista.',
                            style: TextStyle(
                              color: _kPrimaryLight,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}