import 'package:flutter/material.dart';
// Importamos las otras pantallas para poder navegar a ellas
import 'ar_tattoo_screen.dart';
import 'test_upload_screen.dart';
import 'unity_test_screen.dart';
// Si tuvieras AuthService para hacer logout, lo importarías aquí también
import '../services/auth_service.dart'; 
import 'auth_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _logout(BuildContext context) async {
    final authService = AuthService();  
    await authService.logout();
    
    // Volver al Login eliminando el historial
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Menú Principal Dev"),
        actions: [
          // Botón de Logout opcional
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => _logout(context),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- BOTÓN 1: AR TATTOO ---
            ElevatedButton.icon(
              icon: const Icon(Icons.camera),
              label: const Text("PROBAR TATUAJE (AR)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ArTattooScreen()),
                );
              },
            ),

            const SizedBox(height: 30),

            // --- BOTÓN 2: SUBIDA IMAGEN ---
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload),
              label: const Text("TEST SUBIDA (PERSONA 3)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TestUploadScreen()),
                );
              },
            ),

            const SizedBox(height: 30),

            // --- BOTÓN 3: TEST UNITY ---
            ElevatedButton.icon(
              icon: const Icon(Icons.sports_esports),
              label: const Text("TEST UNITY INTEGRATION"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UnityTestScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}