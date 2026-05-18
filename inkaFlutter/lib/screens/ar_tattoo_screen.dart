import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
=======
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
>>>>>>> parent of 1a8214c (a)

import '../painters/tattoo_painter.dart';
import '../utils/camera_utils.dart';

<<<<<<< HEAD
enum BodyZone {
  head,
  neck,
  chest,
  back,
  stomach,
  leftForearm,
  rightForearm,
  leftBicep,
  rightBicep,
  leftHand,
  rightHand,
  leftThigh,
  rightThigh,
  leftCalf,
  rightCalf,
  leftFoot,
  rightFoot
}

enum ControlMode { size, posX, posY, rotation, opacity, timer }
=======
enum BodyZone { leftArm, rightArm, chest }

// Enum para saber qué slider estamos moviendo
enum ControlMode { size, position, rotation, opacity }
>>>>>>> parent of 1a8214c (a)

class ArTattooScreen extends StatefulWidget {
  const ArTattooScreen({super.key});

  @override
  State<ArTattooScreen> createState() => _ArTattooScreenState();
}

class _ArTattooScreenState extends State<ArTattooScreen> {
<<<<<<< HEAD
  final GlobalKey _boundaryKey = GlobalKey();
=======
>>>>>>> parent of 1a8214c (a)
  CameraController? _controller;
  PoseDetector? _poseDetector;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
<<<<<<< HEAD

  bool _isFrontCamera = true; 
=======
>>>>>>> parent of 1a8214c (a)

  // --- VARIABLES DE ESTADO UI ---
  BodyZone _selectedZone = BodyZone.leftArm;
  ControlMode _activeControl = ControlMode.size; // Qué control vemos ahora

<<<<<<< HEAD
  // Valores predeterminados en el punto medio
  double _sizeValue = 0.8;
  double _posXValue = 0.5;
  double _posYValue = 0.5;
  double _rotValue = 0.0;
  double _opacityValue = 0.55;
  double _timerSetting = 3.0;

  int _currentCountdown = 0;
  bool _isCountingDown = false;

  final OneEuroFilter _startFilter = OneEuroFilter(minCutoff: 0.05, beta: 0.005);
  final OneEuroFilter _endFilter = OneEuroFilter(minCutoff: 0.05, beta: 0.005);

  PoseLandmark? _stabilizedStart;
  PoseLandmark? _stabilizedEnd;
=======
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
>>>>>>> parent of 1a8214c (a)

  ui.Image? _tattooImage;
  CameraDescription? _cameraDescription;
  Size _inputImageSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
<<<<<<< HEAD
    await [Permission.camera, Permission.storage].request();

    try {
      if (widget.tattooBytes != null) {
        setState(() => _isProcessing = true);
        final transparentBytes = await _removeBackgroundOnServer(widget.tattooBytes!);
        _tattooImage = await _loadUiImageFromBytes(transparentBytes);
      } else {
        _tattooImage = await _loadUiImage('assets/images/tattoo.png');
      }
    } catch (e) {
      _tattooImage = await _loadUiImage('assets/images/tattoo.png');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
=======
    await Permission.camera.request();
    _tattooImage = await _loadUiImage('assets/images/tattoo.png');
>>>>>>> parent of 1a8214c (a)

    _poseDetector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));

    await _setupCamera();
  }

  Future<void> _setupCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      // Forzamos buscar la cámara frontal como principal
      _cameraDescription = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
<<<<<<< HEAD
      
      _isFrontCamera = _cameraDescription!.lensDirection == CameraLensDirection.front;
      _sensorOrientation = _cameraDescription!.sensorOrientation;
      
      _controller = CameraController(
        _cameraDescription!,
        ResolutionPreset.high,
        enableAudio: false,
=======

      _controller = CameraController(
        _cameraDescription!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
          ? ImageFormatGroup.nv21 
          : ImageFormatGroup.bgra8888,
>>>>>>> parent of 1a8214c (a)
      );

      await _controller!.initialize();
      _controller!.startImageStream(_processCameraImage);
      if (mounted) setState(() => _isCameraInitialized = true);
    }
  }

<<<<<<< HEAD
  // Lógica de imantación (Magnetic Snapping)
  double _snapValue(double value, double target, {double threshold = 0.04}) {
    if ((value - target).abs() < threshold) {
      return target;
    }
    return value;
  }

  Future<Uint8List> _removeBackgroundOnServer(Uint8List originalBytes) async {
    final uri = Uri.parse('http://172.17.33.7:8000/api/remove-background');
    var request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile.fromBytes('file', originalBytes, filename: 'tattoo.jpg'));
    var response = await request.send();
    if (response.statusCode == 200) return await response.stream.toBytes();
    throw Exception('Error removing background');
  }

