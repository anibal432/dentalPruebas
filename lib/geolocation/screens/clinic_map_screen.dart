// lib/screens/clinic_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/dental_clinic.dart';
import '../services/location_service.dart';
import 'clinic_detail_screen.dart';
import '../widgets/radius_selector.dart';

class ClinicMapScreen extends StatefulWidget {
  const ClinicMapScreen({super.key});

  @override
  State<ClinicMapScreen> createState() => _ClinicMapScreenState();
}

class _ClinicMapScreenState extends State<ClinicMapScreen> {
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();

  Position? _currentPosition;
  List<DentalClinic> _nearbyClinics = [];
  bool _isLoading = true;
  double _radiusKm = 5.0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Position? position = await _locationService.getCurrentLocation();

      if (position != null) {
        setState(() => _currentPosition = position);
        await _loadNearbyClinics();
      } else {
        setState(() => _errorMessage = 'No se pudo obtener la ubicación');
        if (mounted) _showPermissionDialog();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNearbyClinics() async {
    if (_currentPosition == null) return;

    setState(() => _isLoading = true);

    try {
      List<DentalClinic> clinics = await _locationService.findNearbyDentalClinics(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radiusKm: _radiusKm,
      );

      setState(() {
        _nearbyClinics = clinics;
        _errorMessage = clinics.isEmpty 
            ? 'No se encontraron clínicas en ${_radiusKm.toInt()} km'
            : null;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso de Ubicación'),
        content: const Text(
          'Se necesita acceso a tu ubicación para mostrar clínicas cercanas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _locationService.openAppSettings();
            },
            child: const Text('Configuración'),
          ),
        ],
      ),
    );
  }

  void _centerOnUser() {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        15.0,
      );
    }
  }

  void _showRadiusSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RadiusSelector(
        initialRadius: _radiusKm,
        onRadiusChanged: (double newRadius) {
          setState(() => _radiusKm = newRadius);
          _loadNearbyClinics();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Clínicas'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showRadiusSelector,
            tooltip: 'Radio de búsqueda',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNearbyClinics,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text('Buscando clínicas cercanas...'),
                  SizedBox(height: 8),
                  Text(
                    'Usando OpenStreetMap',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            )
          : _currentPosition == null
              ? _buildNoLocationWidget()
              : Stack(
                  children: [
                    _buildMap(),
                    if (_errorMessage != null) _buildErrorBanner(),
                    _buildClinicsList(),
                  ],
                ),
      floatingActionButton: _currentPosition != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'refresh',
                  onPressed: _loadNearbyClinics,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.refresh, color: Colors.teal),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'location',
                  onPressed: _centerOnUser,
                  backgroundColor: Colors.teal,
                  child: const Icon(Icons.my_location),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        initialZoom: 13.0,
        minZoom: 5.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.umg.dental_umg',
        ),
        CircleLayer(
          circles: [
            CircleMarker(
              point: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              radius: _radiusKm * 1000,
              useRadiusInMeter: true,
              color: Colors.blue.withAlpha(25),
              borderColor: Colors.blue.withAlpha(77),
              borderStrokeWidth: 2,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              width: 60,
              height: 60,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(77),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            ..._nearbyClinics.asMap().entries.map((entry) {
              final clinic = entry.value;
              return Marker(
                point: LatLng(clinic.latitude, clinic.longitude),
                width: 50,
                height: 50,
                child: GestureDetector(
                  onTap: () => _showClinicDetail(clinic),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(77),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_hospital,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade800),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.orange.shade900),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _errorMessage = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClinicsList() {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.1,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_nearbyClinics.length} clínicas',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Chip(
                      label: Text('${_radiusKm.toInt()} km'),
                      avatar: const Icon(Icons.location_on, size: 16),
                      backgroundColor: Colors.teal.shade50,
                      labelStyle: TextStyle(
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _nearbyClinics.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _nearbyClinics.length,
                        padding: const EdgeInsets.only(bottom: 16),
                        itemBuilder: (context, index) {
                          return _buildClinicCard(_nearbyClinics[index]);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No se encontraron clínicas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta ampliar el radio de búsqueda',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _radiusKm = _radiusKm + 5);
              _loadNearbyClinics();
            },
            icon: const Icon(Icons.zoom_out_map),
            label: const Text('Ampliar búsqueda'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicCard(DentalClinic clinic) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.local_hospital,
            color: Colors.red,
            size: 28,
          ),
        ),
        title: Text(
          clinic.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    clinic.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.directions_walk, size: 14, color: Colors.blue.shade700),
                const SizedBox(width: 4),
                Text(
                  '${clinic.distanceInKm?.toStringAsFixed(2) ?? '?'} km',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _showClinicDetail(clinic),
      ),
    );
  }

  void _showClinicDetail(DentalClinic clinic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClinicDetailScreen(
          clinic: clinic,
          userPosition: _currentPosition,
        ),
      ),
    );
  }

  Widget _buildNoLocationWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 100, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            const Text(
              'Ubicación no disponible',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Activa los servicios de ubicación para encontrar clínicas cercanas',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeMap,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _locationService.openAppSettings(),
              child: const Text('Abrir Configuración'),
            ),
          ],
        ),
      ),
    );
  }
}