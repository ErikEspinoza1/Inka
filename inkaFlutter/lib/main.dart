import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/ar_tattoo_screen.dart';
import 'screens/test_upload_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //Persona 3
  await Supabase.initialize(
    url: 'https://unqfkfunxnlxyatjnyqd.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVucWZrZnVueG5seHlhdGpueXFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3ODM5NTIsImV4cCI6MjA4MTM1OTk1Mn0.Mfe5ykSKG9gds8FNIjnaFuN63VsLZ_89-LZU0KGj8mI',  );
  
  // Bloquear orientación a Portrait para simplificar MVP
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tattoo AR',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Menú Principal Dev")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- BOTÓN 1: EL QUE YA TENÍAS (AR) ---
            ElevatedButton.icon(
              icon: const Icon(Icons.camera),
              label: const Text("PROBAR TATUAJE (AR)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, // Color distintivo
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ArTattooScreen()),
                );
              },
            ),

            const SizedBox(height: 30), // Espacio entre botones

            // --- BOTÓN 2: EL NUEVO (INFRAESTRUCTURA) ---
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload),
              label: const Text("TEST SUBIDA (PERSONA 3)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, // Color distintivo
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TestUploadScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 