// tip_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/dental_tip.dart';

class TipDetailScreen extends StatelessWidget {
  final DentalTip tip;

  const TipDetailScreen({super.key, required this.tip});

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'niños':
        return Colors.blue;
      case 'adultos':
        return Colors.green;
      case 'higiene':
        return Colors.purple;
      case 'prevención':
        return Colors.orange;
      case 'emergencias':
        return Colors.red;
      default:
        return Colors.teal;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'niños':
        return Icons.child_care;
      case 'adultos':
        return Icons.person;
      case 'higiene':
        return Icons.cleaning_services;
      case 'prevención':
        return Icons.health_and_safety;
      case 'emergencias':
        return Icons.medical_services;
      default:
        return Icons.tips_and_updates;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor(tip.category);
    final categoryIcon = _getCategoryIcon(tip.category);
    // ── formattedDate eliminado (fecha guardada en Firestore como bitácora) ──

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Detalle del Consejo'),
        backgroundColor: categoryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: categoryColor,
                boxShadow: [
                  BoxShadow(
                    color: categoryColor.withAlpha(76),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
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
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  // ── Fila de fecha eliminada de la UI ──
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(25),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      tip.description,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: categoryColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: categoryColor.withAlpha(76),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: categoryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Recuerda que estos consejos son de carácter informativo. Consulta siempre con tu dentista.',
                            style: TextStyle(
                              color: categoryColor.withAlpha(204),
                              fontSize: 14,
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