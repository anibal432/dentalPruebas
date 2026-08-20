// lib/models/feedback_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackItem {
  final String id;
  final String uid;
  final String nombre;
  final String mensaje;
  final int calificacion; // 1 a 5
  final DateTime fecha;

  FeedbackItem({
    required this.id,
    required this.uid,
    required this.nombre,
    required this.mensaje,
    required this.calificacion,
    required this.fecha,
  });

  factory FeedbackItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeedbackItem(
      id: doc.id,
      uid: data['uid'] ?? '',
      nombre: data['nombre'] ?? 'Usuario',
      mensaje: data['mensaje'] ?? '',
      calificacion: (data['calificacion'] ?? 5) as int,
      fecha: data['fecha'] != null
          ? (data['fecha'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'nombre': nombre,
        'mensaje': mensaje,
        'calificacion': calificacion,
      };
}