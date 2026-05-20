import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
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
  bool _acceptedTerms = false;

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

      if (!_isPasswordSecure(pass)) {
        _showError('La contraseña debe tener al menos 8 caracteres, una mayúscula y un símbolo');
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

  bool _isPasswordSecure(String pass) {
    if (pass.length < 8) return false;
    if (!pass.contains(RegExp(r'[A-Z]'))) return false;
    if (!pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;
    return true;
  }

  void _goToHome() {
    NotificationService.initialize();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ClientHomeScreen()),
      (route) => false,
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  void _showTermsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Términos y Condiciones - INKA', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              const Text(
                '1. Naturaleza del Servicio: INKA es una plataforma de intermediación tecnológica (Ley 34/2002). No procesamos pagos. Cualquier transacción económica (Bizum, efectivo) es estrictamente privada entre cliente y artista. INKA no se hace responsable de disputas o impagos.\n\n'
                '2. Derechos de Imagen: El usuario declara ser el autor de las imágenes subidas o poseer el consentimiento de las personas que aparecen en ellas (Ley Orgánica 1/1982).\n\n'
                '3. Procesamiento de IA: El usuario acepta que las imágenes subidas puedan ser procesadas por Inteligencias Artificiales de terceros para habilitar la simulación AR y la búsqueda vectorial (RGPD).',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fingerprint, size: 80, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                _isLogin ? 'INICIAR SESIÓN' : 'CREAR CUENTA',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 40),

              // Campo Nombre (Solo en registro)
              if (!_isLogin)
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre Completo', prefixIcon: Icon(Icons.person)),
                ),
              if (!_isLogin) const SizedBox(height: 16),

              // Campo Email
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 20),

              // Campo Password
              TextField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock)),
                obscureText: true,
              ),
              const SizedBox(height: 20),

              // Checkbox Legal (Solo en registro)
              if (!_isLogin)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _acceptedTerms,
                      onChanged: (val) {
                        setState(() {
                          _acceptedTerms = val ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showTermsModal,
                        child: Text.rich(
                          TextSpan(
                            text: 'He leído y acepto la ',
                            style: Theme.of(context).textTheme.bodyMedium,
                            children: [
                              TextSpan(
                                text: 'Política de Privacidad y los Términos de Uso',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (!_isLogin) const SizedBox(height: 20),

              // Botón Acción
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (!_isLogin && !_acceptedTerms) ? null : _submit,
                        child: Text(_isLogin ? 'ENTRAR' : 'REGISTRARSE'),
                      ),
                    ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(
                  _isLogin
                      ? '¿No tienes cuenta? Regístrate aquí'
                      : '¿Ya tienes cuenta? Inicia sesión',
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}