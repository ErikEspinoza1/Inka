import 'package:flutter/material.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';

class UnityTestScreen extends StatefulWidget {
  const UnityTestScreen({super.key});

  @override
  State<UnityTestScreen> createState() => _UnityTestScreenState();
}

class _UnityTestScreenState extends State<UnityTestScreen> {
  UnityWidgetController? _unityController;
  bool _isUnityLoaded = false;
  String _statusMessage = "Iniciando Unity...";

  void _onUnityCreated(UnityWidgetController controller) {
    _unityController = controller;
    setState(() {
      _isUnityLoaded = true;
      _statusMessage = "✅ Unity cargado correctamente!";
    });
  }

  void _onUnityMessage(dynamic message) {
    debugPrint("Mensaje de Unity: $message");
  }

  @override
  void dispose() {
    _unityController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Test Unity Integration"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Widget de Unity
          UnityWidget(
            onUnityCreated: _onUnityCreated,
            onUnityMessage: _onUnityMessage,
            fullscreen: false,
          ),
          
          // Overlay con estado
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isUnityLoaded ? Colors.green.withValues(alpha: 0.9) : Colors.orange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _isUnityLoaded ? Icons.check_circle : Icons.hourglass_top,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
