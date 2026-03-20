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

    // Escalado correcto según orientación del sensor
    final bool isRotated = sensorOrientation == 90 || sensorOrientation == 270;
    final double scaleX = isRotated
        ? size.width  / absoluteImageSize.height
        : size.width  / absoluteImageSize.width;
    final double scaleY = isRotated
        ? size.height / absoluteImageSize.width
        : size.height / absoluteImageSize.height;

    // Coordenadas escaladas + espejo horizontal para cámara frontal
    double startX = size.width - (startPoint!.x * scaleX);
    double startY = startPoint!.y * scaleY;
    double endX   = size.width - (endPoint!.x * scaleX);
    double endY   = endPoint!.y * scaleY;

    final centerX  = startX + (endX - startX) * positionFactor;
    final centerY  = startY + (endY - startY) * positionFactor;
    final angle    = atan2(endY - startY, endX - startX) - rotationOffset + rotationManual;
    final distance = sqrt(pow(endX - startX, 2) + pow(endY - startY, 2));

    if (distance < 10) return;

    final double imgW      = tattooImage!.width.toDouble();
    final double imgH      = tattooImage!.height.toDouble();
    final double imageScale = (distance * scaleFactor) / imgW;

    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias   = true
      ..color         = Colors.white.withOpacity(opacity)
      ..blendMode     = BlendMode.multiply;

    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.rotate(angle);
    canvas.scale(imageScale, imageScale);

    canvas.drawImage(tattooImage!, Offset(-imgW / 2, -imgH / 2), paint);

    // Sombra lateral para simular volumen 3D
    final volumePaint = Paint()
      ..blendMode = BlendMode.multiply
      ..shader = ui.Gradient.linear(
        Offset(-imgW / 2, 0),
        Offset( imgW / 2, 0),
        [
          Colors.black.withOpacity(0.3),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withOpacity(0.3),
        ],
        [0.0, 0.2, 0.8, 1.0],
      );

    canvas.drawRect(
      Rect.fromLTWH(-imgW / 2, -imgH / 2, imgW, imgH),
      volumePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TattooPainter oldDelegate) {
    return oldDelegate.startPoint        != startPoint        ||
           oldDelegate.endPoint          != endPoint          ||
           oldDelegate.positionFactor    != positionFactor    ||
           oldDelegate.scaleFactor       != scaleFactor       ||
           oldDelegate.rotationManual    != rotationManual    ||
           oldDelegate.opacity           != opacity           ||
           oldDelegate.sensorOrientation != sensorOrientation;
  }
}