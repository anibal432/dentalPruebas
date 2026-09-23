// lib/screens/feedback_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/feedback_service.dart';

// ── Paleta institucional ──────────────────────────────────────
const Color _kPrimary     = Color(0xFF3D3D8F);
const Color _kPrimaryDark = Color(0xFF2A2A6E);
const Color _kSurface     = Color(0xFFF0F0FA);
const Color _kLightFill   = Color(0xFFD0D0F0);

/// Pantalla para que el usuario envíe una opinión/calificación de la app.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _service = FeedbackService();
  final _mensajeController = TextEditingController();

  int _calificacion = 5;
  bool _enviando = false;

  Future<void> _enviar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_mensajeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe tu opinión antes de enviar')),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      await _service.enviarFeedback(
        uid: user.uid,
        nombre: user.displayName ?? user.email ?? 'Usuario',
        mensaje: _mensajeController.text.trim(),
        calificacion: _calificacion,
      );

      if (!mounted) return;
      _mensajeController.clear();
      setState(() => _calificacion = 5);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Gracias por tu opinión!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _buildEstrellas() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final valor = i + 1;
        return IconButton(
          iconSize: 36,
          icon: Icon(
            valor <= _calificacion
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            color: valor <= _calificacion ? Colors.amber : _kLightFill,
          ),
          onPressed: () => setState(() => _calificacion = valor),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: const Text('Enviar Feedback'),
        backgroundColor: _kPrimaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kLightFill),
              ),
              child: Column(
                children: [
                  const Icon(Icons.feedback_outlined,
                      size: 40, color: _kPrimary),
                  const SizedBox(height: 10),
                  const Text(
                    '¿Cómo calificarías tu experiencia?',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  _buildEstrellas(),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Cuéntanos más',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: _kPrimaryDark),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _mensajeController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText:
                    'Comentarios, sugerencias o problemas que encontraste...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kLightFill),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _enviando ? null : _enviar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enviar Feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }
}