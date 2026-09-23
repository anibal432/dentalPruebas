// lib/dental_dictionary/screens/dental_dictionary_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/dental_dictionary_entry.dart';

// ── Paleta institucional unificada ────────────────────────────
const Color _kPrimaryDark  = Color(0xFF2A2A6E);
const Color _kPrimary      = Color(0xFF3D3D8F);
const Color _kPrimaryLight = Color(0xFF5C5CAF);
const Color _kAccent       = Color(0xFF8888C8);
const Color _kLightFill    = Color(0xFFD0D0F0);
const Color _kSurface      = Color(0xFFF0F0FA);

Color _categoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'enfermedades comunes':
      return _kPrimary;
    case 'procedimientos':
      return _kPrimaryDark;
    case 'anatomía':
    case 'anatomía dental':
      return _kPrimaryLight;
    case 'ortodoncia':
      return _kAccent;
    case 'higiene':
      return _kPrimary;
    case 'materiales':
      return _kPrimaryDark;
    case 'tratamientos dentales':
    case 'tratamientos':
      return _kPrimaryLight;
    default:
      return _kPrimary;
  }
}

IconData _categoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'enfermedades comunes':
      return Icons.sick_outlined;
    case 'procedimientos':
      return Icons.medical_services_outlined;
    case 'anatomía':
    case 'anatomía dental':
      return Icons.biotech_outlined;
    case 'ortodoncia':
      return Icons.straighten;
    case 'higiene':
      return Icons.clean_hands_outlined;
    case 'materiales':
      return Icons.science_outlined;
    case 'tratamientos dentales':
    case 'tratamientos':
      return Icons.healing_outlined;
    default:
      return Icons.menu_book_outlined;
  }
}

class DentalDictionaryDetailScreen extends StatelessWidget {
  final DentalDictionaryEntry entry;

  const DentalDictionaryDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(entry.category);
    final icon  = _categoryIcon(entry.category);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar colapsable ───────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            // ✅ Color institucional en lugar de turquesa
            backgroundColor: _kPrimaryDark,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  // ✅ Gradiente institucional azul/morado
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kPrimaryDark, _kPrimary, _kPrimaryLight],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      // ── Avatar con inicial ──────────────────
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withAlpha(80),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            entry.title.isNotEmpty
                                ? entry.title[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ── Badge de categoría ──────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withAlpha(60),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              entry.category,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Contenido ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Título ────────────────────────────────
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      color: Color(0xFF1A1A3E),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: _kLightFill),
                  const SizedBox(height: 20),

                  // ── Encabezado "Definición" ───────────────
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Definición',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A3E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Cuerpo de la definición ───────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kLightFill),
                    ),
                    child: Text(
                      entry.description,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.7,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Nota informativa ──────────────────────
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
                            'Este término es de carácter informativo, '
                            'consulta siempre con un profesional dental.',
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
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}