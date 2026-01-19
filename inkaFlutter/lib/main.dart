import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Importamos la pantalla de Login
import 'screens/auth_screen.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Supabase (Mantenemos tu configuración original)
  await Supabase.initialize(
    url: 'https://unqfkfunxnlxyatjnyqd.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVucWZrZnVueG5seHlhdGpueXFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3ODM5NTIsImV4cCI6MjA4MTM1OTk1Mn0.Mfe5ykSKG9gds8FNIjnaFuN63VsLZ_89-LZU0KGj8mI',
  );
  
  // Bloquear orientación vertical
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
      // AQUÍ ESTÁ EL CAMBIO:
      // En lugar de ir a HomeScreen, vamos primero a AuthScreen (Login)
      home: const AuthScreen(),
    );
  }
}