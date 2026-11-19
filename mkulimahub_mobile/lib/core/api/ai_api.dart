import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:mkulimahub_mobile/core/api/api_base.dart';

/// AI & Dashboard API methods: AI chat, predictions, farmer/buyer dashboards, buyer insights.
mixin AiApi on ApiBase {
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
          "business_details": businessDetails,
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

  Future<Map<String, dynamic>> getPrediction(
      String commodity,
      String region,
      String priceType,
      ) async {
    final url = Uri.parse('$baseUrl/api/predict-price');

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "commodity": commodity.toLowerCase(),
        "days": 30,
        "region": region.toLowerCase(),
        "price_type": priceType.toLowerCase(),
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to analyze market.');
    }
  }

  // 🔥 NEW: For Farmer's home screen stats (Total Yield, Active Deliveries, etc.)
  Future<Map<String, dynamic>?> getFarmerDashboard() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/farmer/dashboard'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getBuyerDashboard() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/buyer/dashboard'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getBuyerInsights() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/buyer/insights'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint("Get Insights Error: $e");
      return null;
    }
  }
}
