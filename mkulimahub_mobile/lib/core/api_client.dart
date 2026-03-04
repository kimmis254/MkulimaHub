import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 🔥 Import dotenv
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mkulimahub_mobile/features/home/harvest_model.dart';

class ApiClient {
  // 🔥 Dynamic base URL! No more hardcoded IPs. 
  // It checks the .env file. If it fails, it defaults to the Android Emulator IP.
  String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://192.168.100.4:8000'; 

  Future<String?> login(String phone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'), 
        headers: {
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
        return null; 
      } else {
        return "Login failed: ${response.body}";
      }
    } catch (e) {
      return "Connection error. Check your network or server.";
    }
  }

  Future<String?> register(Map<String, dynamic> userData) async {
    try {
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

  Future<Map<String, dynamic>?> getProfile() async {
    final token = await getToken(); 
    if (token == null) return null;

    try {
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
      final response = await http.put(
        Uri.parse('$baseUrl/users/profile'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return null; 
      } else {
        return "Update failed: ${response.body}";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }

  Future<List<Harvest>> getHarvests() async {
    try {
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

  Future<List<dynamic>> getPrediction(String commodity, String region) async {
    final url = Uri.parse('$baseUrl/predict');
    
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "commodity": commodity.toLowerCase(),
        "days": 30,
        "region": region.toLowerCase() 
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['forecast']; 
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['detail'] ?? 'AI failed to process this request.');
    }
  }

  // 🔥 FIXED: Now uses dynamic baseUrl instead of hardcoded 192.168.X.X
  Future<Map<String, dynamic>> getMarketMetadata() async {
    final url = Uri.parse('$baseUrl/api/market-metadata'); 
    
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load market metadata');
    }
  }

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

  Future<List<dynamic>> getContracts({String? county}) async {
    try {
      String url = '$baseUrl/api/contracts';
      if (county != null && county.isNotEmpty) {
        url += '?county=$county';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Failed to fetch contracts: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching contracts: $e");
    }
    return [];
  }

  Future<String?> createPledge(int contractId, double weightKg) async {
    final token = await getToken();
    if (token == null) return "Please login first to pledge.";

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/contracts/$contractId/pledge'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "pledged_weight_kg": weightKg
        }),
      );

      if (response.statusCode == 200) {
        return null; 
      } else {
        return "Failed to pledge: ${response.body}";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<List<dynamic>> getMyPledges() async {
    final token = await getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/my-pledges'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error fetching my pledges: $e");
    }
    return [];
  }

  Future<List<dynamic>> getHubMessages(String hubName) async {
    final token = await getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/hubs/$hubName/messages'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error fetching hub messages: $e");
    }
    return [];
  }

  Future<String?> postHubMessage(String hubName, String message) async {
    final token = await getToken();
    if (token == null) return "Please login to chat.";

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/hubs/$hubName/messages'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"message": message}),
      );

      if (response.statusCode == 200) {
        return null; 
      } else {
        return "Failed to send: ${response.body}";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }

  Future<String> askAI(String message) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ai-chat'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'] ?? "I couldn't process that.";
      } else {
        return "Server error: ${response.statusCode}";
      }
    } catch (e) {
      return "Connection error. Make sure your Python server is running!";
    }
  }
}