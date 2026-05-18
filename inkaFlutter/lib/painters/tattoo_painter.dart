import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
<<<<<<< HEAD
import '../screens/ar_tattoo_screen.dart';

class TattooPainter extends CustomPainter {
  final ui.Image? tattooImage;
  final PoseLandmark? startPoint;
  final PoseLandmark? endPoint;

  final Size absoluteImageSize;
  final bool isFrontCamera; 
  final int sensorOrientation;

  final double scaleFactor;
  final double positionX;
  final double positionY;
  final double rotationManual;
  final double opacity;
  final double rotationOffset;
  final BodyZone selectedZone;
=======

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
>>>>>>> parent of 1a8214c (a)

  TattooPainter({
    required this.tattooImage,
    required this.startPoint,
    required this.endPoint,
    required this.absoluteImageSize,
    required this.isFrontCamera,
    required this.scaleFactor,
    required this.positionX,
    required this.positionY,
    required this.rotationManual,
    required this.opacity,
    required this.rotationOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (tattooImage == null || startPoint == null || endPoint == null) return;

<<<<<<< HEAD
    final bool isRotated = sensorOrientation == 90 || sensorOrientation == 270;
    final double scX = isRotated
        ? size.width / absoluteImageSize.height
        : size.width / absoluteImageSize.width;
    final double scY = isRotated
        ? size.height / absoluteImageSize.width
        : size.height / absoluteImageSize.height;

    // --- CORRECCIÓN DEL ESPEJO (CAMERA MIRRORING) ---
    double rawStartX = isFrontCamera 
        ? absoluteImageSize.width - startPoint!.x 
        : startPoint!.x;
    double rawEndX = isFrontCamera 
        ? absoluteImageSize.width - endPoint!.x 
        : endPoint!.x;

    double sX = rawStartX * scX;
    double sY = startPoint!.y * scY;
    double eX = rawEndX * scX;
    double eY = endPoint!.y * scY;

    final distance = sqrt(pow(eX - sX, 2) + pow(eY - sY, 2));
    if (distance < 10) return;

    bool isFlat = false;
    double maxTaper = 0.0;
    double gravityDrop = 0.0;

    switch (selectedZone) {
      case BodyZone.head:
        isFlat = true;
        gravityDrop = -0.5;
        break;
      case BodyZone.neck:
        isFlat = false;
        maxTaper = 0.05;
        gravityDrop = 0.25;
        break;
      case BodyZone.chest:
      case BodyZone.back:
      case BodyZone.stomach:
        isFlat = true;
        gravityDrop = 0.35;
        break;
      case BodyZone.leftHand:
      case BodyZone.rightHand:
      case BodyZone.leftFoot:
      case BodyZone.rightFoot:
        isFlat = false;
        maxTaper = 0.4;
        break;
      case BodyZone.leftForearm:
      case BodyZone.rightForearm:
      case BodyZone.leftCalf:
      case BodyZone.rightCalf:
        isFlat = false;
        maxTaper = 0.35;
        break;
      default:
        isFlat = false;
        maxTaper = 0.15;
    }

    // Desplazamiento vertical manual libre
    double verticalScreenOffset = (positionY - 0.5) * distance * 2.5;

    double bX = sX + (eX - sX) * positionX;
    double bY = sY + (eY - sY) * positionX;

    double cX = bX;
    double cY = bY + (isFlat ? (distance * gravityDrop) : 0.0) + verticalScreenOffset;
=======
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true
      ..color = Colors.white.withOpacity(opacity); // Aquí aplicamos la transparencia

    // 1. Escalar coordenadas
    final double scaleX = size.width / absoluteImageSize.height;
    final double scaleY = size.height / absoluteImageSize.width;

    final startX = startPoint!.x * scaleX;
    final startY = startPoint!.y * scaleY;
    final endX = endPoint!.x * scaleX;
    final endY = endPoint!.y * scaleY;

    // 2. MATEMÁTICA DE POSICIÓN (Interpolación Lineal)
    // En lugar de dividir entre 2, nos movemos un porcentaje del camino
    final centerX = startX + (endX - startX) * positionFactor;
    final centerY = startY + (endY - startY) * positionFactor;
    
    // Ángulo automático de la IA + Rotación Manual del usuario - Offset de zona
    final angle = atan2(endY - startY, endX - startX) - rotationOffset + rotationManual;
    
    // Distancia para calcular la base del tamaño
    final distance = sqrt(pow(endX - startX, 2) + pow(endY - startY, 2));

    // 3. Tamaño
    final double desiredSize = distance * scaleFactor;
    final double imageScale = desiredSize / tattooImage!.width.toDouble();

    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.rotate(angle); 
    canvas.scale(imageScale, imageScale);
>>>>>>> parent of 1a8214c (a)

    final angle = atan2(eY - sY, eX - sX) - rotationOffset + rotationManual;
    final double imgW = tattooImage!.width.toDouble();
    final double imgH = tattooImage!.height.toDouble();
<<<<<<< HEAD

    final double stableScale = pow(distance / size.width, 0.85) * size.width;
    final double imageScale = (stableScale * scaleFactor) / imgH;
    final double dW = imgW * imageScale;
    final double dH = imgH * imageScale;

    final Float64List identityMatrix = Float64List.fromList([
      1.0, 0.0, 0.0, 0.0,
      0.0, 1.0, 0.0, 0.0,
      0.0, 0.0, 1.0, 0.0,
      0.0, 0.0, 0.0, 1.0,
    ]);

    final paint = Paint()
      ..shader = ui.ImageShader(tattooImage!, ui.TileMode.clamp, ui.TileMode.clamp, identityMatrix)
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 0.6, sigmaY: 0.6)
      ..colorFilter = const ui.ColorFilter.mode(ui.Color(0x224A2511), ui.BlendMode.srcOver)
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    canvas.save();
    canvas.translate(cX, cY);
    canvas.rotate(angle);

    const int vSlices = 20;
    const int hVertices = 20;
    final double sH = dH / vSlices;

    List<ui.Offset> pos = [];
    List<ui.Offset> tex = [];
    List<ui.Color> cols = [];
    List<int> idx = [];
    final rand = Random();

    for (int y = 0; y <= vSlices; y++) {
      final double taper = 1.0 - ((y / vSlices) * maxTaper);
      final double cW = dW * taper;

      for (int x = 0; x < hVertices; x++) {
        final double nx = x / (hVertices - 1);
        final double theta = (nx - 0.5) * pi;

        double dx = isFlat ? (nx - 0.5) * cW : sin(theta) * (cW / 2);
        double dy = (-dH / 2) + (y * sH);

        final double bump = sin((y / vSlices) * 35.0) * cos(theta * 10.0) * 1.2;

        pos.add(ui.Offset(dx + bump, dy + bump));
        tex.add(ui.Offset(nx * imgW, (y / vSlices) * imgH));

        final double shadow = isFlat ? 1.0 : (cos(theta) + 1.0) / 2.0;
        final double spec = isFlat ? 0.0 : pow(max(0.0, cos(theta)), 6) * 0.2;
        double intensity = (0.8 + (shadow * 0.15) + spec + (rand.nextDouble() * 0.04)).clamp(0.0, 1.0);

        // Desvanecimiento curvo en los bordes
        double edgeVis = isFlat ? 1.0 : pow(max(0.0, cos(theta)), 0.4).toDouble();

        cols.add(ui.Color.fromARGB(
            (opacity * edgeVis * 255).round(),
            (intensity * 255).round(),
            (intensity * 255).round(),
            (intensity * 255).round()));
      }
    }

    for (int y = 0; y < vSlices; y++) {
      for (int x = 0; x < hVertices - 1; x++) {
        int tl = (y * hVertices) + x;
        int tr = tl + 1;
        int bl = ((y + 1) * hVertices) + x;
        int br = bl + 1;
        
        idx.addAll([tl, tr, bl]);
        idx.addAll([tr, br, bl]);
      }
    }

    canvas.drawVertices(
        ui.Vertices(ui.VertexMode.triangles, pos, textureCoordinates: tex, colors: cols, indices: idx),
        ui.BlendMode.modulate,
        paint);
        
=======
    
    canvas.drawImage(tattooImage!, Offset(-imgW / 2, -imgH / 2), paint);
>>>>>>> parent of 1a8214c (a)
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TattooPainter oldDelegate) {
<<<<<<< HEAD
    return oldDelegate.startPoint      != startPoint      ||
           oldDelegate.endPoint        != endPoint        ||
           oldDelegate.positionX       != positionX       ||
           oldDelegate.positionY       != positionY       ||
           oldDelegate.scaleFactor     != scaleFactor     ||
           oldDelegate.rotationManual  != rotationManual  ||
           oldDelegate.opacity         != opacity         ||
           oldDelegate.selectedZone    != selectedZone    ||
           oldDelegate.isFrontCamera   != isFrontCamera   ||
           oldDelegate.sensorOrientation != sensorOrientation;
=======
    return oldDelegate.positionFactor != positionFactor || 
           oldDelegate.scaleFactor != scaleFactor ||
           oldDelegate.rotationManual != rotationManual ||
           oldDelegate.opacity != opacity ||
           oldDelegate.startPoint != startPoint;
>>>>>>> parent of 1a8214c (a)
  }
}