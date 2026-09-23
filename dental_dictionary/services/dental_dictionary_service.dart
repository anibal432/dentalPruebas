// lib/dental_dictionary/services/dental_dictionary_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/dental_dictionary_entry.dart';

class DentalDictionaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'dental_dictionary';

  Future<List<DentalDictionaryEntry>> getAllEntries() async {
    debugPrint('🔍 Intentando leer: $_collection');
    try {
      final snap = await _firestore
          .collection(_collection)
          .get(const GetOptions(source: Source.server));

      debugPrint('✅ Docs recibidos: ${snap.docs.length}');

      final entries = <DentalDictionaryEntry>[];
      for (final doc in snap.docs) {
        try {
          entries.add(DentalDictionaryEntry.fromFirestore(doc));
        } catch (e) {
          debugPrint('⚠️ Error parseando ${doc.id}: $e | data: ${doc.data()}');
        }
      }
      entries.sort((a, b) => a.title.compareTo(b.title));
      return entries;
    } on FirebaseException catch (e) {
      debugPrint('🔥 FirebaseException: code=${e.code} msg=${e.message}');
      rethrow;
    } catch (e, st) {
      debugPrint('❌ Error inesperado: $e\n$st');
      rethrow;
    }
  }

  Future<List<DentalDictionaryEntry>> getEntriesByCategory(
      String category) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('category', isEqualTo: category)
          .get(const GetOptions(source: Source.server));
      final entries =
          snap.docs.map(DentalDictionaryEntry.fromFirestore).toList();
      entries.sort((a, b) => a.title.compareTo(b.title));
      return entries;
    } on FirebaseException catch (e) {
      debugPrint('🔥 getByCategory: code=${e.code} msg=${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ getByCategory error: $e');
      rethrow;
    }
  }

  Future<List<String>> getCategories() async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .get(const GetOptions(source: Source.server));
      final cats = <String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data.containsKey('category')) cats.add(data['category'] as String);
      }
      return cats.toList()..sort();
    } catch (e) {
      debugPrint('❌ getCategories error: $e');
      return [];
    }
  }

  /// Agrega una entrada asignando automáticamente [createdAt] = ahora.
  /// El llamador NO necesita pasar la fecha; queda guardada en Firestore
  /// como bitácora sin mostrarse en la UI.
  Future<void> addEntry(DentalDictionaryEntry entry) async {
    final data = entry.toMap()
      // Sobrescribe con FieldValue.serverTimestamp() para usar
      // la hora del servidor de Firestore (más confiable que la del dispositivo).
      ..['createdAt'] = FieldValue.serverTimestamp();
    await _firestore.collection(_collection).add(data);
  }

  Future<void> updateEntry(String id, DentalDictionaryEntry entry) async =>
      await _firestore
          .collection(_collection)
          .doc(id)
          .update(entry.toMap());

  Future<void> deleteEntry(String id) async =>
      await _firestore.collection(_collection).doc(id).delete();
}