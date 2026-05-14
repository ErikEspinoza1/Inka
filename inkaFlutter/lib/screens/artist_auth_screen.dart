import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart'; 
import '../services/auth_service.dart';
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
  final TextEditingController _addressCtrl = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  void _submit() async {
    // 1. PRIMERO: Recoger valores de los controladores
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final shopName = _nameCtrl.text.trim();
    final specialty = _specialtyCtrl.text.trim();
    final address = _addressCtrl.text.trim();

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
      if (shopName.isEmpty || specialty.isEmpty || address.isEmpty) {
        _showError('Nombre, Especialidad y Dirección son obligatorios');
        setState(() => _isLoading = false);
        return;
      }

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
        specialty: specialty, // ¡Ojo! Asegúrate de pasar specialty aquí
        address: address,
        lat: lat,
        lng: lng,
      );

      if (success) {
        _goToHome();
      } else {
        _showError('Error al registrar artista. Revisa los datos.');
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _goToHome() async {
    final data = await _authService.getArtistProfile();
    if (data != null && data['is_verified'] == true) {
      // Verificado: ir a pantalla principal
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ArtistHomeScreen()),
        (route) => false,
      );
    } else {
      // No verificado: ir a editar perfil para subir certificado
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ArtistProfileScreen()),
        (route) => false,
      );
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
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.palette, size: 80, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                _isLogin ? 'ARTIST LOGIN' : 'JOIN AS ARTIST',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 30),
              if (!_isLogin) ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: 'Nombre Estudio / Artístico', prefixIcon: const Icon(Icons.store)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _specialtyCtrl,
                  decoration: InputDecoration(labelText: 'Estilo (ej. Realismo)', prefixIcon: const Icon(Icons.brush)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _addressCtrl,
                  decoration: InputDecoration(labelText: 'Dirección (Calle, Ciudad)', prefixIcon: const Icon(Icons.map)),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailCtrl,
                decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                decoration: InputDecoration(labelText: 'Contraseña', prefixIcon: const Icon(Icons.lock)),
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