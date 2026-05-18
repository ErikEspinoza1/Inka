import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_service.dart';

class WatermarkTestScreen extends StatefulWidget {
  const WatermarkTestScreen({super.key});

  @override
  State<WatermarkTestScreen> createState() => _WatermarkTestScreenState();
}

class _WatermarkTestScreenState extends State<WatermarkTestScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _originalImage;
  File? _watermarkedImage;
  bool _isProcessing = false;

  Future<void> _pickAndTest() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _originalImage = File(pickedFile.path);
        _watermarkedImage = null;
        _isProcessing = true;
      });

      // Aplicar marca de agua de prueba
      final watermarked = await ImageService.applyWatermark(
        imagePath: pickedFile.path,
        artistName: "INKA STUDIO TEST",
      );

      setState(() {
        _watermarkedImage = watermarked;
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Test de Marca de Agua")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_originalImage == null)
              const Center(child: Text("Selecciona una imagen para probar"))
            else ...[
              const Text("Original:"),
              Image.file(_originalImage!, height: 200),
              const SizedBox(height: 20),
              if (_isProcessing)
                const CircularProgressIndicator()
              else if (_watermarkedImage != null) ...[
                const Text("Con Marca de Agua:"),
                Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.teal, width: 2)),
                  child: Image.file(_watermarkedImage!),
                ),
                const SizedBox(height: 10),
                const Text("Fíjate en la esquina inferior derecha", 
                  style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
              ],
            ],
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _pickAndTest,
              icon: const Icon(Icons.image),
              label: const Text("Seleccionar Imagen de Galería"),
            ),
          ],
        ),
      ),
    );
  }
}
