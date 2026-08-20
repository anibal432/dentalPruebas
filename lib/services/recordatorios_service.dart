// lib/services/recordatorios_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/recordatorio.dart';

class RecordatoriosService {
  static final RecordatoriosService _instance =
      RecordatoriosService._internal();
  factory RecordatoriosService() => _instance;
  RecordatoriosService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _coleccion(String uid) =>
      _db.collection('usuarios').doc(uid).collection('recordatorios');

  /// Último día permitido: 31 de diciembre del año actual, 23:59.
  DateTime get finDeAnio {
    final ahora = DateTime.now();
    return DateTime(ahora.year, 12, 31, 23, 59);
  }

  /// Primer día permitido: hoy a las 00:00.
  DateTime get inicioHoy {
    final ahora = DateTime.now();
    return DateTime(ahora.year, ahora.month, ahora.day);
  }

  Future<void> crearRecordatorio({
    required String uid,
    required String titulo,
    required DateTime fecha,
    required String tipo,
    String notas = '',
  }) async {
    if (fecha.isBefore(inicioHoy) || fecha.isAfter(finDeAnio)) {
      throw Exception(
        'La fecha debe estar entre hoy y el 31 de diciembre de este año',
      );
    }
    await _coleccion(uid).add({
      'titulo': titulo,
      'fecha': Timestamp.fromDate(fecha),
      'tipo': tipo,
      'estado': EstadoRecordatorio.pendiente.valor,
      'notas': notas,
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizarEstado(
    String uid,
    String recordatorioId,
    EstadoRecordatorio nuevoEstado,
  ) async {
    await _coleccion(uid).doc(recordatorioId).update({
      'estado': nuevoEstado.valor,
    });
  }

  Future<void> eliminarRecordatorio(String uid, String recordatorioId) async {
    await _coleccion(uid).doc(recordatorioId).delete();
  }

  /// Stream de recordatorios del usuario, desde hoy hasta fin de año,
  /// ordenados por fecha ascendente (los más próximos primero).
  Stream<List<Recordatorio>> streamRecordatorios(String uid) {
    return _coleccion(uid)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(finDeAnio))
        .orderBy('fecha')
        .snapshots()
        .map((snap) => snap.docs.map(Recordatorio.fromFirestore).toList())
        .handleError(
          (e) => debugPrint('❌ RecordatoriosService stream error: $e'),
        );
  }
}