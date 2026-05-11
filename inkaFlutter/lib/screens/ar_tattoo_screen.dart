// lib/screens/ar_tattoo_screen.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http; 

import '../painters/tattoo_painter.dart';
import '../utils/camera_utils.dart';
import '../utils/one_euro_filter.dart'; // <-- One Euro Filter Import

enum BodyZone { leftArm, rightArm, chest }
enum ControlMode { size, position, rotation, opacity }

class ArTattooScreen extends StatefulWidget {
  final Uint8List? tattooBytes;

  const ArTattooScreen({super.key, this.tattooBytes});

  @override
  State<ArTattooScreen> createState() => _ArTattooScreenState();
}

class _ArTattooScreenState extends State<ArTattooScreen> {
  CameraController? _controller;
  PoseDetector? _poseDetector;
  bool _isCameraInitialized = false;
  bool _isProcessing = false; 

  BodyZone _selectedZone = BodyZone.leftArm;
  ControlMode _activeControl = ControlMode.size;

  double _sizeValue = 0.5;
  double _posValue = 0.5;
  double _rotValue = 0.0;
  double _opacityValue = 0.9;

  // --- NEW: Math Filters for Jitter Stabilization ---
  // minCutoff: Reduces jitter at slow speeds.
  // beta: Reduces lag at high speeds.
  final OneEuroFilter _startFilter = OneEuroFilter(minCutoff: 0.5, beta: 0.01);
  final OneEuroFilter _endFilter = OneEuroFilter(minCutoff: 0.5, beta: 0.01);
  
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
    await Permission.camera.request();

    try {
      if (widget.tattooBytes != null) {
        setState(() => _isProcessing = true);
        
        final transparentBytes = await _removeBackgroundOnServer(widget.tattooBytes!);
        _tattooImage = await _loadUiImageFromBytes(transparentBytes);
      } else {
        _tattooImage = await _loadUiImage('assets/images/tattoo.png');
      }
    } catch (e) {
      debugPrint("Error processing image on server: $e");
      _tattooImage = await _loadUiImage('assets/images/tattoo.png');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }

    final options = PoseDetectorOptions(mode: PoseDetectionMode.stream);
    _poseDetector = PoseDetector(options: options);

    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _cameraDescription = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _sensorOrientation = _cameraDescription!.sensorOrientation;

      _controller = CameraController(
        _cameraDescription!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: kIsWeb
            ? ImageFormatGroup.jpeg
            : (defaultTargetPlatform == TargetPlatform.android
                ? ImageFormatGroup.nv21
                : ImageFormatGroup.bgra8888),
      );

