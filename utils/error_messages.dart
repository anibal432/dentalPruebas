// lib/utils/error_messages.dart
//
// Traduce errores técnicos (FirebaseException, SocketException, etc.)
// a mensajes claros y amigables para el usuario final, en español.
// Úsalo en cualquier catch/StreamBuilder en vez de mostrar `error.toString()`.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendlyError {
  final String titulo;
  final String mensaje;
  final bool esProblemaDeConexion;

  const FriendlyError({
    required this.titulo,
    required this.mensaje,
    this.esProblemaDeConexion = false,
  });
}

/// Convierte cualquier error capturado en un [FriendlyError] presentable.
FriendlyError obtenerErrorAmigable(Object error) {
  // ── Errores de Firestore ────────────────────────────────────
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'cancelled':
        return const FriendlyError(
          titulo: 'Sin conexión',
          mensaje:
              'No pudimos conectarnos al servidor. Revisa tu conexión '
              'a internet e inténtalo de nuevo.',
          esProblemaDeConexion: true,
        );
      case 'permission-denied':
        return const FriendlyError(
          titulo: 'Acceso no permitido',
          mensaje:
              'No tienes permiso para ver esta información. Intenta '
              'cerrar sesión y volver a iniciarla.',
        );
      case 'not-found':
        return const FriendlyError(
          titulo: 'No encontrado',
          mensaje: 'No encontramos la información que buscabas.',
        );
      default:
        return const FriendlyError(
          titulo: 'Algo salió mal',
          mensaje:
              'Ocurrió un problema al cargar la información. '
              'Por favor, inténtalo de nuevo.',
        );
    }
  }

  // ── Errores de Firebase Auth ─────────────────────────────────
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'network-request-failed':
        return const FriendlyError(
          titulo: 'Sin conexión',
          mensaje: 'Revisa tu conexión a internet e inténtalo de nuevo.',
          esProblemaDeConexion: true,
        );
      case 'requires-recent-login':
        return const FriendlyError(
          titulo: 'Confirma tu identidad',
          mensaje: 'Por seguridad, necesitamos que inicies sesión de nuevo.',
        );
      default:
        return const FriendlyError(
          titulo: 'Algo salió mal',
          mensaje: 'No pudimos completar la acción. Inténtalo de nuevo.',
        );
    }
  }

  // ── Errores de red genéricos (SocketException, TimeoutException...) ──
  final texto = error.toString().toLowerCase();
  if (texto.contains('socket') ||
      texto.contains('network') ||
      texto.contains('timeout') ||
      texto.contains('connection')) {
    return const FriendlyError(
      titulo: 'Sin conexión',
      mensaje:
          'No pudimos conectarnos. Revisa tu conexión a internet '
          'e inténtalo de nuevo.',
      esProblemaDeConexion: true,
    );
  }

  // ── Cualquier otra cosa ───────────────────────────────────────
  return const FriendlyError(
    titulo: 'Algo salió mal',
    mensaje: 'Ocurrió un problema inesperado. Por favor, inténtalo de nuevo.',
  );
}