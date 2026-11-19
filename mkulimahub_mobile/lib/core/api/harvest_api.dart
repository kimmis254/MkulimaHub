import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mkulimahub_mobile/core/api/api_base.dart';
import 'package:mkulimahub_mobile/features/home/harvest_model.dart';

/// Harvest & listing API methods: fetch, create, update, delete harvests/listings.
mixin HarvestApi on ApiBase {
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

  Future<String?> updateMarketListing(
      int listingId,
      double availableKg,
      double? pricePerKg,
      List<Map<String, dynamic>> unitPricing,
      ) async {
    return putRequest('/api/market/listings/$listingId', {
      "available_kg": availableKg,
      "price_per_kg": pricePerKg,
      "unit_pricing": unitPricing,
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
}
