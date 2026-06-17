// lib/login/screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/custom_textfield.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _emailEnviado = false;

  void _enviarRecuperacion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _authService
          .sendPasswordResetEmail(_emailController.text.trim());
      if (mounted) setState(() => _emailEnviado = true);
    } catch (e) {
      if (mounted) {
        String mensaje = 'Error al enviar el correo';
        if (e.toString().contains('user-not-found')) {
          mensaje = 'No existe una cuenta con ese correo';
        } else if (e.toString().contains('invalid-email')) {
          mensaje = 'Correo inválido';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _emailEnviado
              ? _buildSuccessView()
              : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),

          // ── Ícono ─────────────────────────────────────────
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.teal.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_reset,
                size: 48,
                color: Colors.teal,
              ),
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'Recuperar Contraseña',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
            style: TextStyle(color: Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 32),

          CustomTextField(
            label: 'Correo electrónico',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Por favor ingresa tu email';
              }
              if (!v.contains('@')) return 'Ingresa un email válido';
              return null;
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _enviarRecuperacion,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Enviar enlace',
                      style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 60),

        // ── Check animado ─────────────────────────────────
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 54,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 32),

        const Text(
          '¡Correo enviado!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 12),

        Text(
          'Enviamos un enlace a:\n${_emailController.text.trim()}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Revisa tu bandeja de entrada y spam.',
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
        const SizedBox(height: 40),

        // ── Reenviar ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withAlpha(60)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: Colors.blue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'El enlace expira en 1 hora. Si no lo recibes, '
                  'revisa que el correo sea correcto.',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() {
              _emailEnviado = false;
              _emailController.clear();
            }),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Usar otro correo'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Volver al inicio de sesión',
            style: TextStyle(color: Colors.teal),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}