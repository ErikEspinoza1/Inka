import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Importar

class AuthService {
  // ⚠️ Asegúrate de que esta IP es correcta
  final String baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8000';
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
      debugPrint('Error conexión register: $e');
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
      debugPrint("Registro cancelado: El email ya existe o hubo un error.");
      return false;
    }

    // ⏳ PAUSA TÉCNICA: Esperamos 500ms para asegurar que la DB guardó el registro
    // Esto evita el error 403 "Forbidden" por intentar entrar muy rápido
    await Future.delayed(const Duration(milliseconds: 500));

    // PASO B: Login para obtener token
    final token = await login(email, password);
    if (token == null) {
      // Si falla el login justo después de crear la cuenta, es un error raro de conexión
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
      debugPrint('Error become-artist: $e');
      return false;
    }
  }

  // ... (El resto de métodos: login, getUserRole, getToken, logout se quedan igual) ...
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
}
