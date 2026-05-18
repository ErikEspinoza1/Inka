// lib/screens/ar_tattoo_screen.dart
import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../painters/tattoo_painter.dart';
import '../utils/camera_utils.dart';
import '../utils/one_euro_filter.dart';

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

class ArTattooScreen extends StatefulWidget {
  final Uint8List? tattooBytes;
  final String? imageUrl;

  const ArTattooScreen({super.key, this.tattooBytes, this.imageUrl});

  @override
  State<ArTattooScreen> createState() => _ArTattooScreenState();
}

class _ArTattooScreenState extends State<ArTattooScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  CameraController? _controller;
  PoseDetector? _poseDetector;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;

  bool _isFrontCamera = true; 

  BodyZone _selectedZone = BodyZone.leftForearm;
  ControlMode _activeControl = ControlMode.size;

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

  ui.Image? _tattooImage;
  CameraDescription? _cameraDescription;
  Size _inputImageSize = Size.zero;
  int _sensorOrientation = 90;

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    await [Permission.camera, Permission.storage].request();

    try {
      if (widget.tattooBytes != null) {
        setState(() => _isProcessing = true);
        final transparentBytes = await _removeBackgroundOnServer(widget.tattooBytes!);
        _tattooImage = await _loadUiImageFromBytes(transparentBytes);
      } else if (widget.imageUrl != null) {
        setState(() => _isProcessing = true);
        final response = await http.get(Uri.parse(widget.imageUrl!));
        final transparentBytes = await _removeBackgroundOnServer(response.bodyBytes);
        _tattooImage = await _loadUiImageFromBytes(transparentBytes);
      } else {
        _tattooImage = await _loadUiImage('assets/images/tattoo.png');
      }
    } catch (e) {
      _tattooImage = await _loadUiImage('assets/images/tattoo.png');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }

    _poseDetector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));

    await _setupCamera();
  }

  Future<void> _setupCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      // Forzamos buscar la cámara frontal como principal
      _cameraDescription = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      
      _isFrontCamera = _cameraDescription!.lensDirection == CameraLensDirection.front;
      _sensorOrientation = _cameraDescription!.sensorOrientation;
      
      _controller = CameraController(
        _cameraDescription!,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      _controller!.startImageStream(_processCameraImage);
      if (mounted) setState(() => _isCameraInitialized = true);
    }
  }

  // Lógica de imantación (Magnetic Snapping)
  double _snapValue(double value, double target, {double threshold = 0.04}) {
    if ((value - target).abs() < threshold) {
      return target;
    }
    return value;
  }

  Future<Uint8List> _removeBackgroundOnServer(Uint8List originalBytes) async {
    final String baseUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.134:8000';
    final uri = Uri.parse('$baseUrl/tattoo/remove_bg');
    var request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile.fromBytes('file', originalBytes, filename: 'tattoo.jpg'));
    var response = await request.send();
    if (response.statusCode == 200) return await response.stream.toBytes();
    throw Exception('Error removing background');
  }

  Future<ui.Image> _loadUiImage(String path) async {
    final data = await rootBundle.load(path);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(Uint8List.view(data.buffer), (img) => completer.complete(img));
    return completer.future;
  }

  Future<ui.Image> _loadUiImageFromBytes(Uint8List bytes) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    return completer.future;
  }

  (PoseLandmarkType, PoseLandmarkType, double) _getZoneConfig() {
    switch (_selectedZone) {
      case BodyZone.head: return (PoseLandmarkType.leftEar, PoseLandmarkType.rightEar, 0.0);
      case BodyZone.neck: return (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, 0.0);
      case BodyZone.chest: return (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, 0.0);
      case BodyZone.back: return (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, 0.0);
      case BodyZone.stomach: return (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, 0.0);
      case BodyZone.leftForearm: return (PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, 1.57);
      case BodyZone.rightForearm: return (PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, 1.57);
      case BodyZone.leftBicep: return (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, 1.57);
      case BodyZone.rightBicep: return (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, 1.57);
      case BodyZone.leftHand: return (PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex, 1.57);
      case BodyZone.rightHand: return (PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex, 1.57);
      case BodyZone.leftThigh: return (PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, 1.57);
      case BodyZone.rightThigh: return (PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, 1.57);
      case BodyZone.leftCalf: return (PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, 1.57);
      case BodyZone.rightCalf: return (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, 1.57);
      case BodyZone.leftFoot: return (PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex, 1.57);
      case BodyZone.rightFoot: return (PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex, 1.57);
    }
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
    } finally {
      _isProcessing = false;
    }
  }

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
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
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
                ),
              ),
            ),
          ),
          
          if (_isCountingDown)
            Container(
              color: Colors.black45,
              child: Center(
                child: Text("$_currentCountdown",
                    style: const TextStyle(color: Colors.tealAccent, fontSize: 120, fontWeight: FontWeight.bold)),
              ),
            ),
            
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildZoneButton("Cabeza", Icons.face, BodyZone.head),
                        _buildZoneButton("Cuello", Icons.person, BodyZone.neck),
                        _buildZoneButton("Pecho", Icons.accessibility_new, BodyZone.chest),
                        _buildZoneButton("Espalda", Icons.accessibility_new, BodyZone.back),
                        _buildZoneButton("Estómago", Icons.accessibility_new, BodyZone.stomach),
                        _buildZoneButton("Mano I", Icons.back_hand, BodyZone.leftHand),
                        _buildZoneButton("Mano D", Icons.back_hand, BodyZone.rightHand),
                        _buildZoneButton("Antebrazo I", Icons.pan_tool, BodyZone.leftForearm),
                        _buildZoneButton("Antebrazo D", Icons.pan_tool, BodyZone.rightForearm),
                        _buildZoneButton("Bíceps I", Icons.fitness_center, BodyZone.leftBicep),
                        _buildZoneButton("Bíceps D", Icons.fitness_center, BodyZone.rightBicep),
                        _buildZoneButton("Muslo I", Icons.directions_walk, BodyZone.leftThigh),
                        _buildZoneButton("Muslo D", Icons.directions_walk, BodyZone.rightThigh),
                        _buildZoneButton("Gemelo I", Icons.directions_run, BodyZone.leftCalf),
                        _buildZoneButton("Gemelo D", Icons.directions_run, BodyZone.rightCalf),
                        _buildZoneButton("Pie I", Icons.pets, BodyZone.leftFoot),
                        _buildZoneButton("Pie D", Icons.pets, BodyZone.rightFoot),
                      ],
                    ),
                  ),
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
                ],
              ),
            ),
          ),
          Positioned(
            top: 50,
            left: 20,
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

  Widget _buildActiveSlider() {
    switch (_activeControl) {
      case ControlMode.size:
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
    }
  }

  Widget _buildModeIcon(IconData icon, String label, ControlMode mode) {
    bool sel = _activeControl == mode;
    return GestureDetector(
      onTap: () => setState(() => _activeControl = mode),
      child: Column(
        children: [
          Icon(icon, color: sel ? Colors.tealAccent : Colors.white54, size: 26),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: sel ? Colors.tealAccent : Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildZoneButton(String label, IconData icon, BodyZone zone) {
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
    );
  }
}