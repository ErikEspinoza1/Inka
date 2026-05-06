import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta de colores central "Inka"
  static const Color background = Color(0xFF080808); // Negro profundo
  static const Color surface = Color(0xFF1A1A1A); // Gris oscuro
  static const Color primary = Color(0xFF1DE9B6); // Azul Turquesa (Teal Accent)
  static const Color primaryVariant = Color(0xFF00BFA5); 
  static const Color secondary = Color(0xFFD4AF37); // Dorado para estrellas o acentos premium
  static const Color textMain = Color(0xFFF5F5F5); // Blanco roto
  static const Color textSecondary = Color(0xFFA0A0A0); // Gris claro para subtítulos
  static const Color success = Color(0xFF2E7D32); // Verde sobrio
  static const Color error = Color(0xFFD32F2F); // Rojo oscuro para errores

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
        onPrimary: textMain,
        onSecondary: background,
        onSurface: textMain,
      ),
      
      // Tipografía global (Inter para cuerpo, Oswald/Bebas para Títulos grandes si se sobreescriben)
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.oswald(color: textMain, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.oswald(color: textMain, fontWeight: FontWeight.bold),
        displaySmall: GoogleFonts.oswald(color: textMain, fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.oswald(color: textMain, fontWeight: FontWeight.w600),
        headlineMedium: GoogleFonts.oswald(color: textMain, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.inter(color: textMain, fontWeight: FontWeight.bold),
        bodyLarge: GoogleFonts.inter(color: textMain),
        bodyMedium: GoogleFonts.inter(color: textMain),
        bodySmall: GoogleFonts.inter(color: textSecondary),
      ),

      // AppBar Global
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textMain),
        titleTextStyle: GoogleFonts.oswald(
          color: textMain,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),

      // Botones Elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textMain,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Botones Outlined
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      
      // Botones de Texto
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textMain, // Color por defecto
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),

      // Inputs de Texto
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: GoogleFonts.inter(color: textSecondary),
        labelStyle: GoogleFonts.inter(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        prefixIconColor: textSecondary,
      ),

      // Tarjetas (Cards)
      cardTheme: CardThemeData(
        color: surface,
        elevation: 4,
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      
      // ListTiles
      listTileTheme: const ListTileThemeData(
        iconColor: primary,
        textColor: textMain,
      ),

      // Progreso (Loading indicators)
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
      ),
    );
  }
}
