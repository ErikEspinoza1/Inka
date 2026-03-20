import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class TattooPainter extends CustomPainter {
  final ui.Image? tattooImage;
  final PoseLandmark? startPoint; // Ej: Codo
  final PoseLandmark? endPoint;   // Ej: Muñeca
  final Size absoluteImageSize;
  
  // --- VARIABLES DE AJUSTE ---
  final double scaleFactor;    // Tamaño
  final double positionFactor; // Posición (0.0 a 1.0)
  final double rotationManual; // Rotación extra del usuario
  final double opacity;        // Transparencia (Realismo)
  final double rotationOffset; // Offset de la zona (Pecho vs Brazo)

  TattooPainter({
    required this.tattooImage,
    required this.startPoint,
    required this.endPoint,
    required this.absoluteImageSize,
    required this.scaleFactor,
    required this.positionFactor,
    required this.rotationManual,
    required this.opacity,
    required this.rotationOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (tattooImage == null || startPoint == null || endPoint == null) return;

    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true
      ..color = Colors.white.withValues(alpha: opacity); // Aplicamos transparencia con sintaxis moderna

    // 1. Escalar coordenadas de la imagen de la cámara al tamaño de la pantalla
    final double scaleX = size.width / absoluteImageSize.height;
    final double scaleY = size.height / absoluteImageSize.width;

    final startX = startPoint!.x * scaleX;
    final startY = startPoint!.y * scaleY;
    final endX = endPoint!.x * scaleX;
    final endY = endPoint!.y * scaleY;

    // 2. MATEMÁTICA DE POSICIÓN (Interpolación Lineal)
    // Calculamos el centro basado en el slider de posición
    final centerX = startX + (endX - startX) * positionFactor;
    final centerY = startY + (endY - startY) * positionFactor;
    
    // Ángulo automático de la IA + Rotación Manual del usuario - Offset de zona
    final angle = atan2(endY - startY, endX - startX) - rotationOffset + rotationManual;
    
    // Distancia para calcular la base del tamaño
    final distance = sqrt(pow(endX - startX, 2) + pow(endY - startY, 2));

    // 3. Cálculo de escala de la imagen
    final double desiredSize = distance * scaleFactor;
    final double imageScale = desiredSize / tattooImage!.width.toDouble();

    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.rotate(angle); 
    canvas.scale(imageScale, imageScale);

    final double imgW = tattooImage!.width.toDouble();
    final double imgH = tattooImage!.height.toDouble();
    
    // Dibujamos centrado en el punto calculado
    canvas.drawImage(tattooImage!, Offset(-imgW / 2, -imgH / 2), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TattooPainter oldDelegate) {
    return oldDelegate.positionFactor != positionFactor || 
           oldDelegate.scaleFactor != scaleFactor ||
           oldDelegate.rotationManual != rotationManual ||
           oldDelegate.opacity != opacity ||
           oldDelegate.startPoint != startPoint;
  }
}