=======
>>>>>>> parent of 1a8214c (a)
  Future<ui.Image> _loadUiImage(String path) async {
    final data = await rootBundle.load(path);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(Uint8List.view(data.buffer), (img) => completer.complete(img));
    return completer.future;
  }

<<<<<<< HEAD
  Future<ui.Image> _loadUiImageFromBytes(Uint8List bytes) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    return completer.future;
  }

=======
>>>>>>> parent of 1a8214c (a)
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

<<<<<<< HEAD
        if (rawStart != null && rawEnd != null && rawStart.likelihood > 0.3) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final sOff = _startFilter.filter(Offset(rawStart.x, rawStart.y), timestamp);
          final eOff = _endFilter.filter(Offset(rawEnd.x, rawEnd.y), timestamp);

          if (mounted) {
            setState(() {
              _stabilizedStart = PoseLandmark(
                  type: rawStart.type, x: sOff.dx, y: sOff.dy, z: rawStart.z, likelihood: rawStart.likelihood);
              _stabilizedEnd = PoseLandmark(
                  type: rawEnd.type, x: eOff.dx, y: eOff.dy, z: rawEnd.z, likelihood: rawEnd.likelihood);
            });
          }
        }
      }
=======
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
>>>>>>> parent of 1a8214c (a)
    } finally {
      _isProcessing = false;
    }
  }

<<<<<<< HEAD
  Future<void> _takePhoto() async {
    try {
      RenderRepaintBoundary boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      if (!await Gal.hasAccess()) await Gal.requestAccess();
      await Gal.putImageBytes(pngBytes, name: "Inka_${DateTime.now().millisecondsSinceEpoch}");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("¡Foto guardada en la galería!"), backgroundColor: Colors.teal));
      }
    } catch (e) {
      debugPrint("Error guardando foto: $e");
    }
=======
  void _changeZone(BodyZone newZone) {
    setState(() {
      _selectedZone = newZone;
      _startBuffer.clear(); _endBuffer.clear();
      _smoothStart = null; _smoothEnd = null;
      // Reseteamos posición al centro al cambiar de zona
      _posValue = 0.5;
    });
>>>>>>> parent of 1a8214c (a)
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final (_, _, rotationOffset) = _getZoneConfig();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
<<<<<<< HEAD
          RepaintBoundary(
            key: _boundaryKey,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1 / _controller!.value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_controller!),
                    CustomPaint(
                      painter: TattooPainter(
                        tattooImage: _tattooImage,
                        startPoint: _stabilizedStart,
                        endPoint: _stabilizedEnd,
                        absoluteImageSize: _inputImageSize,
                        isFrontCamera: _isFrontCamera,
                        scaleFactor: _sizeValue,
                        positionX: _posXValue,
                        positionY: _posYValue,
                        rotationManual: _rotValue,
                        opacity: _opacityValue,
                        rotationOffset: rotationOffset,
                        sensorOrientation: _sensorOrientation,
                        selectedZone: _selectedZone,
                      ),
                    ),
                  ],
=======
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
>>>>>>> parent of 1a8214c (a)
                ),
                size: Size(constraints.maxWidth, constraints.maxHeight),
              );
            },
          ),
<<<<<<< HEAD
          
          if (_isCountingDown)
            Container(
              color: Colors.black45,
              child: Center(
                child: Text("$_currentCountdown",
                    style: const TextStyle(color: Colors.tealAccent, fontSize: 120, fontWeight: FontWeight.bold)),
              ),
            ),
            
=======

          // --- UI PANEL CONTROL ---
>>>>>>> parent of 1a8214c (a)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
<<<<<<< HEAD
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
=======
              padding: const EdgeInsets.only(top: 15, bottom: 20, left: 20, right: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
>>>>>>> parent of 1a8214c (a)
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. FILA DE SELECTORES DE MODO (Iconos pequeños arriba)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
<<<<<<< HEAD
                      _buildModeIcon(Icons.zoom_out_map, "Escala", ControlMode.size),
                      _buildModeIcon(Icons.swap_horiz, "X", ControlMode.posX),
                      _buildModeIcon(Icons.swap_vert, "Y", ControlMode.posY),
                      _buildModeIcon(Icons.rotate_right, "Girar", ControlMode.rotation),
                      _buildModeIcon(Icons.opacity, "Tinta", ControlMode.opacity),
                      _buildModeIcon(Icons.timer, "Reloj", ControlMode.timer),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 25),
                  _buildActiveSlider(),
                  const SizedBox(height: 15),
