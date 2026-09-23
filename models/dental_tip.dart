// dental_tip.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DentalTip {
  final String id;
  final String category;
  final String title;
  final String description;

  /// Se guarda en Firestore como bitácora pero NO se muestra en la UI.
  final DateTime createdAt;

  DentalTip({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory DentalTip.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DentalTip(
      id: doc.id,
      category: data['category'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      // Fallback para documentos antiguos sin el campo.
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'title': title,
      'description': description,
      // Siempre se persiste en Firestore para bitácora.
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}