// lib/painters/tattoo_painter.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class TattooPainter extends CustomPainter {
  final ui.Image? tattooImage;
  final PoseLandmark? startPoint;
  final PoseLandmark? endPoint;
  final Size absoluteImageSize;
  final int sensorOrientation;

  final double scaleFactor;
  final double positionFactor;
  final double rotationManual;
  final double opacity;
  final double rotationOffset;

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
    this.sensorOrientation = 90,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (tattooImage == null || startPoint == null || endPoint == null) return;
    if (absoluteImageSize.width == 0 || absoluteImageSize.height == 0) return;

    // --- 1. Escalado según orientación del sensor ---
    final bool isRotated = sensorOrientation == 90 || sensorOrientation == 270;
    final double scaleX = isRotated
        ? size.width  / absoluteImageSize.height
        : size.width  / absoluteImageSize.width;
    final double scaleY = isRotated
        ? size.height / absoluteImageSize.width
        : size.height / absoluteImageSize.height;

    // --- 2. Coordenadas con efecto ESPEJO para cámara frontal ---
    double startX = size.width - (startPoint!.x * scaleX);
    double startY = startPoint!.y * scaleY;
    double endX   = size.width - (endPoint!.x * scaleX);
    double endY   = endPoint!.y * scaleY;

    // --- 3. Cálculos de centro, ángulo y distancia ---
    final centerX  = startX + (endX - startX) * positionFactor;
    final centerY  = startY + (endY - startY) * positionFactor;
    final angle    = atan2(endY - startY, endX - startX) - rotationOffset + rotationManual;
    final distance = sqrt(pow(endX - startX, 2) + pow(endY - startY, 2));

    if (distance < 10) return;

    final double imgW = tattooImage!.width.toDouble();
    final double imgH = tattooImage!.height.toDouble();
    
    // ARREGLO 1 (El tamaño): Calculamos la escala basándonos en la ALTURA (imgH)
    // Así el tatuaje no se hace gigante si la imagen es estrecha.
    final double imageScale = (distance * scaleFactor) / imgH;
    final double drawnWidth = imgW * imageScale;
    final double drawnHeight = imgH * imageScale;

    // ARREGLO 2 (El borrón): Un solo filtro de multiplicación para integración en la piel
    final paint = Paint()
      ..filterQuality = FilterQuality.high // Mantiene la imagen HD nítida
      ..isAntiAlias   = true
      ..blendMode     = BlendMode.multiply;

    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.rotate(angle);

    // --- 4. DEFORMACIÓN CILÍNDRICA (Malla UV) ---
    const int verticalSlices = 10;
    const int horizontalVertices = 10;

    final double sliceWidth = drawnWidth / (horizontalVertices - 1);
    final double sliceHeight = drawnHeight / verticalSlices;

    List<ui.Offset> positions = [];
    List<ui.Offset> textureCoordinates = [];
    List<ui.Color> colors = [];
    List<int> indices = [];

    for (int y = 0; y <= verticalSlices; y++) {
      for (int x = 0; x < horizontalVertices; x++) {
        final double normX = x / (horizontalVertices - 1);
        final double normY = y / verticalSlices;

        final double flatY = (-drawnHeight / 2) + (y * sliceHeight);

        final double theta = (normX - 0.5) * pi;
        final double distortedX = sin(theta) * (drawnWidth / 2);

        // ARREGLO 3 (Sombra suave): Hacemos la sombra mucho más sutil (mínimo 80% de luz)
        // para que no ensucie los bordes del tatuaje.
        final double brightness = (cos(theta) + 1.0) / 2.0; 
        final double intensity = 0.8 + (brightness * 0.2); 
        
        final int alphaValue = (opacity * 255).round();
        final int colorV = (intensity * 255).round();

        positions.add(ui.Offset(distortedX, flatY));
        textureCoordinates.add(ui.Offset(normX * imgW, normY * imgH));
        colors.add(ui.Color.fromARGB(alphaValue, colorV, colorV, colorV));
      }
    }

    for (int y = 0; y < verticalSlices; y++) {
      for (int x = 0; x < horizontalVertices - 1; x++) {
        final int topLeft = (y * horizontalVertices) + x;
        final int topRight = topLeft + 1;
        final int bottomLeft = ((y + 1) * horizontalVertices) + x;
        final int bottomRight = bottomLeft + 1;

        indices.addAll([topLeft, topRight, bottomLeft]);
        indices.addAll([topRight, bottomRight, bottomLeft]);
      }
    }

    canvas.drawVertices(
      ui.Vertices(
        ui.VertexMode.triangles,
        positions,
        textureCoordinates: textureCoordinates,
        colors: colors,
        indices: indices,
      ),
      ui.BlendMode.modulate, 
      paint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TattooPainter oldDelegate) {
    return oldDelegate.startPoint      != startPoint      ||
           oldDelegate.endPoint        != endPoint        ||
           oldDelegate.positionFactor  != positionFactor  ||
           oldDelegate.scaleFactor     != scaleFactor     ||
           oldDelegate.rotationManual  != rotationManual  ||
           oldDelegate.opacity         != opacity         ||
           oldDelegate.sensorOrientation != sensorOrientation;
  }
}