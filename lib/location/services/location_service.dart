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
  // ── Servidores Overpass (ordenados por fiabilidad) ─────────
  static const List<String> _overpassUrls = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  static const double _guatemalaCityLat = 14.6349;
  static const double _guatemalaCityLng = -90.5069;

  // ── Permisos ───────────────────────────────────────────────
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ GPS del dispositivo desactivado');
      return false;
    }

    PermissionStatus status = await Permission.locationWhenInUse.status;
    debugPrint('📋 Estado permiso: $status');

    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;

    status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  Future<bool> isPermissionPermanentlyDenied() async =>
      await Permission.locationWhenInUse.isPermanentlyDenied;

  // ── Ubicación actual ───────────────────────────────────────
  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await checkPermissions();
      if (!hasPermission) return null;

      try {
        Position? last = await Geolocator.getLastKnownPosition();
        if (last != null) return last;
      } catch (_) {}

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 8),
          ),
        );
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

  // ── Clínicas de Firestore ──────────────────────────────────
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
          clinics.add(DentalClinic(
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
          ));
          debugPrint('🏥 Firestore: ${data['name']} (${dist.toStringAsFixed(2)} km)');
        }
      }
      return clinics;
    } catch (e) {
      debugPrint('⚠️ Error Firestore clinics: $e');
      return [];
    }
  }

  // ── Punto de entrada principal ─────────────────────────────
  Future<List<DentalClinic>> findNearbyDentalClinics({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async {
    final results = await Future.wait([
      _findOSMClinics(
          latitude: latitude, longitude: longitude, radiusKm: radiusKm),
      _getFirestoreClinics(
          latitude: latitude, longitude: longitude, radiusKm: radiusKm),
    ]);

    final osmClinics = results[0];
    final firestoreClinics = results[1];

    final combined = <DentalClinic>[...firestoreClinics];
    final firestoreNames =
        firestoreClinics.map((c) => c.name.toLowerCase()).toSet();
    for (final c in osmClinics) {
      if (!firestoreNames.contains(c.name.toLowerCase())) {
        combined.add(c);
      }
    }

    combined.sort(
        (a, b) => (a.distanceInKm ?? 0).compareTo(b.distanceInKm ?? 0));
    debugPrint(
        '✅ Total combinadas: ${combined.length} (Firestore: ${firestoreClinics.length}, OSM: ${osmClinics.length})');
    return combined;
  }

  // ── Búsqueda OSM con radio progresivo ─────────────────────
  // Si el radio pedido no da resultados, lo duplica automáticamente.
  Future<List<DentalClinic>> _findOSMClinics({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    // Intentamos con el radio original y luego con el doble
    for (final double radio in [radiusKm, radiusKm * 2]) {
      final clinics = await _queryAllServers(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radio,
      );
      if (clinics.isNotEmpty) {
        debugPrint('✅ OSM: ${clinics.length} clínicas con radio ${radio}km');
        return clinics;
      }
      debugPrint('⚠️ OSM: sin resultados con radio ${radio}km, ampliando...');
    }
    debugPrint('❌ OSM: sin resultados con ningún radio');
    return [];
  }

  // ── Prueba cada servidor hasta obtener respuesta válida ────
  Future<List<DentalClinic>> _queryAllServers({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    for (int i = 0; i < _overpassUrls.length; i++) {
      final url = _overpassUrls[i];
      debugPrint('🌐 Probando servidor ${i + 1}/${_overpassUrls.length}: $url');
      try {
        final clinics = await _performSearch(
          url: url,
          latitude: latitude,
          longitude: longitude,
          radiusKm: radiusKm,
        );
        if (clinics.isNotEmpty) return clinics;
        // Si el servidor respondió pero sin resultados, probar el siguiente
        debugPrint('ℹ️ Servidor ${i + 1} respondió pero sin clínicas');
      } catch (e) {
        debugPrint('⚠️ Servidor ${i + 1} falló: $e');
        // Pequeña pausa antes de intentar el siguiente
        if (i < _overpassUrls.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    return [];
  }

  // ── Query Overpass (incluye node + way + relation) ─────────
  // FIX PRINCIPAL: la query anterior solo buscaba `node`,
  // lo que omitía clínicas registradas como `way` o `relation`.
  Future<List<DentalClinic>> _performSearch({
    required String url,
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    final radiusMeters = (radiusKm * 1000).toInt();

    // Query completa: nodes, ways y relations con amenity=dentist
    // o healthcare=dentist. `out center` hace que ways/relations
    // devuelvan un punto central, igual que los nodes.
    final query = '''
[out:json][timeout:25];
(
  node["amenity"="dentist"](around:$radiusMeters,$latitude,$longitude);
  way["amenity"="dentist"](around:$radiusMeters,$latitude,$longitude);
  relation["amenity"="dentist"](around:$radiusMeters,$latitude,$longitude);
  node["healthcare"="dentist"](around:$radiusMeters,$latitude,$longitude);
  way["healthcare"="dentist"](around:$radiusMeters,$latitude,$longitude);
  relation["healthcare"="dentist"](around:$radiusMeters,$latitude,$longitude);
);
out center;
''';

    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'data': query},
        )
        .timeout(
          // FIX: timeout aumentado a 30s (antes 12s era insuficiente)
          const Duration(seconds: 30),
          onTimeout: () => throw Exception('Timeout en $url'),
        );

    if (response.statusCode == 429) {
      throw Exception('Rate limit en $url');
    }
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} en $url');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final elements = (data['elements'] as List?) ?? [];

    debugPrint('📦 Overpass devolvió ${elements.length} elementos desde $url');

    final clinics = <DentalClinic>[];
    for (final element in elements) {
      try {
        // FIX: extraer coordenadas de `center` para ways/relations
        final el = _normalizeElement(element as Map<String, dynamic>);
        if (el == null) continue;

        final clinic = DentalClinic.fromOSM(el);
        final dist =
            _calculateDistance(latitude, longitude, clinic.latitude, clinic.longitude);

        if (dist <= radiusKm * 1.1) {
          // margen del 10% para evitar excluir clínicas en el límite
          clinics.add(clinic.copyWith(distanceInKm: dist));
        }
      } catch (e) {
        debugPrint('⚠️ Error parseando elemento: $e');
      }
    }

    clinics.sort(
        (a, b) => (a.distanceInKm ?? 0).compareTo(b.distanceInKm ?? 0));
    return clinics;
  }

  // ── Normalizar elemento OSM ────────────────────────────────
  // Para ways y relations, Overpass devuelve las coordenadas
  // dentro del campo `center` en lugar de en `lat`/`lon`.
  // Aquí las movemos al nivel raíz para que fromOSM() las encuentre.
  Map<String, dynamic>? _normalizeElement(Map<String, dynamic> element) {
    final type = element['type'] as String?;

    if (type == 'node') {
      // Los nodes ya tienen lat/lon directamente
      if (element['lat'] == null || element['lon'] == null) return null;
      return element;
    }

    if (type == 'way' || type == 'relation') {
      // ways y relations necesitan el campo `center`
      final center = element['center'] as Map<String, dynamic>?;
      if (center == null) return null;

      return {
        ...element,
        'lat': center['lat'],
        'lon': center['lon'],
      };
    }

    return null;
  }

  // ── Distancia Haversine ────────────────────────────────────
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

  // ── Utilidades ─────────────────────────────────────────────
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