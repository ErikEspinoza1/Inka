import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AiExploreService {
  // ATENCIÓN: La URL de tu servidor FastAPI
  // Si pruebas en el navegador web (Chrome/Edge): usa 127.0.0.1
  // Si pruebas en un móvil físico o emulador: usa la IP de tu PC (ej: 192.168.1.55)
  final String _baseUrl = 'https://inka-production.up.railway.app'; 

  Future<List<Map<String, dynamic>>> buscarTatuajesPorIdea(String idea) async {
    try {
      // Llamamos a nuestro servidor de Python
      final response = await http.get(
        Uri.parse('$_baseUrl/buscar-tatuajes-ia?idea=$idea'),
      );

      if (response.statusCode == 200) {
        // Convertimos la respuesta de Python en una lista para Flutter
        List<dynamic> datos = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(datos);
      } else {
        debugPrint("Error del servidor FastAPI: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("Error al conectar con FastAPI: $e");
      return [];
    }
  }
}