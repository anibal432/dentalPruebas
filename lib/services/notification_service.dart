import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Inicializa el sistema de notificaciones.
  Future<void> init() async {
    debugPrint('========================================');
    debugPrint('🔔 INICIANDO NOTIFICATION SERVICE');
    debugPrint('========================================');

    // Inicializar zonas horarias.
    tzdata.initializeTimeZones();

    // Zona horaria de Guatemala.
    tz.setLocalLocation(
      tz.getLocation('America/Guatemala'),
    );

    debugPrint('🌎 Zona horaria: ${tz.local.name}');

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(settings);

    debugPrint('✅ Plugin de notificaciones inicializado');

    // Permiso para mostrar notificaciones.
    final permisoNotificacion =
        await Permission.notification.request();

    debugPrint(
      '🔔 Permiso notificaciones: $permisoNotificacion',
    );

    // Permiso para alarmas exactas.
    try {
      final permisoAlarmaExacta =
          await Permission.scheduleExactAlarm.isGranted;

      debugPrint(
        '⏰ Permiso alarma exacta: $permisoAlarmaExacta',
      );

      if (!permisoAlarmaExacta) {
        await Permission.scheduleExactAlarm.request();
      }
    } catch (e) {
      debugPrint(
        '❌ Error comprobando permiso de alarma exacta: $e',
      );
    }

    debugPrint('========================================');
    debugPrint('🔔 NOTIFICATION SERVICE LISTO');
    debugPrint('========================================');
  }

  /// Programa una notificación para la fecha indicada.
  Future<void> programarRecordatorio({
    required int id,
    required String titulo,
    required String cuerpo,
    required DateTime fecha,
  }) async {
    final ahora = DateTime.now();

    if (fecha.isBefore(ahora)) {
      throw Exception(
        'La fecha del recordatorio debe ser posterior a la hora actual.',
      );
    }

    final fechaZonaHoraria = tz.TZDateTime.from(
      fecha,
      tz.local,
    );

    bool permisoAlarmaExacta = false;

    try {
      permisoAlarmaExacta =
          await Permission.scheduleExactAlarm.isGranted;
    } catch (e) {
      debugPrint(
        '❌ No se pudo comprobar el permiso de alarma exacta: $e',
      );
    }

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'recordatorios_channel',
        'Recordatorios',
        channelDescription: 'Recordatorios de citas dentales',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    try {
      if (permisoAlarmaExacta) {
        await _plugin.zonedSchedule(
          id,
          titulo,
          cuerpo,
          fechaZonaHoraria,
          notificationDetails,
          androidScheduleMode:
              AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } else {
        await _plugin.zonedSchedule(
          id,
          titulo,
          cuerpo,
          fechaZonaHoraria,
          notificationDetails,
          androidScheduleMode:
              AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }

      debugPrint(
        '✅ Recordatorio programado para $fechaZonaHoraria',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '❌ Error programando notificación: $e',
      );
      debugPrint('$stackTrace');

      // Si falla la alarma exacta, intentamos una inexacta.
      if (permisoAlarmaExacta) {
        try {
          await _plugin.zonedSchedule(
            id,
            titulo,
            cuerpo,
            fechaZonaHoraria,
            notificationDetails,
            androidScheduleMode:
                AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );

          debugPrint(
            '✅ Recordatorio programado como alarma inexacta',
          );

          return;
        } catch (e2) {
          debugPrint(
            '❌ También falló la alarma inexacta: $e2',
          );
        }
      }

      rethrow;
    }
  }

  /// Cancela una notificación previamente programada.
  Future<void> cancelarRecordatorio(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancela todas las notificaciones.
  Future<void> cancelarTodas() async {
    await _plugin.cancelAll();
  }
}