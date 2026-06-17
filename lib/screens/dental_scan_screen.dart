// lib/screens/dental_scan_screen.dart
import 'dart:io';
//import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../location/screens/smart_clinic_screen.dart'; // ← botón "Ver clínicas"

class DentalScanScreen extends StatefulWidget {
  const DentalScanScreen({super.key});

  @override
  State<DentalScanScreen> createState() => _DentalScanScreenState();
}

class _DentalScanScreenState extends State<DentalScanScreen>
    with TickerProviderStateMixin {
  File? _selectedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _diagnosis;
  Interpreter? _interpreter;
  bool _modelLoaded = false;

  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  static const List<String> _labels = [
    'Aftas Bucales',
    'Caries',
    'Gingivitis',
    'Sano',
    'Sarro',
  ];
  static const int _inputSize = 224;

  static const Map<String, double> _umbrales = {
    'Aftas Bucales': 0.40,
    'Caries': 0.35,
    'Gingivitis': 0.30,
    'Sano': 0.65,
    'Sarro': 0.35,
  };

  static const double _umbralAcumulado = 0.75;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadModel();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
          parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _fadeController, curve: Curves.easeOut),
    );
  }

  Future<void> _loadModel() async {
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        'assets/modelo_dental.tflite',
        options: options,
      );
      debugPrint('✅ Modelo cargado | '
          'Input: ${_interpreter!.getInputTensor(0).shape} | '
          'Output: ${_interpreter!.getOutputTensor(0).shape}');
      setState(() => _modelLoaded = true);
    } catch (e) {
      debugPrint('❌ Error cargando modelo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar el modelo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
          _diagnosis = null;
        });
        _fadeController.reset();
        await _analyzeImage();
      }
    } catch (e) {
      debugPrint('Error seleccionando imagen: $e');
    }
  }

  Future<List> _prepareInput(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes,
        targetWidth: _inputSize, targetHeight: _inputSize);
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;
    final byteData =
        await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    uiImage.dispose();
    if (byteData == null) throw Exception('No se pudo leer los píxeles');

    final pixels = byteData.buffer.asUint8List();
    return List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final b = (y * _inputSize + x) * 4;
          return [
            (pixels[b].toDouble() / 127.5) - 1.0,
            (pixels[b + 1].toDouble() / 127.5) - 1.0,
            (pixels[b + 2].toDouble() / 127.5) - 1.0,
          ];
        }),
      ),
    );
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null || _interpreter == null) return;
    setState(() => _isAnalyzing = true);

    try {
      final inputTensor = await _prepareInput(_selectedImage!);
      final outputTensor = [List.filled(_labels.length, 0.0)];
      _interpreter!.run(inputTensor, outputTensor);

      final scores = List<double>.from(outputTensor[0]);

      for (int i = 0; i < _labels.length; i++) {
        debugPrint(
            '🎯 [${_labels[i]}]: ${(scores[i] * 100).toStringAsFixed(2)}%');
      }

      final ranked = List<int>.generate(_labels.length, (i) => i)
        ..sort((a, b) => scores[b].compareTo(scores[a]));

      final top1Idx = ranked[0];
      final top2Idx = ranked[1];
      final top1Label = _labels[top1Idx];
      final top1Score = scores[top1Idx];
      final top2Label = _labels[top2Idx];
      final top2Score = scores[top2Idx];
      final umbral1 = _umbrales[top1Label] ?? 0.45;

      final top1EsPatologia = top1Label != 'Sano';
      final top2EsPatologia = top2Label != 'Sano';
      final sumaPatologias = (top1EsPatologia ? top1Score : 0.0) +
          (top2EsPatologia ? top2Score : 0.0);

      String labelFinal;
      double confianzaFinal;
      bool esSano;

      if (top1Label == 'Sano' && top1Score >= umbral1) {
        labelFinal = 'Sano';
        confianzaFinal = top1Score;
        esSano = true;
      } else if (top1EsPatologia && top1Score >= umbral1) {
        labelFinal = top1Label;
        confianzaFinal = top1Score;
        esSano = false;
      } else if (top1EsPatologia &&
          top2EsPatologia &&
          sumaPatologias >= _umbralAcumulado) {
        labelFinal = top1Label;
        confianzaFinal = top1Score;
        esSano = false;
      } else {
        labelFinal = 'No concluyente';
        confianzaFinal = top1Score;
        esSano = false;
      }

      String? segundaOpcion;
      double? segundaConfianza;
      if (!esSano &&
          top2EsPatologia &&
          top2Score > 0.20 &&
          top2Label != labelFinal) {
        segundaOpcion = top2Label;
        segundaConfianza = top2Score;
      }

      setState(() {
        _diagnosis = {
          'label': labelFinal,
          'confianza': confianzaFinal,
          'esSano': esSano,
          'scores': scores,
          'segundaOpcion': segundaOpcion,
          'segundaConfianza': segundaConfianza,
        };
        _isAnalyzing = false;
      });
      _fadeController.forward();
    } catch (e, stack) {
      debugPrint('❌ Error: $e\n$stack');
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al analizar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ── Helpers visuales ──────────────────────────────────────────────────────

  Color _colorPorLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('sano')) return const Color(0xFF2ECC71);
    if (l.contains('caries')) return const Color(0xFFE74C3C);
    if (l.contains('aftas')) return const Color(0xFFE67E22);
    if (l.contains('gingivitis')) return const Color(0xFF9B59B6);
    if (l.contains('sarro')) return const Color(0xFFF39C12);
    if (l.contains('concluyente')) return const Color(0xFF95A5A6);
    return const Color(0xFF3498DB);
  }

  IconData _iconPorLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('sano')) return Icons.check_circle_outline;
    if (l.contains('caries')) return Icons.warning_amber_rounded;
    if (l.contains('aftas')) return Icons.local_hospital_outlined;
    if (l.contains('gingivitis')) return Icons.bloodtype_outlined;
    if (l.contains('sarro')) return Icons.cleaning_services_outlined;
    if (l.contains('concluyente')) return Icons.help_outline;
    return Icons.info_outline;
  }

  String _descripcionPorLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('sano')) {
      return 'No se detectaron síntomas de caries, aftas bucales, gingivitis '
          'ni sarro. ¡Tu dentadura luce saludable! Recuerda mantener tu '
          'higiene bucal diaria.';
    }
    if (l.contains('caries')) {
      return 'Se detectaron posibles signos de caries dental. '
          'Te recomendamos visitar a tu odontólogo para una revisión y '
          'tratamiento oportuno.';
    }
    if (l.contains('aftas')) {
      return 'Se detectaron posibles aftas bucales (úlceras orales). '
          'Son generalmente temporales, pero si persisten más de 2 semanas '
          'consulta a tu médico.';
    }
    if (l.contains('gingivitis')) {
      return 'Se detectaron posibles signos de gingivitis (inflamación de '
          'encías). Las encías enrojecidas o inflamadas son una señal '
          'temprana. Se recomienda una limpieza dental profesional y mejorar '
          'la higiene bucal. Consulta con tu odontólogo.';
    }
    if (l.contains('sarro')) {
      return 'Se detectó acumulación de sarro (cálculo dental). El sarro '
          'endurecido no puede eliminarse con el cepillo; se requiere una '
          'limpieza profesional (profilaxis) por un odontólogo.';
    }
    if (l.contains('concluyente')) {
      return 'La imagen no permite un diagnóstico claro. Intenta con una '
          'foto más cercana, bien iluminada y sin movimiento.';
    }
    return 'Consulta a un odontólogo para mayor información.';
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.teal.withAlpha(15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.teal.withAlpha(60)),
        ),
        child: Row(children: [
          Icon(icon, color: Colors.teal, size: 18),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.teal.withAlpha(20)),
            child: const Icon(Icons.add_a_photo_outlined,
                size: 44, color: Colors.teal),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Sube una foto dental',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E))),
        const SizedBox(height: 6),
        Text('Foto intraoral, sonrisa o zona afectada',
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.teal.withAlpha(10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.teal.withAlpha(40)),
          ),
          child: const Text(
            '💡 Mejor resultado: buena iluminación, sin movimiento, '
            'boca bien abierta a 15-20 cm de distancia.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11, color: Colors.teal, height: 1.4),
          ),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _buildSourceButton(
              icon: Icons.photo_library_outlined,
              label: 'Galería',
              onTap: () => _pickImage(ImageSource.gallery)),
          const SizedBox(width: 12),
          _buildSourceButton(
              icon: Icons.camera_alt_outlined,
              label: 'Cámara',
              onTap: () => _pickImage(ImageSource.camera)),
        ]),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.file(_selectedImage!,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover),
      ),
      if (_isAnalyzing)
        Container(
          decoration: BoxDecoration(
              color: Colors.black.withAlpha(140),
              borderRadius: BorderRadius.circular(22)),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                    color: Colors.teal, strokeWidth: 3),
                SizedBox(height: 16),
                Text('Analizando con IA...',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      Positioned(
        top: 12,
        right: 12,
        child: GestureDetector(
          onTap: () => setState(
              () {
                _selectedImage = null;
                _diagnosis = null;
              }),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: Colors.black.withAlpha(140),
                shape: BoxShape.circle),
            child:
                const Icon(Icons.close, color: Colors.white, size: 16),
          ),
        ),
      ),
      Positioned(
        bottom: 12,
        right: 12,
        child: GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (_) => Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24))),
              child:
                  Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined,
                      color: Colors.teal),
                  title: const Text('Galería'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined,
                      color: Colors.teal),
                  title: const Text('Cámara'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ]),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.circular(20)),
            child: const Row(children: [
              Icon(Icons.refresh, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text('Cambiar',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _buildImagePicker() {
    return Container(
      height: 300,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.teal.withAlpha(80), width: 2),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.teal.withAlpha(25),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: _selectedImage == null
          ? _buildEmptyState()
          : _buildImagePreview(),
    );
  }

  Widget _buildResultadoSano(double confianza) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF2ECC71).withAlpha(80),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 64),
        const SizedBox(height: 16),
        const Text('¡Dentadura Saludable!',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
            'Confianza: ${(confianza * 100).toStringAsFixed(1)}%',
            style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Text(
          _descripcionPorLabel('sano'),
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white.withAlpha(230),
              fontSize: 14,
              height: 1.5),
        ),
      ]),
    );
  }

  Widget _buildResultadoEnfermedad(Map<String, dynamic> diag) {
    final label = diag['label'] as String;
    final confianza = diag['confianza'] as double;
    final scores = diag['scores'] as List<double>;
    final segundaOpcion = diag['segundaOpcion'] as String?;
    final segundaConfianza = diag['segundaConfianza'] as double?;
    final color = _colorPorLabel(label);

    final enfermedades = <MapEntry<String, double>>[];
    for (int i = 0; i < _labels.length; i++) {
      if (_labels[i] != 'Sano' && scores[i] > 0.05) {
        enfermedades.add(MapEntry(_labels[i], scores[i]));
      }
    }
    enfermedades.sort((a, b) => b.value.compareTo(a.value));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color.withAlpha(230), color.withAlpha(170)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: color.withAlpha(80),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                shape: BoxShape.circle),
            child: Icon(_iconPorLabel(label),
                color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('DIAGNÓSTICO PRINCIPAL',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                  'Confianza: ${(confianza * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
      ),

      if (segundaOpcion != null && segundaConfianza != null) ...[
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _colorPorLabel(segundaOpcion).withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _colorPorLabel(segundaOpcion).withAlpha(80)),
          ),
          child: Row(children: [
            Icon(_iconPorLabel(segundaOpcion),
                color: _colorPorLabel(segundaOpcion), size: 16),
            const SizedBox(width: 8),
            Text(
              'También posible: $segundaOpcion '
              '(${(segundaConfianza * 100).toStringAsFixed(1)}%)',
              style: TextStyle(
                  fontSize: 13,
                  color:
                      _colorPorLabel(segundaOpcion).withAlpha(220),
                  fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      ],

      const SizedBox(height: 8),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Icon(Icons.info_outline, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(_descripcionPorLabel(label),
                  style: TextStyle(
                      fontSize: 13,
                      color: color.withAlpha(220),
                      height: 1.4))),
        ]),
      ),

      if (enfermedades.length > 1) ...[
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Condiciones detectadas',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[700])),
        ),
        const SizedBox(height: 8),
        ...enfermedades.map((e) => _buildBarra(e.key, e.value)),
      ],
    ]);
  }

  Widget _buildBarra(String label, double score) {
    final color = _colorPorLabel(label);
    return Container(
      margin:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        Row(children: [
          Icon(_iconPorLabel(label), color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14))),
          Text('${(score * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: color)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score,
            backgroundColor: Colors.grey[100],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }

  // ── Botón "Ver clínicas especializadas" ────────────────────────────────────
  // Solo aparece cuando se detecta una patología (no "Sano" ni "No concluyente")
  Widget _buildClinicButton(String detectedLabel) {
    if (detectedLabel == 'Sano' ||
        detectedLabel == 'No concluyente') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SmartClinicScreen(
              detectedCondition: detectedLabel, // ← pasa el diagnóstico
            ),
          ),
        ),
        icon: const Icon(Icons.local_hospital_rounded, size: 20),
        label: const Text(
          'Ver clínicas especializadas',
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 3,
          shadowColor: Colors.teal.withAlpha(80),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_diagnosis == null) return const SizedBox.shrink();
    final esSano = _diagnosis!['esSano'] as bool;
    final confianza = _diagnosis!['confianza'] as double;
    final label = _diagnosis!['label'] as String;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Resultado del Análisis',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[800])),
        ),
        const SizedBox(height: 12),
        if (esSano)
          _buildResultadoSano(confianza)
        else
          _buildResultadoEnfermedad(_diagnosis!),
        const SizedBox(height: 12),

        // ── Disclaimer ───────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Colors.amber.withAlpha(80)),
          ),
          child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Icon(Icons.warning_amber_outlined,
                color: Colors.amber, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Este análisis es orientativo y no reemplaza un '
                'diagnóstico profesional. Consulta siempre con un '
                'odontólogo certificado.',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.brown,
                    height: 1.4),
              ),
            ),
          ]),
        ),

        // ── Botón Ver Clínicas (solo si hay patología) ───────────
        _buildClinicButton(label),

        const SizedBox(height: 32),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Análisis Dental IA',
            style: TextStyle(
                fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        actions: [
          if (!_modelLoaded)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white)),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.fromLTRB(20, 20, 20, 28),
            decoration: const BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(28))),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('Diagnóstico con IA',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                  'Detecta: Caries · Aftas bucales · Gingivitis · '
                  'Sarro · Dentadura sana',
                  style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 13,
                      height: 1.5)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Icon(
                      _modelLoaded
                          ? Icons.check_circle
                          : Icons.sync,
                      color: _modelLoaded
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      size: 14),
                  const SizedBox(width: 6),
                  Text(
                      _modelLoaded
                          ? 'Modelo listo'
                          : 'Cargando modelo...',
                      style: TextStyle(
                          color: _modelLoaded
                              ? Colors.greenAccent
                              : Colors.orangeAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          _buildImagePicker(),
          _buildResults(),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _interpreter?.close();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
}
