import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'client_home_screen.dart'; 

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();

  bool _isLogin = true; 
  bool _isLoading = false;

  void _submit() async {
    // 1. PRIMERO: Recoger valores
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    // 2. Validaciones comunes
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor rellena los campos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (_isLogin) {
      // ===========================
      // LÓGICA LOGIN + SEGURIDAD
      // ===========================
      final token = await _authService.login(email, pass);

      if (token != null) {
        // 🔒 VALIDACIÓN: ¿Es cliente normal?
        final role = await _authService.getUserRole();

        // Permitimos 'cliente' y 'admin' aquí, pero bloqueamos 'artista'
        if (role == 'cliente' || role == 'admin') {
          _goToHome(); // ✅ Pasa
        } else {
          // ⛔ Es artista, fuera.
          await _authService.logout();
          _showError('Eres Artista. Por favor inicia sesión en la zona de Profesionales.');
        }
      } else {
        _showError('Credenciales incorrectas o error de conexión');
      }
    } else {
      // ===========================
      // LÓGICA REGISTRO CLIENTE
      // ===========================
      if (name.isEmpty) {
        _showError('El nombre es obligatorio para registrarse');
        setState(() => _isLoading = false);
        return;
      }

      final success = await _authService.register(email, pass, name);
      if (success) {
        // Si se registra bien, hacemos login automático
        await _authService.login(email, pass);
        _goToHome();
      } else {
        _showError('No se pudo registrar. ¿El email ya existe?');
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _goToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ClientHomeScreen()),
      (route) => false,
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fingerprint, size: 80, color: Colors.tealAccent),
              const SizedBox(height: 20),
              Text(
                _isLogin ? 'INKA LOGIN' : 'CREAR CUENTA',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 40),

              // Campo Nombre (Solo en registro)
              if (!_isLogin)
                TextField(
                  controller: _nameCtrl,
                  decoration: _inputDeco('Nombre Completo', Icons.person),
                  style: const TextStyle(color: Colors.white),
                ),
              if (!_isLogin) const SizedBox(height: 16),

              // Campo Email
              TextField(
                controller: _emailCtrl,
                decoration: _inputDeco('Email', Icons.email),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Campo Password
              TextField(
                controller: _passCtrl,
                decoration: _inputDeco('Contraseña', Icons.lock),
                style: const TextStyle(color: Colors.white),
                obscureText: true,
              ),
              const SizedBox(height: 30),

              // Botón Acción
              _isLoading
                  ? const CircularProgressIndicator(color: Colors.tealAccent)
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _submit,
                        child: Text(
                          _isLogin ? 'ENTRAR' : 'REGISTRARSE',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(
                  _isLogin
                      ? '¿No tienes cuenta? Regístrate aquí'
                      : '¿Ya tienes cuenta? Inicia sesión',
                  style: const TextStyle(color: Colors.tealAccent),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.white70),
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.tealAccent),
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: Colors.white10,
    );
  }
}