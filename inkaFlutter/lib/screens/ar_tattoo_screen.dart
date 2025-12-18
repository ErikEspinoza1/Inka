import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../painters/tattoo_painter.dart';
import '../utils/camera_utils.dart';

enum BodyZone { leftArm, rightArm, chest }

// Enum para saber qué slider estamos moviendo
enum ControlMode { size, position, rotation, opacity }

class ArTattooScreen extends StatefulWidget {
  const ArTattooScreen({super.key});

  @override
  State<ArTattooScreen> createState() => _ArTattooScreenState();
}

class _ArTattooScreenState extends State<ArTattooScreen> {
  CameraController? _controller;
  PoseDetector? _poseDetector;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;

  // --- VARIABLES DE ESTADO UI ---
  BodyZone _selectedZone = BodyZone.leftArm;
  ControlMode _activeControl = ControlMode.size; // Qué control vemos ahora

  // Valores de los Sliders
  double _sizeValue = 0.5;      // Tamaño
  double _posValue = 0.5;       // Posición (0.0 = Inicio, 1.0 = Fin)
  double _rotValue = 0.0;       // Rotación extra (-pi a pi)
  double _opacityValue = 0.9;   // Opacidad

  // Búfers de suavizado
  final List<PoseLandmark> _startBuffer = [];
  final List<PoseLandmark> _endBuffer = [];
  final int _bufferSize = 6; 
  
  PoseLandmark? _smoothStart;
  PoseLandmark? _smoothEnd;

  ui.Image? _tattooImage;
  CameraDescription? _cameraDescription;
  Size _inputImageSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    await Permission.camera.request();
    _tattooImage = await _loadUiImage('assets/images/tattoo.png');