=======
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
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)
                      ),
                      Expanded(child: _buildActiveSlider()),
                    ],
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // 3. SELECTOR DE ZONA DEL CUERPO
>>>>>>> parent of 1a8214c (a)
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
<<<<<<< HEAD
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      if (_isCountingDown) return;
                      setState(() {
                        _isCountingDown = true;
                        _currentCountdown = _timerSetting.toInt();
                      });
                      Timer.periodic(const Duration(seconds: 1), (t) async {
                        if (_currentCountdown > 1) {
                          setState(() => _currentCountdown--);
                        } else {
                          t.cancel();
                          await _takePhoto();
                          setState(() => _isCountingDown = false);
                        }
                      });
                    },
                    child: Container(
                      height: 65,
                      width: 65,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        color: Colors.tealAccent,
                      ),
                      child: const Icon(Icons.camera_alt, size: 30, color: Colors.black),
                    ),
                  )
=======
>>>>>>> parent of 1a8214c (a)
                ],
              ),
            ),
          ),
<<<<<<< HEAD
=======
          
          // Botón salir
>>>>>>> parent of 1a8214c (a)
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
<<<<<<< HEAD
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
=======
              backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
>>>>>>> parent of 1a8214c (a)
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
<<<<<<< HEAD
        return Slider(
          value: _sizeValue, min: 0.1, max: 1.5, activeColor: Colors.tealAccent,
          onChanged: (v) => setState(() => _sizeValue = _snapValue(v, 0.8)),
        );
      case ControlMode.posX:
        return Slider(
          value: _posXValue, min: 0.0, max: 1.0, activeColor: Colors.orangeAccent,
          onChanged: (v) => setState(() => _posXValue = _snapValue(v, 0.5)),
        );
      case ControlMode.posY:
        return Slider(
          value: _posYValue, min: 0.0, max: 1.0, activeColor: Colors.deepOrangeAccent,
          onChanged: (v) => setState(() => _posYValue = _snapValue(v, 0.5)),
        );
      case ControlMode.rotation:
        return Slider(
          value: _rotValue, min: -3.14, max: 3.14, activeColor: Colors.purpleAccent,
          onChanged: (v) => setState(() => _rotValue = _snapValue(v, 0.0)),
        );
      case ControlMode.opacity:
        return Slider(
          value: _opacityValue, min: 0.1, max: 1.0, activeColor: Colors.blueAccent,
          onChanged: (v) => setState(() => _opacityValue = _snapValue(v, 0.55)),
        );
      case ControlMode.timer:
        return Slider(
          value: _timerSetting, min: 0, max: 10, divisions: 10,
          label: "${_timerSetting.toInt()}s", activeColor: Colors.redAccent,
          onChanged: (v) => setState(() => _timerSetting = v),
        );
=======
        return Slider(value: _sizeValue, min: 0.1, max: 1.5, activeColor: Theme.of(context).colorScheme.primary,
          onChanged: (v) => setState(() => _sizeValue = v));
      case ControlMode.position:
        return Slider(value: _posValue, min: 0.0, max: 1.0, activeColor: Theme.of(context).colorScheme.secondary,
          onChanged: (v) => setState(() => _posValue = v));
      case ControlMode.rotation:
        return Slider(value: _rotValue, min: -3.14, max: 3.14, activeColor: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          onChanged: (v) => setState(() => _rotValue = v));
      case ControlMode.opacity:
        return Slider(value: _opacityValue, min: 0.1, max: 1.0, activeColor: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
          onChanged: (v) => setState(() => _opacityValue = v));
    }
  }

  String _getSliderLabel() {
    switch (_activeControl) {
      case ControlMode.size: return " Escala ";
      case ControlMode.position: return " Mover ";
      case ControlMode.rotation: return " Girar ";
      case ControlMode.opacity: return " Tinta ";
>>>>>>> parent of 1a8214c (a)
    }
  }

  Widget _buildModeIcon(IconData icon, String label, ControlMode mode) {
    final isSelected = _activeControl == mode;
    return GestureDetector(
      onTap: () => setState(() => _activeControl = mode),
      child: Column(
        children: [
<<<<<<< HEAD
          Icon(icon, color: sel ? Colors.tealAccent : Colors.white54, size: 26),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: sel ? Colors.tealAccent : Colors.white54, fontSize: 10)),
=======
          Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.5), size: 28),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 10)),
>>>>>>> parent of 1a8214c (a)
        ],
      ),
    );
  }

  Widget _buildZoneButton(String label, IconData icon, BodyZone zone) {
<<<<<<< HEAD
    bool sel = _selectedZone == zone;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: sel ? Colors.tealAccent : Colors.grey[800],
          foregroundColor: sel ? Colors.black : Colors.white,
        ),
        onPressed: () => setState(() {
          _selectedZone = zone;
          _posXValue = 0.5;
          _posYValue = 0.5;
        }),
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 11)),
      ),
=======
    final isSelected = _selectedZone == zone;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceVariant,
        foregroundColor: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: () => _changeZone(zone),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
>>>>>>> parent of 1a8214c (a)
    );
  }
}