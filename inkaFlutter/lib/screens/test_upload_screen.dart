import 'dart:io';
import 'package:flutter/material.dart';

// 👇 ESTA LÍNEA ES LA MAGIA. Si 'image_service.dart' no está en la carpeta 'services', esto fallará.
import '../services/image_service.dart';

class TestUploadScreen extends StatefulWidget {
  const TestUploadScreen({super.key});

  @override
  State<TestUploadScreen> createState() => _TestUploadScreenState();
}

class _TestUploadScreenState extends State<TestUploadScreen> {
  // Instanciamos la clase que creaste en el otro archivo
  final ImageService _imageService = ImageService();
  
  File? _imageFile;
  String? _statusMessage = "Listo para subir";
  bool _isLoading = false;

  Future<void> _handleUpload() async {
    setState(() => _isLoading = true);
    
    // 1. Llamamos al servicio para elegir foto
    final file = await _imageService.pickImage(fromCamera: false);
    
    if (file != null) {
      setState(() {
        _imageFile = file;
        _statusMessage = "Subiendo a Supabase...";
      });

      // 2. Llamamos al servicio para subirla
      final url = await _imageService.uploadImage(file, 'test_user');

      setState(() {
        if (url != null) {
          _statusMessage = "✅ ÉXITO! URL GENERADA:\n$url";
        } else {
          _statusMessage = "❌ Error al subir la imagen.";
        }
      });
    } else {
      setState(() => _statusMessage = "Cancelado por el usuario");
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Prueba Persona 3")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mostramos la foto si existe (así usamos la variable _imageFile)
              if (_imageFile != null) 
                Image.file(_imageFile!, height: 200),
              
              const SizedBox(height: 20),
              
              // Mostramos el estado (así usamos la variable _statusMessage)
              Text(
                _statusMessage!, 
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              
              const SizedBox(height: 20),
              
              _isLoading 
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _handleUpload,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text("Seleccionar y Subir"),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}