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
          .snapshots() // Temporalmente sin orderBy para evitar errores de índice
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
      DocumentSnapshot doc =
          await _firestore.collection(collection).doc(id).get();
      if (doc.exists) {
        return DentalTip.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error en getTipById: $e');
      return null;
    }
  }

  Future<void> addTip(DentalTip tip) async {
    try {
      await _firestore.collection(collection).add(tip.toMap());
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

      QuerySnapshot snapshot = await _firestore.collection(collection).get();
      debugPrint('📊 Documentos encontrados: ${snapshot.docs.length}');

      Set<String> categories = {};

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('category')) {
          String category = data['category'] as String;
          debugPrint('🏷️ Categoría encontrada: $category');
          categories.add(category);
        }
      }

      List<String> sortedCategories = categories.toList()..sort();
      debugPrint('✅ Categorías finales: $sortedCategories');

      return sortedCategories;
    } catch (e) {
      debugPrint('❌ Error en getCategories: $e');
      return [];
    }
  }
}
