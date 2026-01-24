// lib/models/dental_clinic.dart
class DentalClinic {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final int totalRatings;
  final bool isOpen;
  final String? phoneNumber;
  final double distanceInKm;

  DentalClinic({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.totalRatings,
    required this.isOpen,
    this.phoneNumber,
    required this.distanceInKm,
  });
}