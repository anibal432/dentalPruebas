// lib/location/services/location_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../models/dental_clinic.dart';

class LocationService {
  static const List<String> _overpassUrls = [
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass-api.de/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  int _currentServerIndex = 0;

  static const double _guatemalaCityLat = 14.6349;
  static const double _guatemalaCityLng = -90.5069;

  String get _currentServer => _overpassUrls[_currentServerIndex];

  void _rotateServer() {
    _currentServerIndex = (_currentServerIndex + 1) % _overpassUrls.length;
  }

  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ GPS del dispositivo desactivado');
      return false;
    }

    PermissionStatus status = await Permission.locationWhenInUse.status;
    debugPrint('📋 Estado permiso: $status');

    if (status.isGranted) {
      debugPrint('✅ Permiso ya concedido');
      return true;
    }

    if (status.isPermanentlyDenied) {
      debugPrint('❌ Permiso denegado permanentemente — abrir configuración');
      return false;
    }

    debugPrint('📋 Solicitando permiso al usuario...');
    status = await Permission.locationWhenInUse.request();
    debugPrint('📋 Respuesta: $status');

    return status.isGranted;
  }

  Future<bool> isPermissionPermanentlyDenied() async {
    return await Permission.locationWhenInUse.isPermanentlyDenied;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await checkPermissions();
      if (!hasPermission) {
        debugPrint('❌ Sin permiso de ubicación');
        return null;
      }

      try {
        Position? last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          debugPrint('✅ Última ubicación: ${last.latitude}, ${last.longitude}');
          return last;
        }
      } catch (_) {}

      try {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );
        debugPrint('✅ GPS: ${position.latitude}, ${position.longitude}');
        return position;
      } catch (e) {
        debugPrint('⚠️ GPS falló: $e');
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return null;
    }
  }

  Position getGuatemalaCityPosition() {
    return Position(
      latitude: _guatemalaCityLat,
      longitude: _guatemalaCityLng,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }

  // ─── NUEVO: obtener clínicas registradas en Firestore ────────────────────
  Future<List<DentalClinic>> _getFirestoreClinics({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('registered_clinics')
          .where('active', isEqualTo: true)
          .get();

      final clinics = <DentalClinic>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final lat = (data['latitude'] as num?)?.toDouble() ?? 0;
        final lng = (data['longitude'] as num?)?.toDouble() ?? 0;
        final dist = _calculateDistance(latitude, longitude, lat, lng);

        if (dist <= radiusKm) {
          final clinic = DentalClinic(
            id: doc.id,
            name: data['name'] ?? 'Clínica Dental',
            address: data['address'] ?? 'Dirección no disponible',
            latitude: lat,
            longitude: lng,
            phone: data['phone'],
            email: data['email'],
            description: data['description'],
            services: List<String>.from(data['services'] ?? []),
            website: data['website'],
            openingHours: data['openingHours'],
            city: data['city'],
            department: data['department'],
            rating: (data['rating'] as num?)?.toDouble(),
            distanceInKm: dist,
          );
          clinics.add(clinic);
          debugPrint('🏥 Clínica Firestore encontrada: ${clinic.name} (${dist.toStringAsFixed(2)} km)');
        }
      }
      return clinics;
    } catch (e) {
      debugPrint('⚠️ Error obteniendo clínicas de Firestore: $e');
      return [];
    }
  }

  // ─── Busca en OSM + Firestore y combina resultados ───────────────────────
  Future<List<DentalClinic>> findNearbyDentalClinics({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async {
    // Lanzamos ambas consultas en paralelo
    final results = await Future.wait([
      _findOSMClinics(latitude: latitude, longitude: longitude, radiusKm: radiusKm),
      _getFirestoreClinics(latitude: latitude, longitude: longitude, radiusKm: radiusKm),
    ]);

    final osmClinics = results[0];
    final firestoreClinics = results[1];

    // Firestore primero, luego OSM (sin duplicados por nombre)
    final combined = <DentalClinic>[];
    combined.addAll(firestoreClinics);

    final firestoreNames = firestoreClinics.map((c) => c.name.toLowerCase()).toSet();
    for (final c in osmClinics) {
      if (!firestoreNames.contains(c.name.toLowerCase())) {
        combined.add(c);
      }
    }

    combined.sort((a, b) => (a.distanceInKm ?? 0).compareTo(b.distanceInKm ?? 0));
    debugPrint('✅ Total clínicas combinadas: ${combined.length} '
        '(Firestore: ${firestoreClinics.length}, OSM: ${osmClinics.length})');
    return combined;
  }

  Future<List<DentalClinic>> _findOSMClinics({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    for (double radio in [radiusKm, radiusKm * 2]) {
      try {
        List<DentalClinic> clinics = await _searchWithRetry(
          latitude: latitude,
          longitude: longitude,
          radiusKm: radio,
        );
        if (clinics.isNotEmpty) return clinics;
      } catch (e) {
        debugPrint('⚠️ Error radio ${radio}km: $e');
      }
    }
    return [];
  }

  Future<List<DentalClinic>> _searchWithRetry({
    required double latitude,
    required double longitude,
    required double radiusKm,
    int maxRetries = 2,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          _rotateServer();
          await Future.delayed(const Duration(seconds: 1));
        }
        List<DentalClinic> clinics = await _performSearch(
          latitude: latitude,
          longitude: longitude,
          radiusKm: radiusKm,
        );
        if (clinics.isNotEmpty) return clinics;
      } catch (e) {
        debugPrint('⚠️ Intento ${attempt + 1} falló: $e');
        if (attempt == maxRetries - 1) rethrow;
      }
    }
    return [];
  }

  Future<List<DentalClinic>> _performSearch({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    int radiusMeters = (radiusKm * 1000).toInt();

    String query = '''
      [out:json][timeout:10];
      (
        node["amenity"="dentist"](around:$radiusMeters,$latitude,$longitude);
        node["healthcare"="dentist"](around:$radiusMeters,$latitude,$longitude);
      );
      out body;
    ''';

    final response = await http.post(
      Uri.parse(_currentServer),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'data': query},
    ).timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw Exception('Timeout'),
    );

    if (response.statusCode != 200) {
      throw Exception('Error HTTP ${response.statusCode}');
    }

    final data = json.decode(response.body);
    final List elements = data['elements'] ?? [];

    List<DentalClinic> clinics = [];
    for (var element in elements) {
      try {
        DentalClinic clinic = DentalClinic.fromOSM(element);
        double distance = _calculateDistance(
            latitude, longitude, clinic.latitude, clinic.longitude);
        if (distance <= radiusKm) {
          clinics.add(clinic.copyWith(distanceInKm: distance));
        }
      } catch (_) {
        continue;
      }
    }

    clinics.sort((a, b) =>
        (a.distanceInKm ?? 0).compareTo(b.distanceInKm ?? 0));
    debugPrint('✅ OSM: ${clinics.length} clínicas encontradas');
    return clinics;
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return earthRadius * 2 * asin(sqrt(a));
  }

  double _toRadians(double degree) => degree * pi / 180;

  String getGoogleMapsUrl(double lat, double lng) =>
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  Future<void> openAppSettings() async => await Geolocator.openAppSettings();

  Future<bool> isLocationServiceEnabled() async =>
      await Geolocator.isLocationServiceEnabled();

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      ),
    );
  }
}