// lib/services/image_validation_service.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// Servicio que valida, usando el modelo base de ML Kit, si una imagen
/// corresponde a una boca/dentadura antes de mandarla al modelo TFLite
/// de clasificación dental (Caries, Sarro, Aftas, Gingivitis, Sano).
/// También incluye una heurística liviana (sin IA) para advertir sobre
/// posibles brackets/objetos metálicos, sin bloquear el análisis.
class ImageValidationService {
  static const List<String> _etiquetasValidas = [
    'tooth',
    'teeth',
    'mouth',
    'jaw',
    'lip',
    'chin',
    'human mouth',
    'dental',
    'human body',
    'face',
  ];

  static const double _confianzaMinima = 0.5;

  final ImageLabeler _labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.4),
  );

  /// Retorna true si la imagen parece ser una boca/dentadura.
  /// Retorna false si detecta objetos/personas completas u otra cosa
  /// que no coincide con las etiquetas esperadas.
  Future<bool> esImagenDental(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final List<ImageLabel> labels = await _labeler.processImage(inputImage);

      if (kDebugMode) {
        debugPrint('🔍 Etiquetas detectadas por ML Kit:');
        for (final l in labels) {
          debugPrint(
              '   - ${l.label} (${(l.confidence * 100).toStringAsFixed(1)}%)');
        }
      }

      for (final label in labels) {
        final texto = label.label.toLowerCase();
        final coincide =
            _etiquetasValidas.any((valida) => texto.contains(valida));
        if (coincide && label.confidence >= _confianzaMinima) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error validando imagen con ML Kit: $e');
      // Si el validador falla (ej. error de plataforma), no bloqueamos
      // al usuario: dejamos pasar la imagen al modelo principal.
      return true;
    }
  }

  /// Heurística liviana (sin IA, sin modelo nuevo) para detectar posibles
  /// brackets/ortodoncia u objetos metálicos en la franja central de la
  /// imagen, donde normalmente está la línea de dientes.
  /// No bloquea el análisis: solo sirve como bandera de advertencia,
  /// independiente de las probabilidades del modelo de clasificación.
  Future<bool> probablementeTieneBrackets(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      const int sampleSize = 120; // resolución baja, solo para el heurístico
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: sampleSize,
        targetHeight: sampleSize,
      );
      final frame = await codec.getNextFrame();
      final uiImage = frame.image;
      final byteData =
          await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      uiImage.dispose();
      if (byteData == null) return false;

      final pixels = byteData.buffer.asUint8List();

      // Franja central donde suele estar la línea de dientes/brackets
      final yStart = (sampleSize * 0.35).round();
      final yEnd = (sampleSize * 0.65).round();

      int metalicos = 0;
      int totalMuestreados = 0;

      for (int y = yStart; y < yEnd; y++) {
        for (int x = 0; x < sampleSize; x++) {
          final i = (y * sampleSize + x) * 4;
          final r = pixels[i];
          final g = pixels[i + 1];
          final b = pixels[i + 2];

          final brightness = (r + g + b) / 3.0;
          final maxC = [r, g, b].reduce((a, c) => a > c ? a : c);
          final minC = [r, g, b].reduce((a, c) => a < c ? a : c);
          final saturation = maxC == 0 ? 0.0 : (maxC - minC) / maxC;

          totalMuestreados++;
          // Brillo alto + baja saturación = típico de metal/plateado
          if (brightness > 195 && saturation < 0.12) {
            metalicos++;
          }
        }
      }

      if (totalMuestreados == 0) return false;
      final proporcion = metalicos / totalMuestreados;

      if (kDebugMode) {
        debugPrint('🔩 Proporción de píxeles metálicos en franja dental: '
            '${(proporcion * 100).toStringAsFixed(1)}%');
      }

      // ⚠️ Umbral inicial — calíbralo viendo el debugPrint de arriba
      // con tus propias fotos (con y sin brackets)
      return proporcion > 0.09;
    } catch (e) {
      debugPrint('❌ Error en heurística de brackets: $e');
      return false;
    }
  }

  void dispose() {
    _labeler.close();
  }
}