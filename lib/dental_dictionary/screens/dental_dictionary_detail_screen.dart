// lib/dental_dictionary/screens/dental_dictionary_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/dental_dictionary_entry.dart';

// ─── Helpers locales (sin dependencia de otras pantallas) ───

Color _categoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'enfermedades comunes':
      return Colors.red;
    case 'procedimientos':
      return Colors.blue;
    case 'anatomía':
      return Colors.green;
    case 'ortodoncia':
      return Colors.orange;
    case 'higiene':
      return Colors.purple;
    case 'materiales':
      return Colors.brown;
    default:
      return Colors.teal;
  }
}

IconData _categoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'enfermedades comunes':
      return Icons.sick;
    case 'procedimientos':
      return Icons.medical_services;
    case 'anatomía':
      return Icons.biotech;
    case 'ortodoncia':
      return Icons.straighten;
    case 'higiene':
      return Icons.cleaning_services;
    case 'materiales':
      return Icons.science;
    default:
      return Icons.menu_book;
  }
}

// ───────────────────────────────────────────────────────────

class DentalDictionaryDetailScreen extends StatelessWidget {
  final DentalDictionaryEntry entry;

  const DentalDictionaryDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(entry.category);
    final icon = _categoryIcon(entry.category);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar colapsable ───────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: color,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withAlpha(204)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          shape: BoxShape.circle,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(20),
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
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  // ── Fecha eliminada de la UI (sigue guardándose en Firestore) ──
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 20),
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
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withAlpha(76), width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: color, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Este término es de carácter informativo, consulta siempre con un profesional dental.',
                            style: TextStyle(
                              color: color.withAlpha(204),
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