      await _controller!.initialize();
      _controller!.startImageStream(_processCameraImage);
      if (mounted) setState(() => _isCameraInitialized = true);
    }
  }

  Future<Uint8List> _removeBackgroundOnServer(Uint8List originalBytes) async {
    // 172.17.33.7 is your computer's local IP on the network
    final uri = Uri.parse('http://172.17.33.7:8000/api/remove-background'); 
    
    var request = http.MultipartRequest('POST', uri);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file', 
        originalBytes, 
        filename: 'tattoo_design.jpg',
      ),
    );

    var response = await request.send();

    if (response.statusCode == 200) {
      return await response.stream.toBytes();
    } else {
      throw Exception('Server failed to remove background: ${response.statusCode}');
    }
  }

  Future<ui.Image> _loadUiImage(String path) async {
    final data = await rootBundle.load(path);
    final list = Uint8List.view(data.buffer);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(list, (img) => completer.complete(img));
    return completer.future;
  }

  Future<ui.Image> _loadUiImageFromBytes(Uint8List bytes) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    return completer.future;
  }

  (PoseLandmarkType, PoseLandmarkType, double) _getZoneConfig() {
    switch (_selectedZone) {
      case BodyZone.leftArm:
        return (PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, 1.57);
      case BodyZone.rightArm:
        return (PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, 1.57);
      case BodyZone.chest:
        return (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, 0.0);
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
          
          final int timestamp = DateTime.now().millisecondsSinceEpoch;

          // Process raw coordinates through the One Euro Filter
          final startOffset = _startFilter.filter(Offset(rawStart.x, rawStart.y), timestamp);
          final endOffset = _endFilter.filter(Offset(rawEnd.x, rawEnd.y), timestamp);

          if (mounted) {
            setState(() {
              // Re-pack into PoseLandmark to keep compatibility with TattooPainter
              _stabilizedStart = PoseLandmark(
                type: rawStart.type,
                x: startOffset.dx,
                y: startOffset.dy,
                z: rawStart.z,
                likelihood: rawStart.likelihood,
              );
              _stabilizedEnd = PoseLandmark(
                type: rawEnd.type,
                x: endOffset.dx,
                y: endOffset.dy,
                z: rawEnd.z,
                likelihood: rawEnd.likelihood,
              );
            });
          }
        }
      } else {
        // Reset filters if we lose track of the body to prevent ghosting
        _startFilter.reset();
        _endFilter.reset();
        if (mounted) {
          setState(() { 
            _stabilizedStart = null; 
            _stabilizedEnd = null; 
          });
        }
      }
    } catch (e) {
      debugPrint("Error analyzing pose: $e");
    } finally {
      _isProcessing = false;
    }
  }

  void _changeZone(BodyZone newZone) {
    setState(() {
      _selectedZone = newZone;
      _startFilter.reset();
      _endFilter.reset();
      _stabilizedStart = null;
      _stabilizedEnd = null;
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
    if (_isProcessing && !_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.tealAccent),
              SizedBox(height: 20),
              Text(
                "Processing tattoo with AI...\nRemoving background",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final (_, _, rotationOffset) = _getZoneConfig();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          LayoutBuilder(builder: (context, constraints) {
            return CustomPaint(
              painter: TattooPainter(
                tattooImage: _tattooImage,
                startPoint: _stabilizedStart,
                endPoint: _stabilizedEnd,
                absoluteImageSize: _inputImageSize,
                scaleFactor: _sizeValue,
                positionFactor: _posValue,
                rotationManual: _rotValue,
                opacity: _opacityValue,
                rotationOffset: rotationOffset,
                sensorOrientation: _sensorOrientation,
              ),
              size: Size(constraints.maxWidth, constraints.maxHeight),
            );
          }),

          // --- VISUAL DETECTION ALERT ---
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _stabilizedStart != null 
                      ? Colors.green.withOpacity(0.8) 
                      : Colors.redAccent.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _stabilizedStart != null
                      ? "✅ Zone detected and tracking"
                      : "❌ Searching for body part...",
                  style: const TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildModeIcon(Icons.zoom_out_map, "Size", ControlMode.size),
                      _buildModeIcon(Icons.linear_scale, "Position", ControlMode.position),
                      _buildModeIcon(Icons.rotate_right, "Rotate", ControlMode.rotation),
                      _buildModeIcon(Icons.opacity, "Opacity", ControlMode.opacity),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  Row(
                    children: [
                      Text(_getSliderLabel(),
                          style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                      Expanded(child: _buildActiveSlider()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildZoneButton("Left", Icons.arrow_back, BodyZone.leftArm),
                        const SizedBox(width: 10),
                        _buildZoneButton("Chest", Icons.accessibility_new, BodyZone.chest),
                        const SizedBox(width: 10),
                        _buildZoneButton("Right", Icons.arrow_forward, BodyZone.rightArm),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

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
      case ControlMode.size:     return " Scale ";
      case ControlMode.position: return " Move ";
      case ControlMode.rotation: return " Rotate ";
      case ControlMode.opacity:  return " Ink ";
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
          Text(label, style: TextStyle(
              color: isSelected ? Colors.tealAccent : Colors.white54, fontSize: 10)),
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