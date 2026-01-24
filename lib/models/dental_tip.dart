//dental_tip.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DentalTip {
  final String id;
  final String category;
  final String title;
  final String description;
  final DateTime createdAt;

  DentalTip({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  // Crear desde Firestore
  factory DentalTip.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return DentalTip(
      id: doc.id,
      category: data['category'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // Convertir a Map para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'title': title,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
