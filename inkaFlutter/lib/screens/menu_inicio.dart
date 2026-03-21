import 'package:flutter/material.dart';
import 'auth_screen.dart';
import 'artist_auth_screen.dart';

class MenuInicio extends StatelessWidget {
  const MenuInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: SingleChildScrollView( // <--- AÑADIDO ESTO AQUÍ
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 60),
                // Título principal
                const Text(
                  'Welcome to Inka',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12), 
                // Subtítulo
                const Text(
                  'Choose how you want to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 50),
                // Primera tarjeta - Buscar tatuajes
                _buildOptionCard(
                  context,
                  icon: Icons.search,
                  iconColor: const Color(0xFF4A9DFF),
                  title: 'Looking to Get Tattooed?',
                  subtitle: 'Discover artists, save inspiration, and book\nyour next piece',
                  onTap: () {
                    // Navegar a pantalla de mapa directamente (Bypass Login)
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AuthScreen()),
                    );
                  },
                ),
                const SizedBox(height: 20),
                // Segunda tarjeta - Soy artista
                _buildOptionCard(
                  context,
                  icon: Icons.palette,
                  iconColor: const Color(0xFF4A9DFF),
                  title: 'Are You a Tattoo Artist?',
                  subtitle: 'Showcase your portfolio and manage\nclient requests',
                  onTap: () {
                    // Navegar a pantalla de registro de artista
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ArtistAuthScreen()),
                    );
                  },
                ),
                const SizedBox(height: 40), // He cambiado Spacer() por SizedBox porque Spacer() no funciona bien dentro de un Scroll
                // Link inferior
                TextButton(
                  onPressed: () {
                    // Navegar a ver componentes
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'View New Components',
                        style: TextStyle(
                          color: Color(0xFF4A9DFF),
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        color: Color(0xFF4A9DFF),
                        size: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF2A2A2A),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Icono circular
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            // Título de la tarjeta
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            // Subtítulo de la tarjeta
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
