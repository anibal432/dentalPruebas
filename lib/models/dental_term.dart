// lib/models/dental_term.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DentalTerm {
  final String id;
  final String title;        // 'titulo'      en Firebase
  final String description;  // 'descripcion' en Firebase
  final String category;     // 'categoria'   en Firebase

  DentalTerm({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
  });

  factory DentalTerm.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    debugPrint('📄 Documento ${doc.id}: ${data.keys.toList()}');

    return DentalTerm(
      id:          doc.id,
      title:       data['titulo']       ?? data['title']       ?? 'Sin nombre',
      description: data['descripcion']  ?? data['description'] ?? '',
      category:    data['categoria']    ?? data['category']    ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'titulo':      title,
    'descripcion': description,
    'categoria':   category,
  };
}