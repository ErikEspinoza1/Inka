import 'package:flutter/material.dart';
import 'auth_screen.dart';
import 'artist_auth_screen.dart';

class MenuInicio extends StatelessWidget {
  const MenuInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Logo principal
              Image.asset(
                'assets/images/inka_logo.png',
                height: 80,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 10),
              // Subtítulo
              Text(
                'Elige cómo quieres continuar',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              // Primera tarjeta - Buscar tatuajes
              _buildOptionCard(
                context,
                icon: Icons.search,
                title: '¿Buscas tatuarte?',
                subtitle:
                    'Descubre artistas, guarda inspiración\ny reserva tu próxima pieza',
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
                title: '¿Eres tatuador?',
                subtitle:
                    'Muestra tu portfolio y gestiona\nsolicitudes de clientes',
                onTap: () {
                  // Navegar a pantalla de registro de artista
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ArtistAuthScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            children: [
              // Icono circular
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              // Título de la tarjeta
              Text(
                title,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              // Subtítulo de la tarjeta
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
