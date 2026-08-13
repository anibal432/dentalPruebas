// lib/admin/services/stats_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class StatsService {
  static final StatsService _i = StatsService._();
  factory StatsService() => _i;
  StatsService._();

  final _db = FirebaseFirestore.instance;
  DateTime? _sessionStart;

  /// Llama esto justo después del login exitoso.
  void iniciarSesion() {
    _sessionStart ??= DateTime.now();
    debugPrint('⏱ Sesión iniciada: $_sessionStart');
  }

  /// Guarda los minutos transcurridos en estadisticas/global.
  Future<void> registrarSalida() async {
    if (_sessionStart == null) return;
    try {
      final minutos = DateTime.now().difference(_sessionStart!).inMinutes;
      debugPrint('⏱ Minutos de sesión: $minutos');

      if (minutos > 0) {
        await _db.collection('estadisticas').doc('global').set(
          {'minutosUsoTotal': FieldValue.increment(minutos)},
          SetOptions(merge: true),
        );
        debugPrint('✅ Minutos guardados: $minutos');
      }
    } catch (e) {
      debugPrint('StatsService.registrarSalida error: $e');
    } finally {
      _sessionStart = null;
    }
  }
}