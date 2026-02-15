import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mkulimahub_mobile/features/home/harvest_model.dart';

class ApiClient {
  // 10.0.2.2 is the special IP for Android Emulator to reach localhost
  static const String baseUrl = 'http://192.168.100.4:8000'; 
  
  final Dio dio = Dio(BaseOptions(baseUrl: baseUrl));
  final storage = const FlutterSecureStorage();

  // Login Function
  Future<String?> login(String phone, String password) async {
    try {
      // API expects "username" and "password" (OAuth2 Standard)
      final response = await dio.post('/auth/login', data: {
        'username': phone, 
        'password': password,
      }, options: Options(contentType: Headers.formUrlEncodedContentType));

      if (response.statusCode == 200) {
        // Extract token
        final token = response.data['access_token'];
        // Save token securely to phone storage
        await storage.write(key: 'auth_token', value: token);
        return null; // Null means success (no error message)
      } else {
        return 'Login Failed';
      }
    } on DioException catch (e) {
      if (e.response != null) {
        return 'Error: ${e.response?.data['detail'] ?? "Unknown Error"}';
      }
      return 'Connection Error. Is Backend running?';
    }
  }
  Future<List<Harvest>> getHarvests() async {
    try {
      final response = await dio.get('/harvests');
      
      if (response.statusCode == 200) {
        // Convert list of JSON objects to list of Harvest objects
        List<dynamic> data = response.data;
        return data.map((json) => Harvest.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load harvests');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }
  Future<String?> getToken() async {
    return await storage.read(key: 'auth_token');
  }

  // Logout (Clear token)
  Future<void> logout() async {
    await storage.delete(key: 'auth_token');
  }

  // Register (We need to move the register logic here for cleaner code)
  Future<String?> register(Map<String, dynamic> userData) async {
    try {
      final response = await dio.post('/auth/register', data: userData);
      if (response.statusCode == 200) {
        return null; // Success
      } else {
        return 'Registration Failed';
      }
    } on DioException catch (e) {
      if (e.response != null) {
        return e.response?.data['detail'] ?? "Unknown Error";
      }
      return 'Connection Error';
    }
  }
  Future<String?> addHarvest(Map<String, dynamic> harvestData) async {
    try {
      // 1. Get the token from storage
      final token = await storage.read(key: 'auth_token');
      
      if (token == null) return "Authentication Error: No token found";

      // 2. Send POST request with "Authorization: Bearer <token>"
      final response = await dio.post(
        '/harvests', 
        data: harvestData,
        options: Options(
          headers: {
            "Authorization": "Bearer $token", // <--- THE KEY
          },
        ),
      );

      if (response.statusCode == 201) {
        return null; // Success!
      } else {
        return 'Failed to post harvest';
      }
    } on DioException catch (e) {
      if (e.response != null) {
        return e.response?.data['detail'] ?? "Unknown Error";
      }
      return 'Connection Error';
    }
  }
  Future<List<dynamic>> getPrediction(String cropName) async {
    try {
      final response = await dio.post('/predict', data: {
        "commodity": cropName,
        "days": 7 // Predict next 7 days
      });

      if (response.statusCode == 200) {
        return response.data['forecast']; // Returns the list of prices
      } else {
        throw Exception('Failed to get prediction');
      }
    } catch (e) {
      throw Exception('AI Error: $e');
    }
  }
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final token = await storage.read(key: 'auth_token');
      final response = await dio.get('/users/me', options: Options(headers: {"Authorization": "Bearer $token"}));
      return response.data;
    } catch (e) {
      return null;
    }
  }

  // PUT: Update Profile
  Future<String?> updateProfile(Map<String, dynamic> data) async {
    try {
      final token = await storage.read(key: 'auth_token');
      await dio.put('/users/profile', data: data, options: Options(headers: {"Authorization": "Bearer $token"}));
      return null; // Success
    } on DioException catch (e) {
      return "Failed to update";
    }
  }
}