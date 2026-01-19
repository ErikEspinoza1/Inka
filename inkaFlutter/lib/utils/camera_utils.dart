import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'; // Necesario para WriteBuffer
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class CameraUtils {
  static InputImage convertCameraImageToInputImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    final allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final InputImageRotation imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final InputImageFormat inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;

    // --- AQUÍ ESTABA EL ERROR: ACTUALIZADO A LA NUEVA API ---
    // En lugar de 'InputImageData', ahora se usa 'InputImageMetadata'
    // y ya no hace falta pasar todos los planos, solo el bytesPerRow del primero.
    
    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow, 
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }
}