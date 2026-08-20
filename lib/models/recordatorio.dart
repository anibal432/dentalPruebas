// lib/models/recordatorio.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoRecordatorio { pendiente, completado, cancelado }

EstadoRecordatorio estadoDesdeString(String? valor) {
  switch (valor) {
    case 'completado':
      return EstadoRecordatorio.completado;
    case 'cancelado':
      return EstadoRecordatorio.cancelado;
    default:
      return EstadoRecordatorio.pendiente;
  }
}

extension EstadoRecordatorioLabel on EstadoRecordatorio {
  String get valor {
    switch (this) {
      case EstadoRecordatorio.pendiente:
        return 'pendiente';
      case EstadoRecordatorio.completado:
        return 'completado';
      case EstadoRecordatorio.cancelado:
        return 'cancelado';
    }
  }

  String get etiqueta {
    switch (this) {
      case EstadoRecordatorio.pendiente:
        return 'Pendiente';
      case EstadoRecordatorio.completado:
        return 'Completado';
      case EstadoRecordatorio.cancelado:
        return 'Cancelado';
    }
  }
}

class Recordatorio {
  final String id;
  final String titulo;
  final DateTime fecha;
  final String tipo; // 'limpieza' | 'revision' | 'urgencia' | 'personalizado'
  final EstadoRecordatorio estado;
  final String notas;

  const Recordatorio({
    required this.id,
    required this.titulo,
    required this.fecha,
    required this.tipo,
    required this.estado,
    required this.notas,
  });

  factory Recordatorio.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Recordatorio(
      id: doc.id,
      titulo: data['titulo'] ?? 'Recordatorio',
      fecha: (data['fecha'] as Timestamp).toDate(),
      tipo: data['tipo'] ?? 'revision',
      estado: estadoDesdeString(data['estado'] as String?),
      notas: data['notas'] ?? '',
    );
  }
}