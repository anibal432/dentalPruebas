// lib/services/clinic_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dental_clinic.dart';

class ClinicService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'clinics';

  Future<List<DentalClinic>> getAllClinics() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection(_collection).get();
      return snapshot.docs.map((doc) => DentalClinic.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error al obtener clínicas: $e');
      return [];
    }
  }

  Future<List<DentalClinic>> getNearbyClinics({
    required double userLat,
    required double userLon,
    double radiusKm = 50,
  }) async {
    try {
      List<DentalClinic> allClinics = await getAllClinics();
      
      List<DentalClinic> nearbyClinics = allClinics.where((clinic) {
        double distance = clinic.calculateDistance(userLat, userLon);
        return distance <= radiusKm;
      }).toList();

      nearbyClinics.sort((a, b) {
        double distanceA = a.calculateDistance(userLat, userLon);
        double distanceB = b.calculateDistance(userLat, userLon);
        return distanceA.compareTo(distanceB);
      });

      return nearbyClinics;
    } catch (e) {
      debugPrint('Error al obtener clínicas cercanas: $e');
      return [];
    }
  }

  Future<List<DentalClinic>> searchClinicsByLocation({
    String? city,
    String? department,
  }) async {
    try {
      Query query = _firestore.collection(_collection);

      if (city != null && city.isNotEmpty) {
        query = query.where('city', isEqualTo: city);
      }

      if (department != null && department.isNotEmpty) {
        query = query.where('department', isEqualTo: department);
      }

      QuerySnapshot snapshot = await query.get();
      return snapshot.docs.map((doc) => DentalClinic.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error al buscar clínicas: $e');
      return [];
    }
  }

  Future<bool> addClinic(DentalClinic clinic) async {
    try {
      await _firestore.collection(_collection).add(clinic.toFirestore());
      return true;
    } catch (e) {
      debugPrint('Error al agregar clínica: $e');
      return false;
    }
  }

  Future<DentalClinic?> getClinicById(String id) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return DentalClinic.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error al obtener clínica: $e');
      return null;
    }
  }

  Stream<List<DentalClinic>> getClinicsStream() {
    return _firestore.collection(_collection).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => DentalClinic.fromFirestore(doc)).toList(),
    );
  }
}