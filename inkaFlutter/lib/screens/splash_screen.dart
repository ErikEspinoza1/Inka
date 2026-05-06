import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'menu_inicio.dart';
import 'client_home_screen.dart';
import 'artist_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Breve pausa para que se vea el SplashScreen
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;

    final token = await _authService.getToken();
    
    if (token != null) {
      final role = await _authService.getUserRole();
      if (!mounted) return;
      
      if (role == 'artista') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ArtistHomeScreen()),
        );
        return;
      } else if (role == 'cliente' || role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ClientHomeScreen()),
        );
        return;
      }
    }
    
    // Si no hay sesión válida o no tiene rol, ir al menú de inicio
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MenuInicio()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D0D0D),
      body: Center(
        child: CircularProgressIndicator(color: Colors.tealAccent),
      ),
    );
  }
}
