import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'services/auth_service.dart';
import 'screens/menu_inicio.dart';
import 'screens/client_home_screen.dart';
import 'screens/artist_home_screen.dart';
import 'theme/app_theme.dart';
import 'providers/interaction_provider.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await dotenv.load(fileName: ".env");

  // Inicialización de Supabase (Mantenemos tu configuración original)
  await Supabase.initialize(
    url: 'https://unqfkfunxnlxyatjnyqd.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVucWZrZnVueG5seHlhdGpueXFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3ODM5NTIsImV4cCI6MjA4MTM1OTk1Mn0.Mfe5ykSKG9gds8FNIjnaFuN63VsLZ_89-LZU0KGj8mI',
  );

  // Bloquear orientación vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Lógica de sesión directamente en el arranque
  final authService = AuthService();
  Widget initialScreen = const MenuInicio();

  final token = await authService.getToken();
  if (token != null) {
    final role = await authService.getUserRole();
    if (role == 'artista') {
      initialScreen = const ArtistHomeScreen();
    } else if (role == 'cliente' || role == 'admin') {
      initialScreen = const ClientHomeScreen();
    }
  }

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    // Eliminamos el splash nativo cuando el primer frame de la pantalla real se dibuje
    FlutterNativeSplash.remove();

    return ChangeNotifierProvider(
      create: (_) => InteractionProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Inka',
        theme: AppTheme.darkTheme,
        builder: (context, child) {
          return ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(
              overscroll: false,
              physics: const BouncingScrollPhysics(),
            ),
            child: child!,
          );
        },
        home: initialScreen,
      ),
    );
  }
}
