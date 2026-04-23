// lib/services/dental_tips_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/dental_tip.dart';

class DentalTipsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collection = 'dental_tips';

  Stream<List<DentalTip>> getAllTips() {
    try {
      return _firestore
          .collection(collection)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .handleError((error) {
        debugPrint('Error en getAllTips stream: $error');
      }).map((snapshot) {
        return snapshot.docs
            .map((doc) => DentalTip.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      debugPrint('Error en getAllTips: $e');
      return const Stream.empty();
    }
  }

  Stream<List<DentalTip>> getTipsByCategory(String category) {
    try {
      return _firestore
          .collection(collection)
          .where('category', isEqualTo: category)
          .snapshots()
          .handleError((error) {
        debugPrint('Error en getTipsByCategory stream: $error');
      }).map((snapshot) {
        return snapshot.docs
            .map((doc) => DentalTip.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      debugPrint('Error en getTipsByCategory: $e');
      return const Stream.empty();
    }
  }

  Future<DentalTip?> getTipById(String id) async {
    try {
      final doc = await _firestore.collection(collection).doc(id).get();
      if (doc.exists) return DentalTip.fromFirestore(doc);
      return null;
    } catch (e) {
      debugPrint('Error en getTipById: $e');
      return null;
    }
  }

  /// Agrega un consejo asignando [createdAt] con el reloj del servidor
  /// de Firestore. El llamador NO necesita pasar la fecha.
  Future<void> addTip(DentalTip tip) async {
    try {
      final data = tip.toMap()
        ..['createdAt'] = FieldValue.serverTimestamp();
      await _firestore.collection(collection).add(data);
    } catch (e) {
      debugPrint('Error en addTip: $e');
      rethrow;
    }
  }

  Future<void> updateTip(String id, DentalTip tip) async {
    try {
      await _firestore.collection(collection).doc(id).update(tip.toMap());
    } catch (e) {
      debugPrint('Error en updateTip: $e');
      rethrow;
    }
  }

  Future<void> deleteTip(String id) async {
    try {
      await _firestore.collection(collection).doc(id).delete();
    } catch (e) {
      debugPrint('Error en deleteTip: $e');
      rethrow;
    }
  }

  Future<List<String>> getCategories() async {
    try {
      debugPrint('🔍 Obteniendo categorías de Firestore...');
      final snapshot = await _firestore.collection(collection).get();
      debugPrint('📊 Documentos encontrados: ${snapshot.docs.length}');

      final categories = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('category')) {
          final cat = data['category'] as String;
          debugPrint('🏷️ Categoría encontrada: $cat');
          categories.add(cat);
        }
      }

      final sorted = categories.toList()..sort();
      debugPrint('✅ Categorías finales: $sorted');
      return sorted;
    } catch (e) {
      debugPrint('❌ Error en getCategories: $e');
      return [];
    }
  }
}