import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_service.dart';

class InteractionService {
  final String baseUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.134:8000';
  final AuthService _authService = AuthService();

  // Método general para hacer las peticiones con el Token
  Future<Map<String, dynamic>> _toggleAction(String endpoint, String postId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return {'success': false, 'message': 'No token'};

      final response = await http.post(
        Uri.parse('$baseUrl/content/$endpoint/$postId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'message': 'Error: ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint("Error in $endpoint: $e");
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> toggleLike(String postId) async {
    final result = await _toggleAction('likes', postId);
    return result['success'];
  }

  Future<bool> toggleFavorite(String postId) async {
    final result = await _toggleAction('favorites', postId);
    return result['success'];
  }

  Future<bool> toggleFollow(String artistId) async {
    final result = await _toggleAction('follow', artistId);
    return result['success'];
  }

  Future<List<Map<String, dynamic>>> getMyFavorites() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/users/me/favorites'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint("Error fetching favorites: $e");
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getMyFollowing() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/users/me/following'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint("Error fetching following: $e");
    }
    return [];
  }

  Future<bool> updatePost(String postId, {String? description, String? styleTag}) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final body = <String, dynamic>{};
      if (description != null) body['description'] = description;
      if (styleTag != null) body['style_tag'] = styleTag;

      final response = await http.patch(
        Uri.parse('$baseUrl/content/posts/$postId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error updating post: $e");
      return false;
    }
  }
}
