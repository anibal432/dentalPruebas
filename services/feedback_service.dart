// lib/services/feedback_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/feedback_item.dart';

class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'feedback';

  Future<void> enviarFeedback({
    required String uid,
    required String nombre,
    required String mensaje,
    required int calificacion,
  }) async {
    try {
      await _db.collection(_collection).add({
        'uid': uid,
        'nombre': nombre,
        'mensaje': mensaje,
        'calificacion': calificacion,
        'fecha': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error en enviarFeedback: $e');
      rethrow;
    }
  }

  /// Stream de todo el feedback, del más reciente al más antiguo.
  /// Pensado para un futuro panel de administración.
  Stream<List<FeedbackItem>> streamTodoElFeedback() {
    return _db
        .collection(_collection)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FeedbackItem.fromFirestore(d)).toList())
        .handleError((e) => debugPrint('❌ streamTodoElFeedback error: $e'));
  }

  /// Stream del feedback enviado por un usuario específico.
  Stream<List<FeedbackItem>> streamMiFeedback(String uid) {
    return _db
        .collection(_collection)
        .where('uid', isEqualTo: uid)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FeedbackItem.fromFirestore(d)).toList())
        .handleError((e) => debugPrint('❌ streamMiFeedback error: $e'));
  }
}