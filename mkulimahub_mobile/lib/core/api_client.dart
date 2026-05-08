import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mkulimahub_mobile/features/home/harvest_model.dart';

class ApiClient {
  // 🔥 Dynamic base URL! No more hardcoded IPs. 
  // It checks the .env file. If it fails, it defaults to the Android Emulator IP.
  String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://192.168.100.4:8000'; 


  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token'); // Must match the line above perfectly!
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
        Uri.parse('$baseUrl/api/auth/register'), // Make sure this matches your python route
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
  Future<String?> googleLogin({required String idToken, String? overrideRole}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': idToken,
          if (overrideRole != null) 'role': overrideRole, // Pass role to backend
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'needs_phone') return 'needs_phone';
        
        final token = data['access_token'];
        if (token != null) {
          await _saveToken(token);
          if (data['needs_profile'] == true) return 'needs_profile';
          return 'success';
        }
      }
      return jsonDecode(response.body)['detail'] ?? 'Google login failed';
    } catch (e) {
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
        Uri.parse('$baseUrl/api/auth/google-register'), // <-- Fixed URL
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': idToken,
          'phone_number': phoneNumber,
          if (role != null) 'role': role, // <-- Passes role to backend
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

  // ==========================================
  // HARVEST LISTING LOGIC
  // ==========================================

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

  Future<List<dynamic>> getMyHarvests() async {
    final token = await getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/harvests/me'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body); 
      }
      return [];
    } catch (e) {
      print("Error fetching harvests: $e");
      return [];
    }
  }

  Future<String?> addHarvest(Map<String, dynamic> data) async {
    final token = await getToken();
    if (token == null) return "Please login first.";

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/market/listings'), // 🔥 THE FIX: New Endpoint!
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) return null;
      return "Failed to post listing. Please try again.";
    } catch (e) {
      return "Connection error.";
    }
  }

  // ==========================================
  // AI & MARKET LOGIC
  // ==========================================

  Future<Map<String, dynamic>> getPrediction(String commodity, String region, String priceType) async {
    final url = Uri.parse('$baseUrl/api/predict-price');
    
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "commodity": commodity.toLowerCase(),
        "days": 30,
        "region": region.toLowerCase(),
        "price_type": priceType.toLowerCase() 
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body); 
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to analyze market.');
    }
  }

  Future<Map<String, dynamic>> getMarketMetadata() async {
    final response = await http.get(Uri.parse('$baseUrl/api/market-metadata'));

    if (response.statusCode == 200) {
      return json.decode(response.body); 
    } else {
      throw Exception('Failed to load metadata');
    }
  }
  
  // ==========================================
  // HUB & CO-OP LOGIC
  // ==========================================

  Future<Map<String, dynamic>> getClusters([String? crop]) async {
    // 🔥 1. Grab the secure token!
    final token = await getToken();
    if (token == null) return {'hubs': [], 'total_farmers_analyzed': 0};

    try {
      String url = '$baseUrl/api/clusters';
      
      if (crop != null && crop != 'All') {
        url += '?crop=$crop';
      }

      // 🔥 2. Attach the token to the headers!
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token" 
        },
      );

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

  Future<List<dynamic>?> getNearbyHubs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/hubs/nearby'),
        headers: {'Authorization': 'Bearer ${await _getToken()}'}, 
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> joinHub(int hubId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/hubs/$hubId/join'),
        headers: {'Authorization': 'Bearer ${await _getToken()}'},
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return null; // Success! No error message.
      } else {
        return body['detail'] ?? body['message'] ?? 'Failed to send request.';
      }
    } catch (e) {
      return 'Network error occurred.';
    }
  }

  // 🔥 NEW: Allows a farmer to cleanly leave a Hub
  Future<String?> leaveHub() async {
    final token = await getToken();
    if (token == null) return "Not authenticated";

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/leave-hub'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        return null; // Success
      } else {
        final body = jsonDecode(response.body);
        return body['detail'] ?? "Failed to leave hub.";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }

  Future<List<dynamic>?> getCoordinatorRequests() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/coordinator/requests'),
        headers: {'Authorization': 'Bearer ${await _getToken()}'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> respondToHubRequest(int requestId, String action) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/coordinator/requests/$requestId?action=$action'),
        headers: {'Authorization': 'Bearer ${await _getToken()}'},
      );
      if (response.statusCode == 200) {
        return null; // Success!
      } else {
        final body = jsonDecode(response.body);
        return body['detail'] ?? 'Failed to update request.';
      }
    } catch (e) {
      return 'Network error occurred.';
    }
  }

  Future<Map<String, dynamic>?> getElectionBallot() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/hubs/election/ballot'),
        headers: {'Authorization': 'Bearer ${await _getToken()}'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> runForCoordinator(String pitch) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/hubs/election/run'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'pitch': pitch}),
      );
      if (response.statusCode == 200) return null; // Success
      return jsonDecode(response.body)['detail'] ?? 'Failed to submit candidacy.';
    } catch (e) {
      return 'Network error.';
    }
  }

  Future<String?> castVote(int candidateId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/hubs/election/vote/$candidateId'),
        headers: {'Authorization': 'Bearer ${await _getToken()}'},
      );
      if (response.statusCode == 200) return null; // Success
      return jsonDecode(response.body)['detail'] ?? 'Failed to cast vote.';
    } catch (e) {
      return 'Network error.';
    }
  }

  Future<List<dynamic>?> getHubDeliveries() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/hubs/deliveries'),
        headers: {'Authorization': 'Bearer ${await _getToken()}'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> processDelivery(int squadId, String action, double? actualWeight, String? notes) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/hubs/deliveries/$squadId/process'), // 🔥 Updated endpoint
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "action": action,
          "actual_weight_kg": actualWeight,
          "notes": notes
        }),
      );
      if (response.statusCode == 200) return null; // Success
      return jsonDecode(response.body)['detail'] ?? 'Failed to process delivery.';
    } catch (e) {
      return 'Network error.';
    }
  }

  Future<List<dynamic>?> getMyDeliveries() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/my-deliveries'),
        headers: {'Authorization': 'Bearer ${await _getToken()}'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
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


  // ==========================================
  // PLEDGES AND CONTRACTS LOGIC
  // ==========================================

  Future<List<dynamic>> getContracts() async {
    final token = await getToken();
    if (token == null) return []; 

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/contracts'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token", // 🔥 THE MISSING KEY!
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print("Error fetching contracts: $e");
      return [];
    }
  }

  Future<String?> createPledge(int contractId, double weightKg) async {
    final token = await getToken();
    if (token == null) return "Please login first to pledge.";

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bulk-requests/$contractId/pledge'),
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

  Future<String?> updatePledge(int pledgeId, double newWeight) async {
    final token = await getToken();
    if (token == null) return "Authentication required";

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/pledges/$pledgeId'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({"pledged_weight_kg": newWeight}),
      );

      if (response.statusCode == 200) {
        return null; // Success!
      } else {
        return jsonDecode(response.body)['detail'] ?? "Failed to update pledge.";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }
  Future<String?> updatePledgeStatus(int pledgeId, String status) async {
    final token = await getToken();
    if (token == null) return "Please login first.";

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/pledges/$pledgeId/status'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"status": status}),
      );
      if (response.statusCode == 200) return null;
      return "Failed to verify drop-off.";
    } catch (e) {
      return "Connection error.";
    }
  }

  Future<String?> deletePledge(int pledgeId) async {
    final token = await getToken();
    if (token == null) return "Authentication required";

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/pledges/$pledgeId'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        return null; // Success!
      } else {
        return jsonDecode(response.body)['detail'] ?? "Failed to delete pledge.";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }

  Future<List<dynamic>> getMyPledges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 🔥 THE FIX: Using your exact secret key!
      final token = prefs.getString('auth_token') ?? '';
      
      print("🔐 DEBUG TOKEN CHECK: Does token exist? ${token.isNotEmpty}");

      final response = await http.get(
        Uri.parse('$baseUrl/api/my-pledges'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token', // 🔥 The valid ID badge is attached!
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("🔥 RAW SQUAD DATA: $data"); 
        return data;
      } else {
        print("❌ API ERROR: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print("❌ NETWORK ERROR: $e");
      return [];
    }
  }

  // ==========================================
  // 🔥 ENTERPRISE BUYER OPERATIONS
  // ==========================================
  
  Future<Map<String, dynamic>?> getBuyerDashboard() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/buyer/dashboard'),
        headers: {'Authorization': 'Bearer ${await _getToken()}'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> createBulkContract(Map<String, dynamic> contractData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/buyer/contracts'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(contractData),
      );
      if (response.statusCode == 200) return null; // Success!
      return jsonDecode(response.body)['detail'] ?? 'Failed to create contract.';
    } catch (e) {
      return 'Network error.';
    }
  }
  
  Future<String?> registerBuyer(String companyName, String phone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'), 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': companyName, 
          'phone_number': phone,
          'password': password,
          'role': 'buyer' 
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

  // 🔥 NEW: POST A BULK REQUEST
  Future<String?> postBulkRequest(Map<String, dynamic> data) async {
    final token = await getToken();
    if (token == null) return "Please login first.";

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bulk-requests/'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null; 
      } else {
        final body = jsonDecode(response.body);
        return body['detail'] ?? "Failed to post bulk request.";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }

  // 🔥 NEW: FETCH ACTIVE BULK REQUESTS
  Future<List<dynamic>> getActiveBulkRequests() async {
    final token = await getToken();
    if (token == null) return []; // Fail gracefully if not logged in

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bulk-requests/'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token", // 🔥 THE MISSING KEY!
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print("Error fetching active bulk requests: $e");
      return [];
    }
  }

  // 🔥 NEW: BUYER RELEASES ESCROW / COMPLETES ORDER
  Future<String?> completeDeliveryVerification(int pledgeId) async {
    final token = await getToken();
    if (token == null) return "Not authenticated";

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/pledges/$pledgeId/complete'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        return null; 
      } else {
        final body = jsonDecode(response.body);
        return body['detail'] ?? "Failed to verify delivery.";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }


  // ==========================================
  // UTILITY & AUTH OPERATIONS
  // ==========================================

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
  
  Future<String> askAdvancedAI({
    required String message,
    required String role,
    required String userName,
    required String location,
    required String businessDetails,
  }) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/ai-chat'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "message": message,
          "role": role,
          "user_name": userName,
          "location": location,
          "business_details": businessDetails
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'] ?? "I couldn't process that.";
      } else {
        return "Sorry, I am having trouble connecting to the network right now.";
      }
    } catch (e) {
      return "Network error: Make sure your server is running.";
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

  Future<String?> phoneLogin({required String phone, required String uid}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/phone-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phone,
          'uid': uid,
        }),
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

  Future<String?> resetPassword({required String phone, required String uid, required String newPassword}) async {
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
        return errorData['detail'] ?? 'Failed to reset password. Please try again.';
      }
    } catch (e) {
      return 'Network error. Please check your connection.';
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

  Future<void> saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
  }

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }
  // 🔥 Run for temporary Squad Coordinator
  Future<String?> runForSquadCoordinator(int squadId, String pitch) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/api/squads/$squadId/run'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: json.encode({'pitch': pitch}),
      );

      return response.statusCode == 200 ? null : json.decode(response.body)['detail'] ?? "Failed to submit candidacy.";
    } catch (e) {
      return "Network error. Please try again.";
    }
  }

  // 🔥 Vote for a temporary Squad Coordinator
  Future<String?> castSquadVote(int squadId, int candidateId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/api/squads/$squadId/vote'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: json.encode({'candidate_id': candidateId}),
      );

      return response.statusCode == 200 ? null : json.decode(response.body)['detail'] ?? "Failed to cast vote.";
    } catch (e) {
      return "Network error. Please try again.";
    }
  }
  Future<String?> triggerAdminClustering([String crop = "Maize"]) async {
    try {
      final response = await http.post(
        // We pass the crop parameter so it clusters the currently selected tab
        Uri.parse('$baseUrl/api/admin/trigger-clustering?crop=$crop'),
      );

      if (response.statusCode == 200) {
        return null; // Success!
      } else {
        final body = jsonDecode(response.body);
        return body['detail'] ?? "Failed to trigger clustering.";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }
  Future<String?> updateSquadDeliveryStatus(int bulkRequestId, String status) async {
    final token = await getToken();
    if (token == null) return "Authentication required";

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/deliveries/squad/$bulkRequestId/status'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({"status": status}),
      );

      if (response.statusCode == 200) {
        return null; // Success!
      } else {
        return jsonDecode(response.body)['detail'] ?? "Failed to update status.";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }
  Future<List<dynamic>> getSquadMessages(int bulkRequestId) async {
    final token = await getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/squads/$bulkRequestId/messages'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("❌ Error fetching squad messages: $e");
    }
    return [];
  }

  Future<String?> sendSquadMessage(int bulkRequestId, String message) async {
    final token = await getToken();
    if (token == null) return "Please login to chat.";

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/squads/$bulkRequestId/messages'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"message": message}),
      );

      if (response.statusCode == 200) {
        return null; // Success!
      } else {
        return "Failed to send: ${response.body}";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }
  Future<String?> createHubPool(String hubName, Map<String, dynamic> data) async {
    final token = await getToken();
    if (token == null) return "Please login first.";

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/hubs/$hubName/pools'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return null; 
      } else {
        return jsonDecode(response.body)['detail'] ?? "Failed to create pool.";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }
  Future<String?> submitUnattendedDropoff(int squadId, String scalePhotoBase64, String cropPhotoBase64) async {
    final token = await getToken();
    if (token == null) return "Please login first.";

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/squads/$squadId/unattended-dropoff'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "scale_photo_url": scalePhotoBase64,
          "crop_photo_url": cropPhotoBase64,
        }),
      );

      if (response.statusCode == 200) {
        return null; // Success!
      } else {
        return jsonDecode(response.body)['detail'] ?? "Failed to submit drop-off.";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }
  Future<String?> updateSquadStatus(int squadId, String status) async {
    final token = await getToken();
    if (token == null) return "Please login first.";

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/squads/$squadId/status'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"status": status}),
      );

      if (response.statusCode == 200) return null;
      return "Failed to update status.";
    } catch (e) {
      return "Connection error.";
    }
  }

  Future<String?> delegateCoordinator(int squadId, int newCoordinatorId) async {
    return _put('/api/squads/$squadId/delegate?new_coordinator_id=$newCoordinatorId', {});
  }

  Future<String?> receiveLineItem(int pledgeId, double actualWeight, String notes) async {
    return _put('/api/pledges/$pledgeId/receive-line-item', {
      "actual_weight_kg": actualWeight,
      "notes": notes
    });
  }

  Future<String?> updateMarketListing(int listingId, double availableKg, double? pricePerKg, List<Map<String, dynamic>> unitPricing) async {
    return _put('/api/market/listings/$listingId', {
      "available_kg": availableKg,
      "price_per_kg": pricePerKg,
      "unit_pricing": unitPricing
    });
  }

  Future<String?> deleteMarketListing(int listingId) async {
    final token = await getToken();
    if (token == null) return "Authentication required";
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/market/listings/$listingId'),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) return null; // Success!
      return jsonDecode(response.body)['detail'] ?? "Failed to delete listing.";
    } catch (e) {
      return "Connection error.";
    }
  }
  // BUYER SIDE /////////////

  Future<List<dynamic>> getMarketListings() async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/market/listings'),
        headers: token != null ? {"Authorization": "Bearer $token"} : {},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print("Error fetching listings: $e");
    }
    return [];
  }

  Future<List<dynamic>> getHubMarketplace() async {
    final token = await getToken();
    if (token == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/buyer/marketplace'),
        headers: {"Authorization": "Bearer $token"}
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print("Error fetching hub marketplace: $e");
    }
    return [];
  }

  // 🔥 CREATE A DIRECT MARKET ORDER
  Future<String?> createMarketOrder(int listingId, String orderType, double quantity, String deliveryMethod) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/market/listings/$listingId/order'),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode({
          "order_type": orderType, 
          "quantity": quantity,
          "delivery_method": deliveryMethod // 🔥 Sent to Python!
        }),
      );
      if (response.statusCode == 200) return null; 
      return jsonDecode(response.body)['detail'] ?? "Failed to place order.";
    } catch (e) {
      return "Connection error.";
    }
  }

  Future<String?> purchaseHubPool(int poolId, String county, String ward) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/market/pools/$poolId/purchase'),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode({
          "county": county,
          "ward": ward
        }),
      );
      if (response.statusCode == 200) return null;
      return jsonDecode(response.body)['detail'] ?? "Failed to purchase pool.";
    } catch (e) {
      return "Connection error.";
    }
  }

  Future<String?> updateQAStatus(int pledgeId, String status, String notes) async {
    return _put('/api/buyer/pledges/$pledgeId/qa', {
      "status": status,
      "notes": notes
    });
  }
  Future<String?> updateDirectOrderQA(int orderId, String status) async {
    return _put('/api/buyer/orders/$orderId/qa', {
      "status": status,
      "notes": "Direct Order Inspected and Approved"
    });
  }

  Future<String?> _put(String endpoint, Map<String, dynamic> body) async {
    try {
      // 🔥 THE FIX: Use your universal getToken() method so the key is always correct!
      final token = await getToken(); 

      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'), 
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token', // The badge is attached!
        },
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return null; // Success!
      } else {
        final decoded = jsonDecode(response.body);
        return decoded['detail'] ?? 'An error occurred during update.';
      }
    } catch (e) {
      return 'Connection error. Please check your internet.';
    }
  }
  Future<String?> updateDirectOrderStatus(int orderId, String status) async {
    return _put('/api/farmer/orders/$orderId/status', {
      "status": status,
    });
  }

  // 🔥 Buyer: Uploads dispute photo and notes
  Future<String?> disputeDirectOrder(int orderId, String notes, String? imageBase64) async {
    return _put('/api/buyer/orders/$orderId/qa', {
      "status": "disputed",
      "notes": notes,
      "dispute_image": imageBase64
    });
  }

  






}