import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Abstract base that all API mixins depend on.
/// Provides baseUrl, token management, and the generic putRequest helper.
abstract class ApiBase {
  String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://owl-catapult-sulk.ngrok-free.dev';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<void> saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
  }

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  /// Generic authenticated PUT helper available to all mixins.
  Future<String?> putRequest(String endpoint, Map<String, dynamic> body) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return null;
      } else {
        final decoded = jsonDecode(response.body);
        return decoded['detail'] ?? 'An error occurred during update.';
      }
    } catch (e) {
      return 'Connection error. Please check your internet.';
    }
  }
}
