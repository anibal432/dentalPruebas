// lib/services/location_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/dental_clinic.dart';

class LocationService {
  // Overpass API - Servicio gratuito para consultar datos de OpenStreetMap
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';
  
  // Ubicación por defecto: Guatemala City
  static const double _guatemalaCityLat = 14.6349;
  static const double _guatemalaCityLng = -90.5069;

  /// Verificar y solicitar permisos de ubicación
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ Servicios de ubicación deshabilitados');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('❌ Permisos de ubicación denegados');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('❌ Permisos de ubicación denegados permanentemente');
      return false;
    }

    debugPrint('✅ Permisos de ubicación concedidos');
    return true;
  }

  /// Obtener ubicación actual del usuario
  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await checkPermissions();
      if (!hasPermission) {
        debugPrint('⚠️ Usando ubicación simulada de Guatemala City');
        return _getSimulatedPosition();
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      debugPrint('📍 Ubicación real obtenida: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('⚠️ Error obteniendo ubicación, usando simulada: $e');
      return _getSimulatedPosition();
    }
  }

  /// Posición simulada para pruebas
  Position _getSimulatedPosition() {
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

  /// Buscar clínicas dentales cercanas usando OpenStreetMap (Overpass API)
  Future<List<DentalClinic>> findNearbyDentalClinics({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async {
    try {
      debugPrint('🔍 Buscando clínicas dentales en OSM');
      debugPrint('📍 Ubicación: $latitude, $longitude');
      debugPrint('📏 Radio: ${radiusKm}km');

      // Convertir radio de km a metros para Overpass
      int radiusMeters = (radiusKm * 1000).toInt();

      // Query de Overpass para buscar clínicas dentales
      String query = '''
        [out:json][timeout:25];
        (
          node["amenity"="dentist"](around:$radiusMeters,$latitude,$longitude);
          way["amenity"="dentist"](around:$radiusMeters,$latitude,$longitude);
          relation["amenity"="dentist"](around:$radiusMeters,$latitude,$longitude);
          node["healthcare"="dentist"](around:$radiusMeters,$latitude,$longitude);
          way["healthcare"="dentist"](around:$radiusMeters,$latitude,$longitude);
          node["name"~"[Dd]ental"](around:$radiusMeters,$latitude,$longitude);
          way["name"~"[Dd]ental"](around:$radiusMeters,$latitude,$longitude);
        );
        out center;
      ''';

      debugPrint('🌐 Consultando Overpass API...');

      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': query},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout al consultar Overpass API');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List elements = data['elements'] ?? [];

        debugPrint('📊 Respuesta de Overpass: ${elements.length} elementos encontrados');

        if (elements.isEmpty) {
          debugPrint('⚠️ No se encontraron clínicas dentales en el radio especificado');
          return [];
        }

        List<DentalClinic> clinics = [];

        for (var element in elements) {
          try {
            DentalClinic clinic = DentalClinic.fromOSM(element);
            
            // Calcular distancia
            double distance = _calculateDistance(
              latitude, 
              longitude, 
              clinic.latitude, 
              clinic.longitude
            );

            // Agregar clínica con distancia
            clinics.add(clinic.copyWith(distanceInKm: distance));

            debugPrint('   ✓ ${clinic.name} - ${distance.toStringAsFixed(2)}km');
          } catch (e) {
            debugPrint('⚠️ Error procesando elemento de OSM: $e');
          }
        }

        // Ordenar por distancia
        clinics.sort((a, b) => 
          (a.distanceInKm ?? 0).compareTo(b.distanceInKm ?? 0)
        );

        debugPrint('🏥 Total clínicas procesadas: ${clinics.length}');
        return clinics;

      } else {
        debugPrint('❌ Error HTTP: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error buscando clínicas en OSM: $e');
      debugPrint('Stack: $stackTrace');
      return [];
    }
  }

  /// Buscar clínicas en una ciudad específica
  Future<List<DentalClinic>> findClinicsInCity(String cityName) async {
    try {
      debugPrint('🔍 Buscando clínicas dentales en: $cityName');

      String query = '''
        [out:json][timeout:25];
        area["name"="$cityName"]["admin_level"~"[68]"]->.searchArea;
        (
          node["amenity"="dentist"](area.searchArea);
          way["amenity"="dentist"](area.searchArea);
          node["healthcare"="dentist"](area.searchArea);
          way["healthcare"="dentist"](area.searchArea);
        );
        out center;
      ''';

      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': query},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List elements = data['elements'] ?? [];

        List<DentalClinic> clinics = [];
        for (var element in elements) {
          try {
            clinics.add(DentalClinic.fromOSM(element));
          } catch (e) {
            debugPrint('⚠️ Error procesando elemento: $e');
          }
        }

        debugPrint('🏥 Clínicas encontradas en $cityName: ${clinics.length}');
        return clinics;
      }

      return [];
    } catch (e) {
      debugPrint('❌ Error buscando clínicas en ciudad: $e');
      return [];
    }
  }

  /// Calcular distancia entre dos puntos (fórmula de Haversine)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = 
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);
    
    final double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  /// Obtener URL de Google Maps para navegación
  String getGoogleMapsUrl(double lat, double lng) {
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  }

  /// Abrir configuración de permisos de la app
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Verificar si los servicios de ubicación están habilitados
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Obtener la última ubicación conocida
  Future<Position?> getLastKnownLocation() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      debugPrint('⚠️ No hay última ubicación conocida: $e');
      return null;
    }
  }

  /// Stream para escuchar cambios de ubicación en tiempo real
  Stream<Position> getPositionStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}