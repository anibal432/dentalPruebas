// lib/location/screens/smart_clinic_screen.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/dental_clinic.dart';
import '../services/location_service.dart';
import 'clinic_detail_screen.dart';

class AffiliatedClinic {
  final String firestoreId;
  final String badgeLabel;
  final String speciality;
  const AffiliatedClinic({required this.firestoreId, required this.badgeLabel, required this.speciality});
}

const List<AffiliatedClinic> _affiliatedList = [
  AffiliatedClinic(firestoreId: 'REEMPLAZA_CON_DOC_ID', badgeLabel: 'Recomendada', speciality: 'Odontología General · Ortodoncia · Implantes'),
];

class _ScoredClinic {
  final DentalClinic clinic;
  final double score;
  final AffiliatedClinic? affiliated;
  final String recommendReason;
  final bool isFirestore;
  const _ScoredClinic({required this.clinic, required this.score, required this.recommendReason, this.affiliated, this.isFirestore = false});
  bool get isAffiliated => affiliated != null;
}

List<_ScoredClinic> _scoreAndSort(List<DentalClinic> clinics, {String? detectedCondition, Set<String>? firestoreIds}) {
  final affiliatedMap = {for (final a in _affiliatedList) a.firestoreId: a};
  firestoreIds ??= {};
  final scored = clinics.map((clinic) {
    final aff = affiliatedMap[clinic.id];
    final isFS = firestoreIds!.contains(clinic.id);
    final dist = clinic.distanceInKm ?? 10.0;
    final distScore = ((10.0 - dist.clamp(0, 10)) * 2).clamp(0.0, 20.0);
    final ratingScore = ((clinic.rating ?? 3.5) * 4).clamp(0.0, 20.0);
    final firestoreBoost = isFS ? 999.0 : 0.0;
    final total = distScore + ratingScore + firestoreBoost;
    String reason;
    if (isFS && detectedCondition != null) {
      reason = '🦷 Puede tratar $detectedCondition · Clínica verificada';
    } else if (isFS) {
      reason = '✅ Clínica verificada · Atención integral disponible';
    } else if (dist < 1.0) {
      reason = '📍 La más cercana · ${dist.toStringAsFixed(1)} km';
    } else if ((clinic.rating ?? 0) >= 4.5) {
      reason = '⭐ Mejor valorada en la zona';
    } else {
      reason = '📍 ${dist.toStringAsFixed(1)} km de distancia';
    }
    return _ScoredClinic(clinic: clinic, score: total, affiliated: aff, recommendReason: reason, isFirestore: isFS);
  }).toList()..sort((a, b) => b.score.compareTo(a.score));
  return scored;
}

class SmartClinicScreen extends StatefulWidget {
  final String? detectedCondition;
  const SmartClinicScreen({super.key, this.detectedCondition});
  @override
  State<SmartClinicScreen> createState() => _SmartClinicScreenState();
}

