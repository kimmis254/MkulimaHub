import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mkulimahub_mobile/core/api/api_base.dart';

/// Market API methods: listings, orders, buyer marketplace, metadata.
mixin MarketApi on ApiBase {
  Future<Map<String, dynamic>> getMarketMetadata() async {
    final response = await http.get(Uri.parse('$baseUrl/api/market-metadata'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load metadata');
    }
  }

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
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print("Error fetching hub marketplace: $e");
    }
    return [];
  }

  // 🔥 CREATE A DIRECT MARKET ORDER
  Future<String?> createMarketOrder(
      int listingId,
      String orderType,
      double quantity,
      String deliveryMethod,
      String paymentMethod,
      ) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/market/listings/$listingId/order'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "order_type": orderType,
          "quantity": quantity,
          "delivery_method": deliveryMethod,
          "payment_method": paymentMethod, // 🔥 Sent to Python!
        }),
      );
      if (response.statusCode == 200) return null;
      return jsonDecode(response.body)['detail'] ?? "Failed to place order.";
    } catch (e) {
      return "Connection error.";
    }
  }

  Future<String?> purchaseHubPool(int poolId, String county, String ward, String paymentMethod) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.post(
        Uri.parse('$baseUrl/api/market/pools/$poolId/purchase'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${prefs.getString('auth_token')}'
        },
        body: json.encode({
          'county': county,
          'ward': ward,
          'payment_method': paymentMethod // Sends Pay Now or Pay On Delivery
        }),
      );
      if (response.statusCode == 200) return null;
      return json.decode(response.body)['detail'] ?? "Purchase failed.";
    } catch (e) {
      return "Network error.";
    }
  }
}
