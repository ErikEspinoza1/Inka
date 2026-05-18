import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart'; 
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'artist_profile_screen.dart';
import 'artist_home_screen.dart';

class ArtistAuthScreen extends StatefulWidget {
  const ArtistAuthScreen({super.key});

  @override
  State<ArtistAuthScreen> createState() => _ArtistAuthScreenState();
}

class _ArtistAuthScreenState extends State<ArtistAuthScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController(); 
  final TextEditingController _specialtyCtrl = TextEditingController();
  final TextEditingController _licenseCtrl = TextEditingController();

  // Controladores Dirección detallada
  final TextEditingController _streetCtrl = TextEditingController();
  final TextEditingController _numberCtrl = TextEditingController();
  final TextEditingController _zipCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  void _submit() async {
    // 1. PRIMERO: Recoger valores de los controladores
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final shopName = _nameCtrl.text.trim();
    final specialty = _specialtyCtrl.text.trim();
    final licenseId = _licenseCtrl.text.trim();

    // 2. Validaciones básicas
    if (email.isEmpty || pass.isEmpty) {
      _showError('Email y contraseña obligatorios');
      return;
    }

    setState(() => _isLoading = true);

    if (_isLogin) {
      // ===========================
      // LÓGICA DE LOGIN + SEGURIDAD
      // ===========================
      final token = await _authService.login(email, pass);

      if (token != null) {
        // 🔒 VALIDACIÓN: ¿Es realmente un artista?
        final role = await _authService.getUserRole();

        if (role == 'artista') {
          _goToHome(); // ✅ Es artista, entra.
        } else {
          // ⛔ Es cliente, fuera.
          await _authService.logout();
          _showError('Esta cuenta no es de tatuador. Por favor usa la app de Clientes.');
        }
      } else {
        _showError('Credenciales incorrectas');
      }
    } else {
      // ===========================
      // LÓGICA DE REGISTRO ARTISTA
      // ===========================
      final street = _streetCtrl.text.trim();
      final number = _numberCtrl.text.trim();
      final zip = _zipCtrl.text.trim();
      final city = _cityCtrl.text.trim();

      if (shopName.isEmpty || specialty.isEmpty || street.isEmpty || city.isEmpty || licenseId.isEmpty) {
        _showError('Nombre, Especialidad, Dirección (Calle/Ciudad) y CIF/DNI son obligatorios');
        setState(() => _isLoading = false);
        return;
      }

      if (!_isPasswordSecure(pass)) {
        _showError('La contraseña debe tener al menos 8 caracteres, una mayúscula y un símbolo');
        setState(() => _isLoading = false);
        return;
      }

      // Construir dirección final
      String address = "$street $number, $zip, $city";

      // Geocodificación (Dirección -> Coordenadas)
      double lat = 0.0;
      double lng = 0.0;

      try {
        List<Location> locations = await locationFromAddress(address);
        if (locations.isNotEmpty) {
          lat = locations.first.latitude;
          lng = locations.first.longitude;
        }
      } catch (e) {
        debugPrint("Error geocoding: $e");
      }

      // Llamada al servicio
      final success = await _authService.registerArtist(
        email: email,
        password: pass,
        fullName: shopName,
        specialty: specialty, 
        address: address,
        lat: lat,
        lng: lng,
        businessLicenseId: licenseId,
      );

      if (success) {
        _goToHome();
      } else {
        _showError('Error al registrar artista. Revisa los datos.');
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

  void _goToHome() async {
    NotificationService.initialize();
    final data = await _authService.getArtistProfile();
    if (data != null && data['is_verified'] == true) {
      // Verificado: ir a pantalla principal
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ArtistHomeScreen()),
          (route) => false,
        );
      }
    } else {
      // No verificado: ir a editar perfil para subir certificado
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ArtistProfileScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Theme.of(context).colorScheme.error),
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
            children: [
              Icon(Icons.palette, size: 80, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                _isLogin ? 'ACCESO PROFESIONAL' : 'UNIRSE COMO ARTISTA',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 30),
              if (!_isLogin) ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre Estudio / Artístico', prefixIcon: Icon(Icons.store)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _specialtyCtrl,
                  decoration: const InputDecoration(labelText: 'Estilo (ej. Realismo)', prefixIcon: Icon(Icons.brush)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _streetCtrl,
                        decoration: const InputDecoration(labelText: 'Calle', prefixIcon: Icon(Icons.map)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _numberCtrl,
                        decoration: const InputDecoration(labelText: 'Nº'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cityCtrl,
                        decoration: const InputDecoration(labelText: 'Ciudad', prefixIcon: Icon(Icons.location_city)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _zipCtrl,
                        decoration: const InputDecoration(labelText: 'CP'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _licenseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'CIF / DNI del Titular', 
                    prefixIcon: Icon(Icons.badge_outlined),
                    hintText: 'Necesario para validar el certificado',
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock)),
                obscureText: true,
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: Text(_isLogin ? 'ENTRAR' : 'REGISTRARSE'),
                      ),
                    ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(
                  _isLogin ? 'Crear cuenta de Artista' : 'Ya tengo cuenta',
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}