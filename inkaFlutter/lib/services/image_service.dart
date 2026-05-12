import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  /// Aplica una marca de agua premium (Logo + Nombre de Artista) usando el Canvas de Flutter.
  static Future<File> applyWatermark({
    required String imagePath,
    required String artistName,
  }) async {
    try {
      // 1. Cargar imagen original
      final Uint8List bytes = await File(imagePath).readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image originalImage = frameInfo.image;

      final double width = originalImage.width.toDouble();
      final double height = originalImage.height.toDouble();

      // 2. Preparar el lienzo (Canvas)
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();

      // Dibujar la imagen base
      canvas.drawImage(originalImage, Offset.zero, paint);

      // 3. Cargar el Logo de Inka
      final ByteData logoData = await rootBundle.load('assets/images/inka_logo.png');
      final ui.Codec logoCodec = await ui.instantiateImageCodec(logoData.buffer.asUint8List());
      final ui.Image logoImage = (await logoCodec.getNextFrame()).image;

      // Tamaño del logo: 18% del ancho de la imagen
      double logoWidth = width * 0.18;
      double logoHeight = (logoWidth * logoImage.height) / logoImage.width;
      
      // Márgenes y posiciones
      double margin = width * 0.05;
      double x = width - logoWidth - margin;
      double y = height - logoHeight - margin - (width * 0.04); 

      final Rect logoRect = Rect.fromLTWH(x, y, logoWidth, logoHeight);
      final Rect srcRect = Rect.fromLTWH(0, 0, logoImage.width.toDouble(), logoImage.height.toDouble());

      // --- DIBUJAR SOMBRA DEL LOGO ---
      canvas.save();
      // Pequeño desplazamiento para la sombra
      canvas.translate(3, 3); 
      final shadowPaint = Paint()
        ..colorFilter = ColorFilter.mode(Colors.black.withValues(alpha: 0.6), BlendMode.srcIn)
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5);
      canvas.drawImageRect(logoImage, srcRect, logoRect, shadowPaint);
      canvas.restore();

      // --- DIBUJAR LOGO REAL ---
      canvas.drawImageRect(
        logoImage,
        srcRect,
        logoRect,
        Paint()..filterQuality = ui.FilterQuality.high,
      );

      // 4. Dibujar Texto (@artista) más pequeño para dar protagonismo a Inka
      final textStyle = GoogleFonts.oswald(
        color: Colors.white.withValues(alpha: 0.9),
        fontSize: width * 0.028, // Tamaño pequeño solicitado
        fontWeight: FontWeight.bold, // Volvemos al Bold que te gustaba
        letterSpacing: 2.0,
        shadows: [
          Shadow(
            offset: const Offset(1.5, 1.5),
            blurRadius: 5.0,
            color: Colors.black.withValues(alpha: 0.8),
          ),
        ],
      );

      final textSpan = TextSpan(
        text: "@${artistName.toUpperCase()}",
        style: textStyle,
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      
      textPainter.layout();

      // Centrar el texto justo debajo del logo
      double textX = x + (logoWidth / 2) - (textPainter.width / 2);
      double textY = y + logoHeight + (width * 0.005);

      textPainter.paint(canvas, Offset(textX, textY));

      // 5. Finalizar y guardar
      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final ByteData? pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
      
      if (pngBytes == null) return File(imagePath);

      final tempDir = await getTemporaryDirectory();
      final String fileName = 'wm_${DateTime.now().millisecondsSinceEpoch}.png';
      final File watermarkedFile = File('${tempDir.path}/$fileName');
      
      await watermarkedFile.writeAsBytes(pngBytes.buffer.asUint8List());

      return watermarkedFile;
    } catch (e) {
      debugPrint("Error en marca de agua: $e");
      return File(imagePath);
    }
  }
}