class _SmartClinicScreenState extends State<SmartClinicScreen> with SingleTickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  Position? _position;
  List<_ScoredClinic> _scored = [];
  bool _loading = true;
  String? _error;
  double _radiusKm = 10.0;
  bool _isRealGPS = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _init();
  }

  @override
  void dispose() { _animController.dispose(); super.dispose(); }

  Future<void> _init() async {
    setState(() { _loading = true; _error = null; });
    Position? pos = await _locationService.getCurrentLocation();
    if (pos != null) { _isRealGPS = true; } else { pos = _locationService.getGuatemalaCityPosition(); _isRealGPS = false; }
    if (!mounted) return;
    setState(() => _position = pos);
    await _loadClinics();
  }

  Future<void> _loadClinics() async {
    if (_position == null) return;
    setState(() => _loading = true);
    try {
      final raw = await _locationService.findNearbyDentalClinics(latitude: _position!.latitude, longitude: _position!.longitude, radiusKm: _radiusKm);
      if (!mounted) return;
      final firestoreIds = raw.where((c) => !RegExp(r'^\d+$').hasMatch(c.id)).map((c) => c.id).toSet();
      final scored = _scoreAndSort(raw, detectedCondition: widget.detectedCondition, firestoreIds: firestoreIds);
      setState(() {
        _scored = scored;
        _loading = false;
        _error = raw.isEmpty ? 'No se encontraron clínicas en ${_radiusKm.toInt()} km' : null;
      });
      _animController..reset()..forward();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Error al buscar clínicas: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildAppBar(),
      body: _loading ? _buildLoader() : _scored.isEmpty ? _buildEmpty() : FadeTransition(opacity: _fadeAnim, child: _buildContent()),
      floatingActionButton: !_loading && _scored.isNotEmpty ? _buildFAB() : null,
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF2A2A6E),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Clínicas Cercanas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          if (widget.detectedCondition != null)
            Text('🧠 Diagnóstico: ${widget.detectedCondition}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.tune_rounded), onPressed: _showRadiusPicker, tooltip: 'Radio de búsqueda'),
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _init, tooltip: 'Actualizar'),
      ],
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF3D3D8F), strokeWidth: 3),
          SizedBox(height: 16),
          Text('Buscando clínicas…', style: TextStyle(color: Color(0xFF3D3D8F), fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('Calculando recomendaciones', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(_error ?? 'Sin clínicas en el área', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () { setState(() => _radiusKm = (_radiusKm + 10).clamp(0, 50)); _loadClinics(); },
              icon: const Icon(Icons.zoom_out_map_rounded),
              label: Text('Ampliar a ${(_radiusKm + 10).clamp(0, 50).toInt()} km'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D3D8F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final top = _scored.first;
    final rest = _scored.skip(1).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (widget.detectedCondition != null) _buildAIBanner(),
        if (!_isRealGPS) _buildGPSWarning(),
        _buildSectionHeader('⭐ Recomendado para ti', const Color(0xFF2A2A6E)),
        const SizedBox(height: 8),
        _buildTopCard(top),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionHeader('Otras clínicas cercanas (${rest.length})', Colors.grey.shade600),
          const SizedBox(height: 8),
          ...List.generate(rest.length, (i) => _buildRegularCard(rest[i], i)),
        ],
      ],
    );
  }

  Widget _buildAIBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A6E), Color(0xFF5C5CAF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: const Color(0xFF3D3D8F).withAlpha(80), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withAlpha(40), shape: BoxShape.circle),
            child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recomendación personalizada', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                Text(
                  'Diagnóstico: ${widget.detectedCondition}. Te mostramos clínicas que pueden atenderte.',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGPSWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off_rounded, color: Colors.orange.shade700, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text('Sin GPS — mostrando clínicas cerca de Guatemala City', style: TextStyle(color: Colors.orange.shade800, fontSize: 12))),
          TextButton(
            onPressed: _init,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('Reintentar', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
      ],
    );
  }

  Widget _buildTopCard(_ScoredClinic sc) {
    final clinic = sc.clinic;
    final isFS = sc.isFirestore;
    const badgeColorFS = Color(0xFF2A2A6E);
    final badgeColor = isFS ? badgeColorFS : Color(0xFF2A2A6E);

    return GestureDetector(
      onTap: () => _openDetail(clinic),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isFS ? const Color(0xFF5C5CAF) : const Color(0xFFD0D0F0), width: isFS ? 2 : 1),
          boxShadow: [BoxShadow(color: const Color(0xFF3D3D8F).withAlpha(isFS ? 60 : 20), blurRadius: isFS ? 24 : 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isFS ? [const Color(0xFFD0D0F0), const Color(0xFF8888C8)] : [Colors.blue.shade50, Colors.blue.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(20),
                      shape: BoxShape.circle,
                      border: Border.all(color: badgeColor.withAlpha(60)),
                    ),
                    child: Icon(Icons.local_hospital_rounded, color: badgeColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded, color: Colors.white, size: 11),
                              const SizedBox(width: 4),
                              Text(
                                isFS ? 'Clínica Verificada' : sc.affiliated?.badgeLabel ?? 'Recomendada',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(clinic.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        Text('${clinic.distanceInKm?.toStringAsFixed(1) ?? '?'}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                        const Text('km', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: badgeColor.withAlpha(40)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: badgeColor, size: 14),
                        const SizedBox(width: 8),
                        Expanded(child: Text(sc.recommendReason, style: TextStyle(color: badgeColor.withAlpha(220), fontSize: 12, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.location_on_rounded, clinic.address, Colors.grey.shade500),
                  if (clinic.openingHours != null && clinic.openingHours!.isNotEmpty)
                    _buildInfoRow(Icons.access_time_rounded, clinic.openingHours!, const Color(0xFF5C5CAF), textColor: const Color(0xFF2A2A6E)),
                  if (clinic.phone != null && clinic.phone!.isNotEmpty)
                    _buildInfoRow(Icons.phone_rounded, clinic.phone!, Colors.green.shade400, textColor: Colors.green.shade700),
                  if (sc.affiliated != null)
                    _buildInfoRow(Icons.medical_services_rounded, sc.affiliated!.speciality, const Color(0xFF5C5CAF), textColor: const Color(0xFF2A2A6E)),
                  if (clinic.services.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6, runSpacing: 4,
                      children: clinic.services.take(4).map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0FA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFD0D0F0)),
                        ),
                        child: Text(s, style: const TextStyle(color: Color(0xFF2A2A6E), fontSize: 11)),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openDetail(clinic),
                      icon: const Icon(Icons.directions_rounded, size: 18),
                      label: const Text('Ver clínica', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: badgeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color iconColor, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(color: textColor ?? Colors.grey.shade600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildRegularCard(_ScoredClinic sc, int index) {
    final clinic = sc.clinic;
    final isFS = sc.isFirestore;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 1,
        shadowColor: Colors.black12,
        child: InkWell(
          onTap: () => _openDetail(clinic),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: isFS ? const Color(0xFFD0D0F0) : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text('${index + 2}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isFS ? const Color(0xFF2A2A6E) : Colors.grey.shade600))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(clinic.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (isFS)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD0D0F0),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF8888C8)),
                              ),
                              child: const Text('Verificada', style: TextStyle(color: Color(0xFF2A2A6E), fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(sc.recommendReason, style: TextStyle(color: Colors.grey.shade500, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (clinic.openingHours != null) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF8888C8)),
                          const SizedBox(width: 3),
                          Expanded(child: Text(clinic.openingHours!, style: const TextStyle(color: Color(0xFF5C5CAF), fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                      ],
                      const SizedBox(height: 3),
                      Row(children: [
                        Icon(Icons.location_on_rounded, size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Expanded(child: Text(clinic.address, style: TextStyle(color: Colors.grey.shade500, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${clinic.distanceInKm?.toStringAsFixed(1) ?? '?'} km',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isFS ? const Color(0xFF3D3D8F) : Colors.grey.shade700),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _loadClinics,
      backgroundColor: const Color(0xFF2A2A6E),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.my_location_rounded),
      label: Text('${_scored.length} clínicas · ${_radiusKm.toInt()} km'),
    );
  }

  void _showRadiusPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RadiusPicker(current: _radiusKm, onChanged: (v) { setState(() => _radiusKm = v); _loadClinics(); }),
    );
  }

  void _openDetail(DentalClinic clinic) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ClinicDetailScreen(clinic: clinic, userPosition: _position)));
  }
}

class _RadiusPicker extends StatefulWidget {
  final double current;
  final void Function(double) onChanged;
  const _RadiusPicker({required this.current, required this.onChanged});
  @override
  State<_RadiusPicker> createState() => _RadiusPickerState();
}

class _RadiusPickerState extends State<_RadiusPicker> {
  late double _r;
  @override
  void initState() { super.initState(); _r = widget.current; }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Radio de búsqueda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          Text('${_r.toInt()} km', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Color(0xFF2A2A6E))),
          Slider(
            value: _r, min: 5, max: 50, divisions: 9,
            activeColor: const Color(0xFF3D3D8F),
            label: '${_r.toInt()} km',
            onChanged: (v) => setState(() => _r = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('5 km', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              Text('50 km', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () { widget.onChanged(_r); Navigator.pop(context); },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D3D8F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Aplicar', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}