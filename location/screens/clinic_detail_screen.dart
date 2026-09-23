// lib/location/screens/clinic_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/dental_clinic.dart';

class ClinicDetailScreen extends StatelessWidget {
  final DentalClinic clinic;
  final Position? userPosition;

  const ClinicDetailScreen({
    super.key,
    required this.clinic,
    this.userPosition,
  });

  double? _getDistance() {
    if (clinic.distanceInKm != null) return clinic.distanceInKm;
    if (userPosition == null) return null;
    return clinic.calculateDistance(
      userPosition!.latitude,
      userPosition!.longitude,
    );
  }

  Future<void> _launchSafe(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir: $url'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir el enlace: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _launchPhone(BuildContext context) async {
    final phoneToCall = clinic.phone ?? clinic.phoneNumber;
    if (phoneToCall == null || phoneToCall.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teléfono no disponible')),
        );
      }
      return;
    }
    final cleaned = phoneToCall.replaceAll(RegExp(r'[\s\-()]'), '');
    await _launchSafe(context, 'tel:$cleaned');
  }

  Future<void> _launchEmail(BuildContext context) async {
    if (clinic.email == null || clinic.email!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email no disponible')),
        );
      }
      return;
    }
    await _launchSafe(context, 'mailto:${clinic.email}');
  }

  Future<void> _launchWebsite(BuildContext context) async {
    if (clinic.website == null || clinic.website!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sitio web no disponible')),
        );
      }
      return;
    }
    String url = clinic.website!;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    await _launchSafe(context, url);
  }

  Future<void> _openInGoogleMaps(BuildContext context) async {
    final lat = clinic.latitude;
    final lng = clinic.longitude;
    final name = Uri.encodeComponent(clinic.name);
    final nativeUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($name)');
    bool opened = false;
    try {
      opened = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened) {
      final webUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      await _launchSafe(context, webUrl);
    }
  }

  Future<void> _openInOSM(BuildContext context) async {
    final lat = clinic.latitude;
    final lng = clinic.longitude;
    final url = 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng&zoom=18#map=18/$lat/$lng';
    await _launchSafe(context, url);
  }

  void _showMapOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Abrir ubicación en…',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.map, color: Color(0xFF3B2F8C)),
              ),
              title: const Text('Google Maps'),
              subtitle: const Text('Abre en la app o navegador'),
              onTap: () { Navigator.pop(ctx); _openInGoogleMaps(context); },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.public, color: Colors.green.shade700),
              ),
              title: const Text('OpenStreetMap'),
              subtitle: const Text('Abre en el navegador'),
              onTap: () { Navigator.pop(ctx); _openInOSM(context); },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distance = _getDistance();

    return Scaffold(
      // SafeArea evita que el contenido (y sobre todo los botones finales
      // "Cómo llegar" / "Llamar") quede pegado a la barra de navegación del
      // sistema, que es justo lo que hacía fácil tocar un botón del celular
      // en vez de la app.
      body: SafeArea(
        bottom: true,
        child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            // Antes el toolbar colapsado usaba la altura estándar de
            // Android (56px), muy angosta para un nombre largo — por eso
            // el texto se veía diminuto o se cortaba/superponía con el
            // contenido de abajo (la línea roja que marcaste). Con más
            // alto en el estado colapsado, el nombre tiene espacio real
            // para 2 líneas con una letra legible, y el contenido de abajo
            // arranca limpio, después del encabezado.
            toolbarHeight: 76,
            pinned: true,
            backgroundColor: const Color(0xFF5B4FCF),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 12, end: 16),
              title: Text(
                clinic.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                ),
              ),
              background: clinic.imageUrl != null
                  ? Image.network(
                      clinic.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildDefaultImage(),
                    )
                  : _buildDefaultImage(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (distance != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF3B2F8C), Color(0xFF3B2F8C)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF3B2F8C),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.near_me, size: 18, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            '${distance.toStringAsFixed(2)} km de distancia',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  _buildSectionTitle('Información de Contacto'),
                  const SizedBox(height: 12),

                  _buildInfoCard(
                    icon: Icons.location_on,
                    title: 'Dirección',
                    subtitle: clinic.address,
                    color: Colors.red,
                    onTap: () => _showMapOptions(context),
                  ),

                  if (clinic.phone != null && clinic.phone!.isNotEmpty)
                    _buildInfoCard(
                      icon: Icons.phone,
                      title: 'Teléfono',
                      subtitle: clinic.phone!,
                      color: Colors.green,
                      onTap: () => _launchPhone(context),
                    ),

                  if (clinic.email != null && clinic.email!.isNotEmpty)
                    _buildInfoCard(
                      icon: Icons.email,
                      title: 'Email',
                      subtitle: clinic.email!,
                      color: Color(0xFF3B2F8C),
                      onTap: () => _launchEmail(context),
                    ),

                  if (clinic.website != null && clinic.website!.isNotEmpty)
                    _buildInfoCard(
                      icon: Icons.language,
                      title: 'Sitio Web',
                      subtitle: clinic.website!,
                      color: Colors.purple,
                      onTap: () => _launchWebsite(context),
                    ),

                  const SizedBox(height: 24),

                  if (clinic.openingHours != null && clinic.openingHours!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Horario de Atención'),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F1FC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF7C6FE0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: Color(0xFF3B2F8C)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  clinic.openingHours!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF3B2F8C),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),

                  if (clinic.city != null || clinic.department != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Ubicación'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (clinic.city != null)
                              Expanded(child: _buildLocationChip(icon: Icons.location_city, label: clinic.city!)),
                            if (clinic.city != null && clinic.department != null)
                              const SizedBox(width: 8),
                            if (clinic.department != null)
                              Expanded(child: _buildLocationChip(icon: Icons.map, label: clinic.department!)),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),

                  if (clinic.description != null && clinic.description!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Descripción'),
                        const SizedBox(height: 12),
                        Text(
                          clinic.description!,
                          style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),

                  if (clinic.services.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Servicios'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: clinic.services.map((service) {
                            return Container(
                              // Sin esto, un servicio con texto largo (como
                              // "Operatoria dental (rellenos, incrustaciones,
                              // carillas)") se salía de la pantalla, porque
                              // Wrap no limita el ancho de cada hijo por sí
                              // solo — cada chip crecía tanto como su texto
                              // lo pidiera.
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width - 32,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F1FC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF7C6FE0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Icon(Icons.check_circle, size: 16, color: Color(0xFF3B2F8C)),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      service,
                                      softWrap: true,
                                      style: const TextStyle(
                                        color: Color(0xFF3B2F8C),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),

                  if (clinic.osmType != null)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFF3B2F8C), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Datos de OpenStreetMap',
                                  style: TextStyle(color: Color(0xFF3B2F8C), fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),

                  // FIX: antes el Expanded del botón "Llamar" estaba dentro
                  // de un Padding, y el Padding era el hijo directo del Row.
                  // Expanded solo puede ser hijo directo de un Row/Column/Flex;
                  // al quedar un nivel más adentro, Flutter tronaba con
                  // "Incorrect use of ParentDataWidget" al montar el widget
                  // (justo lo que salía en el log), y la pantalla completa se
                  // caía a un rectángulo gris en vez de mostrar el detalle.
                  // Ahora el Expanded envuelve al Padding, no al revés.
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showMapOptions(context),
                          icon: const Icon(Icons.directions),
                          label: const Text('Cómo llegar'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF5B4FCF),
                            foregroundColor: Colors.white,
                            elevation: 2,
                          ),
                        ),
                      ),
                      if (clinic.phone != null && clinic.phone!.isNotEmpty)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: ElevatedButton.icon(
                              onPressed: () => _launchPhone(context),
                              icon: const Icon(Icons.phone),
                              label: const Text('Llamar'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildDefaultImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8C7FE8), Color(0xFF5B4FCF)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.local_hospital, size: 80, color: Colors.white),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        trailing: onTap != null
            ? Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400)
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildLocationChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}