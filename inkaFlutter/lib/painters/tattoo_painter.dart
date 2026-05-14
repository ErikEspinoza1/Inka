// lib/painters/tattoo_painter.dart
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../screens/ar_tattoo_screen.dart'; // Needed to import the BodyZone enum

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
  final BodyZone selectedZone; 

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
    required this.selectedZone,
    this.sensorOrientation = 90,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (tattooImage == null || startPoint == null || endPoint == null) return;
    if (absoluteImageSize.width == 0 || absoluteImageSize.height == 0) return;

    final bool isRotated = sensorOrientation == 90 || sensorOrientation == 270;
    final double scaleX = isRotated ? size.width / absoluteImageSize.height : size.width / absoluteImageSize.width;
    final double scaleY = isRotated ? size.height / absoluteImageSize.width : size.height / absoluteImageSize.height;

    double startX = size.width - (startPoint!.x * scaleX);
    double startY = startPoint!.y * scaleY;
    double endX   = size.width - (endPoint!.x * scaleX);
    double endY   = endPoint!.y * scaleY;

    final distance = sqrt(pow(endX - startX, 2) + pow(endY - startY, 2));
    if (distance < 10) return;

    final double normalizedDistance = distance / size.width;
    final double stableScale = pow(normalizedDistance, 0.85) * size.width;

    // --- ANATOMY LOGIC WITH EXHAUSTIVE SWITCH (FIXED) ---
    bool isFlat = false;
    double maxTaper = 0.0;
    double gravityDrop = 0.0;

    switch (selectedZone) {
      case BodyZone.head:
        isFlat = true;
        maxTaper = 0.0;
        gravityDrop = -0.5; // Offset up to the forehead
        break;
      case BodyZone.neck:
        isFlat = false;
        maxTaper = 0.05;
        gravityDrop = 0.25; // Offset down from ears
        break;
      case BodyZone.chest:
      case BodyZone.back:
      case BodyZone.stomach:
        isFlat = true;
        maxTaper = 0.0; // Flat surfaces don't taper
        gravityDrop = 0.35; // Drop below the shoulders line
        break;
      case BodyZone.leftHand:
      case BodyZone.rightHand:
      case BodyZone.leftFoot:
      case BodyZone.rightFoot:
        isFlat = false;
        maxTaper = 0.4; // Extreme taper for hands and feet
        gravityDrop = 0.0;
        break;
      case BodyZone.leftForearm:
      case BodyZone.rightForearm:
      case BodyZone.leftCalf:
      case BodyZone.rightCalf:
        isFlat = false;
        maxTaper = 0.35; // Pronounced cone (shrinks 35% at the bottom)
        gravityDrop = 0.0;
        break;
      case BodyZone.leftBicep:
      case BodyZone.rightBicep:
      case BodyZone.leftThigh:
      case BodyZone.rightThigh:
        isFlat = false;
        maxTaper = 0.15; // Mild cylinder (shrinks only 15% towards the knee/elbow)
        gravityDrop = 0.0;
        break;
    }

    double centerX, centerY;
    double baseX = startX + (endX - startX) * positionFactor;
    double baseY = startY + (endY - startY) * positionFactor;

    if (isFlat) {
      centerX = baseX;
      centerY = baseY + (distance * gravityDrop); 
    } else {
      centerX = baseX;
      centerY = baseY;
    }

    final angle = atan2(endY - startY, endX - startX) - rotationOffset + rotationManual;

    final double imgW = tattooImage!.width.toDouble();
    final double imgH = tattooImage!.height.toDouble();
    
    final double imageScale = (stableScale * scaleFactor) / imgH;
    final double drawnWidth = imgW * imageScale;
    final double drawnHeight = imgH * imageScale;

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
      ..isAntiAlias   = true;

    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.rotate(angle);

    const int verticalSlices = 20;
    const int horizontalVertices = 20;

    final double sliceWidth = drawnWidth / (horizontalVertices - 1);
    final double sliceHeight = drawnHeight / verticalSlices;

    List<ui.Offset> positions = [];
    List<ui.Offset> textureCoordinates = [];
    List<ui.Color> colors = [];
    List<int> indices = [];
    final Random random = Random();

    for (int y = 0; y <= verticalSlices; y++) {
      final double progressY = y / verticalSlices; 
      
      final double taperFactor = 1.0 - (progressY * maxTaper);
      final double currentWidth = drawnWidth * taperFactor;

      for (int x = 0; x < horizontalVertices; x++) {
        final double normX = x / (horizontalVertices - 1);
        final double normY = y / verticalSlices;
        final double flatY = (-drawnHeight / 2) + (y * sliceHeight);
        
        final double theta = (normX - 0.5) * pi;
        
        double distortedX = isFlat 
            ? (normX - 0.5) * currentWidth 
            : sin(theta) * (currentWidth / 2);

        final double bump = sin(normY * 35.0) * cos(theta * 10.0) * 1.2;

        positions.add(ui.Offset(distortedX + bump, flatY + bump));
        textureCoordinates.add(ui.Offset(normX * imgW, normY * imgH));

        final double baseShadow = isFlat ? 1.0 : (cos(theta) + 1.0) / 2.0; 
        final double specular = isFlat ? 0.0 : pow(max(0.0, cos(theta)), 6).toDouble() * 0.2;
        final double grain = (random.nextDouble() - 0.5) * 0.04; 
        
        double intensity = 0.8 + (baseShadow * 0.15) + specular + grain; 
        intensity = intensity.clamp(0.0, 1.0);
        
        // --- EDGE CLIPPING EFFECT (NEW) ---
        // If it's a cylinder, we calculate how close the pixel is to the side edge.
        // As theta approaches 90 degrees (pi/2) or -90 degrees, cos(theta) drops to 0.
        // We use this to smoothly fade the alpha to 0, making the tattoo disappear 
        // as it wraps around the back of the limb.
        double edgeVisibility = isFlat ? 1.0 : pow(max(0.0, cos(theta)), 0.4).toDouble();
        
        final int alphaValue = (opacity * edgeVisibility * 255).round();
        final int colorV = (intensity * 255).round();

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
           oldDelegate.selectedZone    != selectedZone    ||
           oldDelegate.sensorOrientation != sensorOrientation;
  }
}