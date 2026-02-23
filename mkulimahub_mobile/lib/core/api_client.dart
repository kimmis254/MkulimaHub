import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mkulimahub_mobile/features/home/harvest_model.dart';

class ApiClient {
  // 1. YOUR IP ADDRESS (Ensure this is correct)
  static const String baseUrl = 'http://192.168.100.4:8000'; 

  // --- AUTHENTICATION ---

  Future<String?> login(String phone, String password) async {
    try {
      // FIX 1: MATCHED SWAGGER '/auth/login'
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'), 
        headers: {
          // Try JSON first as it is a custom endpoint
          "Content-Type": "application/x-www-form-urlencoded" 
        },
        body: {
          "username": phone, 
          "password": password
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        await _saveToken(token); 
        return null; // Success
      } else {
        return "Login failed: ${response.body}";
      }
    } catch (e) {
      return "Connection error. Check IP or Server.";
    }
  }

  Future<String?> register(Map<String, dynamic> userData) async {
    try {
      // FIX 2: MATCHED SWAGGER '/auth/register'
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(userData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null; 
      } else {
        return "Registration failed: ${response.body}";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // --- PROFILE ---

  Future<Map<String, dynamic>?> getProfile() async {
    final token = await getToken(); 
    if (token == null) return null;

    try {
      // FIX 3: MATCHED SWAGGER '/users/me' (This one was correct)
      final response = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error fetching profile: $e");
    }
    return null;
  }

  Future<String?> updateProfile(Map<String, dynamic> data) async {
    final token = await getToken();
    if (token == null) return "Not authenticated";

    try {
      print("SENDING UPDATE: ${jsonEncode(data)}");

      // FIX 4: MATCHED SWAGGER '/users/profile' (was /users/me)
      final response = await http.put(
        Uri.parse('$baseUrl/users/profile'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        return "Update failed: ${response.body}";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }

  // --- HARVESTS ---

  Future<List<Harvest>> getHarvests() async {
    try {
      // FIX 5: REMOVED TRAILING SLASH '/harvests'
      final response = await http.get(Uri.parse('$baseUrl/harvests'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Harvest.fromJson(json)).toList();
      }
    } catch (e) {
      print("Error fetching harvests: $e");
    }
    return [];
  }

  Future<String?> addHarvest(Map<String, dynamic> harvestData) async {
    final token = await getToken();
    if (token == null) return "Please login first";

    try {
      // FIX 6: REMOVED TRAILING SLASH '/harvests'
      final response = await http.post(
        Uri.parse('$baseUrl/harvests'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(harvestData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null;
      } else {
        return "Failed to post: ${response.body}";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }

  // --- PREDICTIONS ---

  Future<List<dynamic>> getPrediction(String cropName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict'), // NO trailing slash here!
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "commodity": cropName, 
          "days": 7              
        }), 
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['forecast'] ?? [];
      }
    } catch (e) {
      print("Prediction error: $e");
    }
    return [];
  }

  // --- AI CLUSTERING ---

  Future<Map<String, dynamic>> getClusters([String? crop]) async {
    try {
      String url = '$baseUrl/api/clusters';
      
      if (crop != null && crop != 'All') {
        url += '?crop=$crop';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Failed to fetch clusters: ${response.statusCode}");
        return {'hubs': [], 'total_farmers_analyzed': 0};
      }
    } catch (e) {
      print("Error fetching clusters: $e");
      return {'hubs': [], 'total_farmers_analyzed': 0};
    }
  }

  // --- HELPER METHODS ---

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
}