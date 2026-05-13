import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiExploreService {
  final String baseUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.134:8000';

  Future<List<Map<String, dynamic>>> getFeedInicial() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/search/feed'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        return List<Map<String, dynamic>>.from(results);
      } else {
        debugPrint("Error del servidor FastAPI (Feed): ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("Error al conectar con FastAPI (Feed): $e");
      return [];
    }
  }

  Future<List<String>> getPopularSearches() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/search/popular'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        return results.map((e) => e.toString()).toList();
      }
    } catch (e) {
      debugPrint("Error fetching popular searches: $e");
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> buscarTatuajesPorIdea(String idea) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/search/tattoos?query=$idea'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        return List<Map<String, dynamic>>.from(results);
      } else {
        debugPrint("Error del servidor FastAPI (Search): ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("Error al conectar con FastAPI (Search): $e");
      return [];
    }
  }
}