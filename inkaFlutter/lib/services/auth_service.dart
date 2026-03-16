import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

class AuthService {
  // ⚠️ Carga la URL del .env, si falla usa localhost
  final String baseUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.134:8000';

  // ==========================================================
  // 1. REGISTRO DE USUARIO BASE (Cliente)
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
      // Solo devuelve TRUE si se creó (200). Si devuelve 400 (ya existe), devuelve false.
      return response.statusCode == 200;
    } catch (e) {
      print('Error conexión register: $e');
      return false;
    }
  }

  // ==========================================================
  // 2. REGISTRO DE ARTISTA (ESTRICTO + ROBUSTO)
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

    // 🛑 ESTRICTO: Si el usuario no se pudo crear (ej: email ya existe),
    // PARAMOS AQUÍ. No permitimos reutilizar cuentas viejas.
    if (!userCreated) {
      print("Registro cancelado: El email ya existe o hubo un error.");
      return false; 
    }

    // ⏳ PAUSA TÉCNICA: Esperamos 500ms para asegurar que la DB guardó el registro
    // Esto evita el error 403 "Forbidden" por intentar entrar muy rápido
    await Future.delayed(const Duration(milliseconds: 500));

    // PASO B: Login para obtener token
    final token = await login(email, password);
    if (token == null) {
      return false;
    }

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
          'instagram_handle': '@pendiente', 
          'business_license_id': 'pendiente',
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error become-artist: $e');
      return false;
    }
  }

  // ==========================================================
  // 3. LOGIN & TOKENS
  // ==========================================================
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
      print('Error login: $e');
      return null;
    }
  }

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
      print("Error obteniendo rol: $e");
    }
    return null;
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Future<String?> getCurrentUserId() async {
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
        return data['id'];
      }
    } catch (e) {
      print('Error getCurrentUserId: $e');
    }
    return null;
  }

  // ==========================================================
  // 4. GESTIÓN DEL PERFIL DE ARTISTA
  // ==========================================================
  
  // Actualizar datos (PATCH)
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
      print('Error update artist: $e');
      return false;
    }
  }

  // Obtener mis datos (GET)
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
        // Decodificamos UTF-8 para evitar problemas con tildes
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      print('Error getArtistProfile: $e');
    }
    return null;
  }

  // Subir Certificado (POST Multipart)
  // Devuelve el JSON completo con el análisis de la IA
  Future<Map<String, dynamic>?> uploadCertificate(String filePath) async {
    final token = await getToken();
    if (token == null) return null;

    final url = Uri.parse('$baseUrl/artists/upload-certificate');
    
    try {
      var request = http.MultipartRequest('POST', url);
      
      // Headers
      request.headers['Authorization'] = 'Bearer $token';
      
      // Archivo
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      // Enviar
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Devolvemos todo el JSON (status, ai_analysis, url...)
        return jsonDecode(utf8.decode(response.bodyBytes)); 
      } else {
        print("Error subida: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error conexión upload: $e");
      return null;
    }
  }

  // ==========================================================
  // PORTFOLIO METHODS
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
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error getPortfolioPosts: $e');
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
      print('Error uploadPortfolioImage: $e');
      return false;
    }
  }

  Future<bool> deletePortfolioPost(String postId) async {
    final token = await getToken();
    if (token == null) return false;

    final url = Uri.parse('$baseUrl/artists/me/posts/$postId');
    try {
      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deletePortfolioPost: $e');
      return false;
    }
  }

  // ==========================================================
  // CLIENT METHODS
  // ==========================================================
  Future<Map<String, dynamic>?> getArtistById(String artistId) async {
    final url = Uri.parse('$baseUrl/artists/$artistId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      print('Error getArtistById: $e');
    }
    return null;
  }

  Future<List<dynamic>?> getVerifiedArtists({String? style}) async {
    final query = style != null ? '?style=$style' : '';
    final url = Uri.parse('$baseUrl/artists/$query');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error getVerifiedArtists: $e');
    }
    return null;
  }

  Future<List<dynamic>?> getArtistPortfolio(String artistId) async {
    final url = Uri.parse('$baseUrl/artists/$artistId/posts');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error getArtistPortfolio: $e');
    }
    return null;
  }

  Future<List<dynamic>?> getMessagesWithArtist(String artistId) async {
    final token = await getToken();
    if (token == null) return null;

    final url = Uri.parse('$baseUrl/messages/?artist_id=$artistId');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error getMessagesWithArtist: $e');
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
      print('Error sendMessageToArtist: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final token = await getToken();
    if (token == null) return null;

    final url = Uri.parse('$baseUrl/users/me');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      print('Error getCurrentUserProfile: $e');
    }
    return null;
  }

  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    final token = await getToken();
    if (token == null) return false;

    final url = Uri.parse('$baseUrl/users/me');
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
      print('Error updateUserProfile: $e');
      return false;
    }
  }
}