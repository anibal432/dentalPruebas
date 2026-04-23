// lib/models/dental_clinic.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class DentalClinic {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? phone;
  final String? email;
  final String? description;
  final List<String> services;
  final String? imageUrl;
  final double? rating;
  final String? city;
  final String? department;
  final double? distanceInKm;
  final bool? isOpen;
  final String? website;
  final String? openingHours;
  final int? totalRatings;
  final String? phoneNumber;
  
  // Datos de OpenStreetMap
  final String? osmType;
  final int? osmId;
  final Map<String, dynamic>? tags;

  DentalClinic({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phone,
    this.email,
    this.description,
    this.services = const [],
    this.imageUrl,
    this.rating,
    this.city,
    this.department,
    this.distanceInKm,
    this.isOpen,
    this.website,
    this.openingHours,
    this.totalRatings,
    this.phoneNumber,
    this.osmType,
    this.osmId,
    this.tags,
  });

  // Calcular distancia desde la ubicación del usuario (en km)
  double calculateDistance(double userLat, double userLon) {
    const double earthRadius = 6371;
    
    double dLat = _toRadians(latitude - userLat);
    double dLon = _toRadians(longitude - userLon);
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(userLat)) * math.cos(_toRadians(latitude)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }

  // Convertir desde OpenStreetMap
  factory DentalClinic.fromOSM(Map<String, dynamic> element) {
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    
    double lat = 0.0;
    double lon = 0.0;
    
    if (element['lat'] != null && element['lon'] != null) {
      lat = (element['lat'] is String) 
          ? double.parse(element['lat']) 
          : element['lat'].toDouble();
      lon = (element['lon'] is String) 
          ? double.parse(element['lon']) 
          : element['lon'].toDouble();
    } else if (element['center'] != null) {
      lat = element['center']['lat'].toDouble();
      lon = element['center']['lon'].toDouble();
    }

    String name = tags['name'] ?? 
                  tags['brand'] ?? 
                  tags['operator'] ?? 
                  'Clínica Dental';
    
    String address = _buildAddress(tags);
    
    String? phone = tags['phone'] ?? 
                    tags['contact:phone'] ?? 
                    tags['telephone'];
    
    String? website = tags['website'] ?? 
                      tags['contact:website'] ?? 
                      tags['url'];
    
    String? email = tags['email'] ?? 
                    tags['contact:email'];
    
    String? openingHours = tags['opening_hours'];
    
    List<String> services = _extractServices(tags);

    return DentalClinic(
      id: element['id'].toString(),
      name: name,
      address: address,
      latitude: lat,
      longitude: lon,
      phone: phone,
      phoneNumber: phone,
      email: email,
      website: website,
      openingHours: openingHours,
      services: services,
      city: tags['addr:city'],
      department: tags['addr:state'] ?? tags['addr:province'],
      osmType: element['type'],
      osmId: element['id'],
      tags: tags,
    );
  }

  static String _buildAddress(Map<String, dynamic> tags) {
    List<String> addressParts = [];
    
    if (tags['addr:street'] != null) {
      String street = tags['addr:street'];
      if (tags['addr:housenumber'] != null) {
        street = '$street ${tags['addr:housenumber']}';
      }
      addressParts.add(street);
    }
    
    if (tags['addr:city'] != null) {
      addressParts.add(tags['addr:city']);
    }
    
    if (addressParts.isEmpty) {
      return tags['address'] ?? 'Dirección no disponible';
    }
    
    return addressParts.join(', ');
  }

  static List<String> _extractServices(Map<String, dynamic> tags) {
    List<String> services = [];
    
    if (tags['emergency'] == 'yes') services.add('Emergencias');
    if (tags['wheelchair'] == 'yes') services.add('Accesible');
    if (tags['healthcare:speciality'] != null) {
      services.add(tags['healthcare:speciality']);
    }
    
    if (tags['amenity'] == 'dentist') services.add('Odontología General');
    if (tags['healthcare'] == 'dentist') services.add('Clínica Dental');
    
    return services;
  }

  // Convertir desde Firestore
  factory DentalClinic.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return DentalClinic(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      phone: data['phone'],
      phoneNumber: data['phone'],
      email: data['email'],
      description: data['description'],
      services: List<String>.from(data['services'] ?? []),
      imageUrl: data['imageUrl'],
      rating: data['rating']?.toDouble(),
      city: data['city'],
      department: data['department'],
      website: data['website'],
      openingHours: data['openingHours'],
    );
  }

  // Convertir a Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone ?? phoneNumber,
      'email': email,
      'description': description,
      'services': services,
      'imageUrl': imageUrl,
      'rating': rating,
      'city': city,
      'department': department,
      'website': website,
      'openingHours': openingHours,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // Crear copia con distancia calculada
  DentalClinic copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? phone,
    String? email,
    String? description,
    List<String>? services,
    String? imageUrl,
    double? rating,
    String? city,
    String? department,
    double? distanceInKm,
    bool? isOpen,
    String? website,
    String? openingHours,
    int? totalRatings,
    String? phoneNumber,
  }) {
    return DentalClinic(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      description: description ?? this.description,
      services: services ?? this.services,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      city: city ?? this.city,
      department: department ?? this.department,
      distanceInKm: distanceInKm ?? this.distanceInKm,
      isOpen: isOpen ?? this.isOpen,
      website: website ?? this.website,
      openingHours: openingHours ?? this.openingHours,
      totalRatings: totalRatings ?? this.totalRatings,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      osmType: osmType,
      osmId: osmId,
      tags: tags,
    );
  }
}