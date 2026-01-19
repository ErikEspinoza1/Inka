import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 👇 ¡FÍJATE QUE EL NOMBRE SEA EXACTAMENTE ESTE!
class ImageService { 
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<File?> pickImage({required bool fromCamera}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 70, 
        maxWidth: 1080,
      );
      if (image != null) return File(image.path);
      return null;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  Future<String?> uploadImage(File file, String userId) async {
    try {
      final fileName = 'uploads/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage.from('app-images').upload(fileName, file);
      final imageUrl = _supabase.storage.from('app-images').getPublicUrl(fileName);
      return imageUrl;
    } catch (e) {
      print('Error upload: $e');
      return null;
    }
  }
}