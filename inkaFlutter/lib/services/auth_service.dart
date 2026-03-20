import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  // Carga la URL desde el archivo .env
  final String baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8000';

  // ==========================================================
  // 1. AUTENTICACIÓN BÁSICA (Registro, Login, Logout)
  // ==========================================================

  Future<bool> register(String email, String password, String fullName) async {
    final url = Uri.parse('$baseUrl/auth/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'full_name': fullName,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error conexión register: $e');
      return false;
    }
  }

  Future<String?> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        await _saveToken(token);
        return token;
      }
      return null;
    } catch (e) {
      debugPrint('Error login: $e');
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  // ==========================================================
  // 2. REGISTRO DE ARTISTA (Proceso Robusto)
  // ==========================================================

  Future<bool> registerArtist({
    required String email,
    required String password,
    required String fullName,
    required String specialty,
    required String address,
    required double lat,
    required double lng,
  }) async {
    // PASO A: Crear usuario base
    final userCreated = await register(email, password, fullName);

    if (!userCreated) {
      debugPrint("Registro cancelado: El email ya existe o hubo un error.");
      return false; 
    }

    // Pausa técnica para asegurar que la DB guardó el registro
    await Future.delayed(const Duration(milliseconds: 500));

    // PASO B: Login para obtener token
    final token = await login(email, password);
    if (token == null) return false;

    // PASO C: Convertir a Artista
    final url = Uri.parse('$baseUrl/artists/become-artist');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'shop_name': fullName,
          'bio': 'Artista registrado desde Inka',
          'styles': [specialty], 
          'address': address,
          'latitude': lat,
          'longitude': lng,
          'workspace_type': 'shop',
          'show_exact_location': true,
          'instagram_handle': 'pendiente', 
          'business_license_id': 'pendiente',
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error become-artist: $e');
      return false;
    }
  }

  // ==========================================================
  // 3. GESTIÓN DE PERFIL Y ROLES
  // ==========================================================

  Future<String?> getUserRole() async {
    final token = await getToken();
    if (token == null) return null;

    final url = Uri.parse('$baseUrl/users/me');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['role']; 
      }
    } catch (e) {
      debugPrint("Error obteniendo rol: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> getArtistProfile() async {
    final token = await getToken();
    if (token == null) return null;

    final url = Uri.parse('$baseUrl/artists/me');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      debugPrint('Error getArtistProfile: $e');
    }
    return null;
  }

  Future<bool> updateArtistProfile(Map<String, dynamic> data) async {
    final token = await getToken();
    if (token == null) return false;

    final url = Uri.parse('$baseUrl/artists/me');
    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error update artist: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> uploadCertificate(String filePath) async {
    final token = await getToken();
    if (token == null) return null;

    final url = Uri.parse('$baseUrl/artists/upload-certificate');
    try {
      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)); 
      }
      return null;
    } catch (e) {
      debugPrint("Error conexión upload: $e");
      return null;
    }
  }

  // ==========================================================
  // 4. PORTFOLIO Y CONTENIDO
  // ==========================================================

  Future<List<dynamic>?> getPortfolioPosts() async {
    final token = await getToken();
    if (token == null) return null;

    final url = Uri.parse('$baseUrl/artists/me/posts');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error getPortfolioPosts: $e');
    }
    return null;
  }

  Future<bool> uploadPortfolioImage(String imagePath, {String description = '', String styleTag = ''}) async {
    final token = await getToken();
    if (token == null) return false;

    final url = Uri.parse('$baseUrl/artists/me/posts');
    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['description'] = description;
    request.fields['style_tag'] = styleTag;
    request.files.add(await http.MultipartFile.fromPath('file', imagePath));

    try {
      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error uploadPortfolioImage: $e');
      return false;
    }
  }

  // ==========================================================
  // 5. MENSAJERÍA Y CHAT
  // ==========================================================

  Future<List<dynamic>?> getMessageContacts() async {
    final token = await getToken();
    if (token == null) return null;

    final url = Uri.parse('$baseUrl/messages/contacts');
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error getMessageContacts: $e');
    }
    return null;
  }

  Future<List<dynamic>?> getMessagesWithArtist(String artistId) async {
    final token = await getToken();
    if (token == null) return null;

    final url = Uri.parse('$baseUrl/messages/?artist_id=$artistId');
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error getMessagesWithArtist: $e');
    }
    return null;
  }

  Future<bool> sendMessageToArtist(String artistId, String content, {String? bookingId}) async {
    final token = await getToken();
    if (token == null) return false;

    final url = Uri.parse('$baseUrl/messages/');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'receiver_id': artistId,
          'content': content,
          if (bookingId != null) 'booking_id': bookingId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sendMessageToArtist: $e');
      return false;
    }
  }

  // ==========================================================
  // 6. RESERVAS (BOOKINGS)
  // ==========================================================

  Future<bool> submitBooking({
    required String artistId,
    required String ideaDescription,
    required String bodyPart,
    String? sizeCm,
    DateTime? bookingDate,
  }) async {
    final token = await getToken();
    if (token == null) return false;

    final url = Uri.parse('$baseUrl/bookings/');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'artist_id': artistId,
          'idea_description': ideaDescription,
          'body_part': bodyPart,
          if (sizeCm != null && sizeCm.isNotEmpty) 'size_cm': sizeCm,
          if (bookingDate != null) 'booking_date': bookingDate.toIso8601String(),
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error submitBooking: $e');
      return false;
    }
  }

  Future<List<dynamic>?> getMyBookings() async {
    final token = await getToken();
    if (token == null) return null;

    final url = Uri.parse('$baseUrl/bookings/me');
    try {
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error getMyBookings: $e');
    }
    return null;
  }

  // ==========================================================
  // 7. MÉTODOS DE APOYO (Tokens y Perfiles Públicos)
  // ==========================================================

  Future<List<dynamic>?> getArtistPortfolio(String artistId) async {
    final url = Uri.parse('$baseUrl/artists/$artistId/posts');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error getArtistPortfolio: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getArtistById(String artistId) async {
    final url = Uri.parse('$baseUrl/artists/$artistId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      debugPrint('Error getArtistById: $e');
    }
    return null;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }
}