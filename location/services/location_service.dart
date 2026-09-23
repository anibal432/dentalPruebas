// lib/location/services/location_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../models/dental_clinic.dart';

class LocationService {
  static const double _guatemalaCityLat = 14.6349;
  static const double _guatemalaCityLng = -90.5069;

  // Ruta del JSON local de respaldo (ver assets en pubspec.yaml)
  static const String _localClinicsAsset =
      'assets/dental_clinics.json';

  // ── User-Agent obligatorio para APIs de OSM ────────────────
  static const String _userAgent =
      'DentalUMG/1.0 (aplicacion educativa Guatemala; contacto@dental-umg.edu)';

  // ── Servidores Overpass (fallback) ──────────────────────────
  static const List<String> _overpassUrls = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  // Cache en memoria del JSON local, para no releerlo en cada búsqueda
  List<DentalClinic>? _localClinicsCache;

  // ── Permisos ───────────────────────────────────────────────
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ GPS del dispositivo desactivado');
      return false;
    }
    PermissionStatus status = await Permission.locationWhenInUse.status;
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
      // Antes se intentaba primero getLastKnownPosition() (una ubicación en
      // caché, que puede ser de horas o días atrás) y solo si eso "fallaba"
      // se pedía la posición real — pero getLastKnownPosition() casi nunca
      // falla, así que en la práctica casi nunca se llegaba a pedir el GPS
      // actual. Ahora se intenta primero obtener la posición real; el
      // último conocido queda solo como respaldo si el GPS no responde a
      // tiempo.
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (e) {
        debugPrint('⚠️ GPS falló, se intenta con la última ubicación conocida: $e');
      }
      try {
        Position? last = await Geolocator.getLastKnownPosition();
        if (last != null) return last;
      } catch (_) {}
      return null;
    } catch (e) {
      debugPrint('❌ Error ubicación: $e');
      return null;
    }
  }

  Position getGuatemalaCityPosition() => Position(
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

  // ══════════════════════════════════════════════════════════
  // PUNTO DE ENTRADA PRINCIPAL
  // Se consultan SIEMPRE las 3 fuentes y se combinan sin duplicar:
  // Firestore + OSM (Nominatim x3, luego Overpass x3) + JSON local.
  // OSM aporta lo que encuentre (puede ser poco o nada); el JSON
  // local rellena lo que falte para esa zona sin reemplazar a OSM.
  // ══════════════════════════════════════════════════════════
  Future<List<DentalClinic>> findNearbyDentalClinics({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async {
    debugPrint(
        '🔍 Buscando clínicas: lat=$latitude, lon=$longitude, radio=${radiusKm}km');

    // 1. Firestore siempre se consulta en paralelo (clínicas registradas a mano)
    final firestoreFuture = _getFirestoreClinics(
        latitude: latitude, longitude: longitude, radiusKm: radiusKm);

    // 2. JSON local también se consulta siempre en paralelo (cubre lo que OSM no tenga)
    final localFuture = _searchLocalClinics(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    );

    // 3. OSM con reintentos: 3 intentos Nominatim, luego 3 intentos Overpass
    //    (lo que encuentre se suma; si no encuentra nada, no afecta al resto)
    final osmClinics = await _searchOSMWithRetries(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    );

    final firestoreClinics = await firestoreFuture;
    final localClinics = await localFuture;

    if (osmClinics.isEmpty) {
      debugPrint('⚠️ OSM no encontró clínicas, se usa solo Firestore + JSON local');
    }

    // 4. Siempre se combinan las tres fuentes, sin duplicar por nombre
    final combinadasOsmLocal = _mergeClinics(osmClinics, localClinics);
    return _mergeClinics(firestoreClinics, combinadasOsmLocal);
  }

  // ══════════════════════════════════════════════════════════
  // OSM CON REINTENTOS (3 Nominatim + 3 Overpass)
  // ══════════════════════════════════════════════════════════
  Future<List<DentalClinic>> _searchOSMWithRetries({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    // ── Fase 1: hasta 3 intentos contra Nominatim ──────────────
    for (int intento = 1; intento <= 3; intento++) {
      debugPrint('🌐 Nominatim intento $intento/3...');
      final resultado = await _searchNominatim(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
      );
      if (resultado.isNotEmpty) {
        debugPrint('✅ Nominatim respondió en el intento $intento');
        return resultado;
      }
      if (intento < 3) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    debugPrint('⚠️ Nominatim sin resultados tras 3 intentos, probando Overpass...');

    // ── Fase 2: hasta 3 intentos contra Overpass (1 por servidor) ─
    for (int i = 0; i < _overpassUrls.length; i++) {
      final url = _overpassUrls[i];
      debugPrint('🌐 Overpass intento ${i + 1}/3: $url');
      try {
        final clinics = await _performOverpassSearch(
          url: url,
          latitude: latitude,
          longitude: longitude,
          radiusKm: radiusKm,
        );
        if (clinics.isNotEmpty) {
          debugPrint('✅ Overpass respondió en el intento ${i + 1}');
          return clinics;
        }
      } catch (e) {
        debugPrint('❌ Overpass intento ${i + 1} falló: $e');
      }
      if (i < _overpassUrls.length - 1) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    debugPrint('❌ OSM agotó los 6 intentos (3 Nominatim + 3 Overpass)');
    return [];
  }

  // ══════════════════════════════════════════════════════════
  // NOMINATIM
  // ══════════════════════════════════════════════════════════
  Future<List<DentalClinic>> _searchNominatim({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    try {
      final bbox = _calculateBoundingBox(latitude, longitude, radiusKm);

      final dentistUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json'
        '&amenity=dentist'
        '&bounded=1'
        '&viewbox=${bbox['west']},${bbox['south']},${bbox['east']},${bbox['north']}'
        '&limit=50'
        '&addressdetails=1'
        '&extratags=1',
      );

      final response = await http.get(
        dentistUrl,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📥 Nominatim HTTP ${response.statusCode}');

      if (response.statusCode != 200) {
        return [];
      }

      final List<dynamic> data = json.decode(response.body);
      debugPrint('📦 Nominatim: ${data.length} resultados');

      if (data.isEmpty) return [];

      final clinics = <DentalClinic>[];
      for (final item in data) {
        try {
          final clinic = _clinicFromNominatim(item as Map<String, dynamic>);
          if (clinic == null) continue;
          final dist = _calculateDistance(
              latitude, longitude, clinic.latitude, clinic.longitude);
          clinics.add(clinic.copyWith(distanceInKm: dist));
        } catch (e) {
          debugPrint('  ⚠️ Error parseando item Nominatim: $e');
        }
      }

      clinics.sort((a, b) =>
          (a.distanceInKm ?? 0).compareTo(b.distanceInKm ?? 0));

      debugPrint('✅ Nominatim: ${clinics.length} clínicas válidas');
      return clinics;
    } catch (e) {
      debugPrint('❌ Nominatim falló: $e');
      return [];
    }
  }

  // Convierte un resultado de Nominatim a DentalClinic
  DentalClinic? _clinicFromNominatim(Map<String, dynamic> item) {
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    if (lat == null || lon == null) return null;
    if (lat == 0.0 && lon == 0.0) return null;

    final address = item['address'] as Map<String, dynamic>? ?? {};
    final extratags = item['extratags'] as Map<String, dynamic>? ?? {};

    final addressParts = <String>[];
    if (address['road'] != null) {
      String road = address['road'];
      if (address['house_number'] != null) {
        road = '$road ${address['house_number']}';
      }
      addressParts.add(road);
    }
    if (address['city'] != null) addressParts.add(address['city']);
    if (address['town'] != null && address['city'] == null) {
      addressParts.add(address['town']);
    }
    final addressStr = addressParts.isNotEmpty
        ? addressParts.join(', ')
        : item['display_name'] ?? 'Dirección no disponible';

    String name = item['name'] ?? '';
    if (name.isEmpty) {
      name = (item['display_name'] as String? ?? '').split(',').first.trim();
    }
    if (name.isEmpty) name = 'Clínica Dental';

    final services = <String>[];
    if (extratags['amenity'] == 'dentist') services.add('Odontología General');
    if (extratags['healthcare'] == 'dentist') services.add('Clínica Dental');
    if (extratags['emergency'] == 'yes') services.add('Emergencias');
    if (extratags['wheelchair'] == 'yes') services.add('Accesible');

    return DentalClinic(
      id: 'nominatim_${item['osm_id'] ?? item['place_id']}',
      name: name,
      address: addressStr,
      latitude: lat,
      longitude: lon,
      phone: extratags['phone'] ??
          extratags['contact:phone'] ??
          extratags['telephone'],
      email: extratags['email'] ?? extratags['contact:email'],
      website: extratags['website'] ??
          extratags['contact:website'] ??
          extratags['url'],
      openingHours: extratags['opening_hours'],
      services: services,
      city: address['city'] ?? address['town'] ?? address['municipality'],
      department: address['state'] ?? address['province'],
      osmType: item['osm_type'],
      osmId: int.tryParse(item['osm_id']?.toString() ?? ''),
      source: 'nominatim',
    );
  }

  // Calcula bounding box a partir de un punto central y radio en km
  Map<String, double> _calculateBoundingBox(
      double lat, double lon, double radiusKm) {
    final deltaLat = radiusKm / 111.0;
    final deltaLon = radiusKm / (111.0 * cos(lat * pi / 180));

    return {
      'north': lat + deltaLat,
      'south': lat - deltaLat,
      'east': lon + deltaLon,
      'west': lon - deltaLon,
    };
  }

  // ══════════════════════════════════════════════════════════
  // OVERPASS
  // ══════════════════════════════════════════════════════════
  Future<List<DentalClinic>> _performOverpassSearch({
    required String url,
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    final radiusMeters = (radiusKm * 1000).toInt();

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
out center tags;
''';

    final response = await http
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent': _userAgent,
            'Accept': 'application/json',
          },
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 429) throw Exception('Rate limit en $url');
    if (response.statusCode == 504) throw Exception('Gateway timeout en $url');
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} en $url');
    }
    if (response.body.isEmpty) throw Exception('Respuesta vacía desde $url');

    final Map<String, dynamic> data;
    try {
      data = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Respuesta no-JSON desde $url');
    }

    final elements = (data['elements'] as List?) ?? [];
    debugPrint('  📦 ${elements.length} elementos de Overpass');

    final clinics = <DentalClinic>[];
    for (final element in elements) {
      try {
        final el = _normalizeOverpassElement(element as Map<String, dynamic>);
        if (el == null) continue;
        final clinic = DentalClinic.fromOSM(el);
        if (clinic.latitude == 0.0 && clinic.longitude == 0.0) continue;
        final dist =
            _calculateDistance(latitude, longitude, clinic.latitude, clinic.longitude);
        if (dist <= radiusKm * 1.1) {
          clinics.add(clinic.copyWith(distanceInKm: dist));
        }
      } catch (e) {
        debugPrint('  ⚠️ Error parseando elemento Overpass: $e');
      }
    }

    clinics.sort((a, b) => (a.distanceInKm ?? 0).compareTo(b.distanceInKm ?? 0));
    return clinics;
  }

  Map<String, dynamic>? _normalizeOverpassElement(Map<String, dynamic> el) {
    final type = el['type'] as String?;
    if (type == 'node') {
      if (el['lat'] == null || el['lon'] == null) return null;
      return el;
    }
    if (type == 'way' || type == 'relation') {
      final center = el['center'] as Map<String, dynamic>?;
      if (center == null) return null;
      return {...el, 'lat': center['lat'], 'lon': center['lon']};
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════
  // JSON LOCAL (último recurso si OSM falla por completo)
  // ══════════════════════════════════════════════════════════
  Future<List<DentalClinic>> _loadLocalClinics() async {
    if (_localClinicsCache != null) return _localClinicsCache!;
    try {
      final raw = await rootBundle.loadString(_localClinicsAsset);
      final List<dynamic> data = json.decode(raw);
      final clinics = data.map((item) {
        final map = item as Map<String, dynamic>;
        return DentalClinic(
          id: map['id'] as String,
          name: map['name'] as String,
          address: map['address'] as String,
          latitude: (map['latitude'] as num).toDouble(),
          longitude: (map['longitude'] as num).toDouble(),
          phone: map['phone'] as String?,
          phoneNumber: map['phone'] as String?,
          services: List<String>.from(map['services'] ?? []),
          city: map['city'] as String?,
          department: map['department'] as String?,
          openingHours: map['openingHours'] as String?,
          source: 'local',
        );
      }).toList();
      _localClinicsCache = clinics;
      debugPrint('📂 JSON local cargado: ${clinics.length} clínicas');
      return clinics;
    } catch (e) {
      debugPrint('❌ Error cargando JSON local: $e');
      return [];
    }
  }

  Future<List<DentalClinic>> _searchLocalClinics({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    final all = await _loadLocalClinics();

    final withDistance = all.map((c) {
      final dist = _calculateDistance(latitude, longitude, c.latitude, c.longitude);
      return c.copyWith(distanceInKm: dist);
    }).where((c) => (c.distanceInKm ?? double.infinity) <= radiusKm).toList();

    withDistance.sort((a, b) => (a.distanceInKm ?? 0).compareTo(b.distanceInKm ?? 0));
    debugPrint('✅ JSON local: ${withDistance.length} clínicas dentro de ${radiusKm}km');
    return withDistance;
  }

  // ══════════════════════════════════════════════════════════
  // FIRESTORE (clínicas registradas manualmente)
  // ══════════════════════════════════════════════════════════
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
            source: 'firestore',
          ));
          debugPrint('🏥 Firestore: ${data['name']} (${dist.toStringAsFixed(2)} km)');
        }
      }
      return clinics;
    } catch (e) {
      debugPrint('⚠️ Error Firestore: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════
  // UTILIDADES
  // ══════════════════════════════════════════════════════════
  List<DentalClinic> _mergeClinics(
      List<DentalClinic> firestore, List<DentalClinic> otras) {
    final combined = <DentalClinic>[...firestore];

    for (final candidata in otras) {
      // Una clínica se considera "la misma" si ya hay una combinada
      // a menos de 120 metros de distancia. Esto es más confiable que
      // comparar nombres, porque distintas fuentes (Firestore, OSM,
      // JSON local) pueden escribir el mismo lugar con tildes, mayúsculas
      // u horarios distintos, pero las coordenadas reales no cambian.
      final esDuplicada = combined.any((existente) =>
          _calculateDistance(existente.latitude, existente.longitude,
                  candidata.latitude, candidata.longitude) <=
              0.12 // 120 metros
      );

      if (!esDuplicada) {
        combined.add(candidata);
      }
    }

    combined.sort((a, b) => (a.distanceInKm ?? 0).compareTo(b.distanceInKm ?? 0));
    debugPrint(
        '✅ Total combinadas: ${combined.length} (Firestore: ${firestore.length}, otras: ${otras.length})');
    return combined;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
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

  Stream<Position> getPositionStream() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
        ),
      );
}