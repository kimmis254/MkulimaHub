import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mkulimahub_mobile/core/api/api_base.dart';

/// Authentication API methods: login, register, Google auth, phone auth, password reset.
mixin AuthApi on ApiBase {
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<String?> login(String phone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': phone, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveToken(data['access_token']);
        return null;
      } else {
        // 🔥 Catch the EXACT error FastAPI is sending!
        final errorData = jsonDecode(response.body);
        return errorData['detail'] ?? "Invalid phone or password.";
      }
    } catch (e) {
      return "Network error. Is your Python server running?";
    }
  }

  Future<String?> register(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['access_token'] != null) {
          await _saveToken(data['access_token']);
        }
        return null; // Null means Success!
      } else {
        final decoded = jsonDecode(response.body);

        // 🔥 Safely extract the error, even if FastAPI sends a 422 List!
        if (decoded['detail'] != null) {
          if (decoded['detail'] is List) {
            return "Please fill in all required fields correctly.";
          }
          return decoded['detail'].toString();
        }
        return "Registration failed. Please try again.";
      }
    } catch (e) {
      return "Connection error. Please check your internet.";
    }
  }

  // 🔥 NEW: Google Login/Signup Endpoint
  Future<String?> googleLogin({
    required String idToken,
    String? overrideRole,
  }) async {
    try {
      print("=================================");
      print("STARTING GOOGLE LOGIN");
      print("BASE URL: $baseUrl");
      print("REQUEST URL: $baseUrl/api/auth/google");

      final requestBody = {
        'id_token': idToken,
        if (overrideRole != null) 'role': overrideRole,
      };

      print("REQUEST BODY: ${jsonEncode(requestBody)}");

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/google'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print("STATUS CODE: ${response.statusCode}");
      print("RESPONSE BODY: ${response.body}");
      print("=================================");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        print("DECODED RESPONSE: $data");

        if (data['status'] == 'needs_phone') {
          print("USER NEEDS PHONE");
          return 'needs_phone';
        }

        final token = data['access_token'];

        if (token != null) {
          print("TOKEN RECEIVED");

          await _saveToken(token);

          print("TOKEN SAVED");

          if (data['needs_profile'] == true) {
            print("USER NEEDS PROFILE");
            return 'needs_profile';
          }

          print("LOGIN SUCCESS");
          return 'success';
        }
      }

      final error =
          jsonDecode(response.body)['detail'] ?? 'Google login failed';

      print("LOGIN FAILED: $error");

      return error;
    } catch (e) {
      print("GOOGLE LOGIN ERROR: $e");
      return 'Connection error. Please check your internet.';
    }
  }

  Future<String?> googleRegister({
    required String idToken,
    required String phoneNumber,
    String? role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/google-register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': idToken,
          'phone_number': phoneNumber,
          if (role != null) 'role': role,
        }),
      );

      if (response.statusCode == 200) {
        final respData = jsonDecode(response.body);
        final token = respData['access_token'];
        if (token != null) await _saveToken(token);
        return respData['status'];
      } else {
        final errorData = jsonDecode(response.body);
        return errorData['detail'] ?? 'Registration failed.';
      }
    } catch (e) {
      return 'Network error. Please check your connection.';
    }
  }

  Future<String?> phoneLogin({
    required String phone,
    required String uid,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/phone-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phone, 'uid': uid}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];

        if (token != null) {
          await _saveToken(token);
          return null; // Success!
        } else {
          return 'Failed to retrieve access token.';
        }
      } else {
        final errorData = jsonDecode(response.body);
        return errorData['detail'] ?? 'Login failed. Please try again.';
      }
    } catch (e) {
      return 'Network error. Please check your connection.';
    }
  }

  Future<String?> verifyCredentials(String phone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {"username": phone, "password": password},
      );

      if (response.statusCode == 200) {
        return null; // Password is correct!
      } else {
        return "Invalid phone number or password.";
      }
    } catch (e) {
      return "Connection error. Check your network.";
    }
  }

  Future<String?> resetPassword({
    required String phone,
    required String uid,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phone,
          'uid': uid,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return null; // Success!
      } else {
        final errorData = jsonDecode(response.body);
        return errorData['detail'] ??
            'Failed to reset password. Please try again.';
      }
    } catch (e) {
      return 'Network error. Please check your connection.';
    }
  }

  Future<String?> deleteAccount() async {
    final token = await getToken();
    if (token == null) return "Not authenticated";

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/me'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        await logout(); // Clear the local token
        return null;
      } else {
        return "Failed to delete account data.";
      }
    } catch (e) {
      return "Network error: $e";
    }
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

  Future<String?> registerBuyer(
      String companyName,
      String phone,
      String password,
      ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': companyName,
          'phone_number': phone,
          'password': password,
          'role': 'buyer',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null; // Success!
      }
      return jsonDecode(response.body)['detail'] ?? 'Registration failed.';
    } catch (e) {
      return 'Network error. Check your connection.';
    }
  }
}