    final options = PoseDetectorOptions(mode: PoseDetectionMode.stream);
    _poseDetector = PoseDetector(options: options);

    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _cameraDescription = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        _cameraDescription!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
          ? ImageFormatGroup.nv21 
          : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      _controller!.startImageStream(_processCameraImage);
      if (mounted) setState(() => _isCameraInitialized = true);
    }
  }

  Future<ui.Image> _loadUiImage(String path) async {
    final data = await rootBundle.load(path);
    final list = Uint8List.view(data.buffer);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(list, (img) => completer.complete(img));
    return completer.future;
  }

  (PoseLandmarkType, PoseLandmarkType, double) _getZoneConfig() {
    switch (_selectedZone) {
      case BodyZone.leftArm:
        // Offset 90 grados (1.57 radianes)
        return (PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, 1.57); 
      case BodyZone.rightArm:
        return (PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, 1.57);
      case BodyZone.chest:
        return (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, 0.0);
    }
  }

  PoseLandmark _calculateAverage(List<PoseLandmark> buffer) {
    double totalX = 0; double totalY = 0;
    for (var mark in buffer) { totalX += mark.x; totalY += mark.y; }
    return PoseLandmark(
      type: buffer.first.type,
      x: totalX / buffer.length,
      y: totalY / buffer.length,
      z: buffer.first.z,
      likelihood: 1.0,
    );
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || _poseDetector == null) return;
    _isProcessing = true;

    try {
      final inputImage = CameraUtils.convertCameraImageToInputImage(image, _cameraDescription!);
      _inputImageSize = Size(image.width.toDouble(), image.height.toDouble());
      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isNotEmpty) {
        final pose = poses.first;
        final (startType, endType, _) = _getZoneConfig();
        
        final rawStart = pose.landmarks[startType];
        final rawEnd = pose.landmarks[endType];

        if (rawStart != null && rawEnd != null && rawStart.likelihood > 0.6) {
          _startBuffer.add(rawStart);
          _endBuffer.add(rawEnd);

          if (_startBuffer.length > _bufferSize) _startBuffer.removeAt(0);
          if (_endBuffer.length > _bufferSize) _endBuffer.removeAt(0);

          final avgStart = _calculateAverage(_startBuffer);
          final avgEnd = _calculateAverage(_endBuffer);

          if (mounted) {
            setState(() {
              _smoothStart = avgStart;
              _smoothEnd = avgEnd;
            });
          }
        }
      } else {
        if (_startBuffer.isNotEmpty) {
           _startBuffer.clear(); _endBuffer.clear();
           if(mounted) setState(() { _smoothStart = null; _smoothEnd = null; });
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  void _changeZone(BodyZone newZone) {
    setState(() {
      _selectedZone = newZone;
      _startBuffer.clear(); _endBuffer.clear();
      _smoothStart = null; _smoothEnd = null;
      // Reseteamos posición al centro al cambiar de zona
      _posValue = 0.5;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }
    
    final (_, _, rotationOffset) = _getZoneConfig();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          
          LayoutBuilder(
            builder: (context, constraints) {
              return CustomPaint(
                painter: TattooPainter(
                  tattooImage: _tattooImage,
                  startPoint: _smoothStart,
                  endPoint: _smoothEnd,
                  absoluteImageSize: _inputImageSize,
                  scaleFactor: _sizeValue,
                  positionFactor: _posValue, // <-- AQUÍ SE PASA LA POSICIÓN
                  rotationManual: _rotValue, // <-- AQUÍ LA ROTACIÓN
                  opacity: _opacityValue,    // <-- AQUÍ LA OPACIDAD
                  rotationOffset: rotationOffset,
                ),
                size: Size(constraints.maxWidth, constraints.maxHeight),
              );
            },
          ),

          // --- UI PANEL CONTROL ---
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 15, bottom: 20, left: 20, right: 20),
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. FILA DE SELECTORES DE MODO (Iconos pequeños arriba)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildModeIcon(Icons.zoom_out_map, "Tamaño", ControlMode.size),
                      _buildModeIcon(Icons.linear_scale, "Posición", ControlMode.position),
                      _buildModeIcon(Icons.rotate_right, "Rotar", ControlMode.rotation),
                      _buildModeIcon(Icons.opacity, "Opacidad", ControlMode.opacity),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 20),

                  // 2. SLIDER ACTIVO (Cambia según lo que seleccionaste arriba)
                  Row(
                    children: [
                      Text(
                        _getSliderLabel(), 
                        style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)
                      ),
                      Expanded(child: _buildActiveSlider()),
                    ],
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // 3. SELECTOR DE ZONA DEL CUERPO
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildZoneButton("Izq.", Icons.arrow_back, BodyZone.leftArm),
                        const SizedBox(width: 10),
                        _buildZoneButton("Pecho", Icons.accessibility_new, BodyZone.chest),
                        const SizedBox(width: 10),
                        _buildZoneButton("Der.", Icons.arrow_forward, BodyZone.rightArm),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Botón salir
          Positioned(
            top: 50, left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget que decide qué slider mostrar
  Widget _buildActiveSlider() {
    switch (_activeControl) {
      case ControlMode.size:
        return Slider(value: _sizeValue, min: 0.1, max: 1.5, activeColor: Colors.tealAccent,
          onChanged: (v) => setState(() => _sizeValue = v));
      case ControlMode.position:
        return Slider(value: _posValue, min: 0.0, max: 1.0, activeColor: Colors.orangeAccent,
          onChanged: (v) => setState(() => _posValue = v));
      case ControlMode.rotation:
        return Slider(value: _rotValue, min: -3.14, max: 3.14, activeColor: Colors.purpleAccent,
          onChanged: (v) => setState(() => _rotValue = v));
      case ControlMode.opacity:
        return Slider(value: _opacityValue, min: 0.1, max: 1.0, activeColor: Colors.blueAccent,
          onChanged: (v) => setState(() => _opacityValue = v));
    }
  }

  String _getSliderLabel() {
    switch (_activeControl) {
      case ControlMode.size: return " Escala ";
      case ControlMode.position: return " Mover ";
      case ControlMode.rotation: return " Girar ";
      case ControlMode.opacity: return " Tinta ";
    }
  }

  Widget _buildModeIcon(IconData icon, String label, ControlMode mode) {
    final isSelected = _activeControl == mode;
    return GestureDetector(
      onTap: () => setState(() => _activeControl = mode),
      child: Column(
        children: [
          Icon(icon, color: isSelected ? Colors.tealAccent : Colors.white54, size: 28),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isSelected ? Colors.tealAccent : Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildZoneButton(String label, IconData icon, BodyZone zone) {
    final isSelected = _selectedZone == zone;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.tealAccent : Colors.grey[800],
        foregroundColor: isSelected ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: () => _changeZone(zone),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}