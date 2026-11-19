import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mkulimahub_mobile/core/api/api_base.dart';

/// Delivery API methods: my-deliveries, hub deliveries, QA, status updates.
mixin DeliveryApi on ApiBase {
  Future<List<dynamic>?> getMyDeliveries() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/my-deliveries'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<dynamic>?> getHubDeliveries() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/hubs/deliveries'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> processDelivery(
      int squadId,
      String action,
      double? actualWeight,
      String? notes,
      ) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/hubs/deliveries/$squadId/process'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "action": action,
          "actual_weight_kg": actualWeight,
          "notes": notes,
        }),
      );
      if (response.statusCode == 200) return null; // Success
      return jsonDecode(response.body)['detail'] ??
          'Failed to process delivery.';
    } catch (e) {
      return 'Network error.';
    }
  }

  Future<String?> updateSquadDeliveryStatus(
      int bulkRequestId,
      String status,
      ) async {
    final token = await getToken();
    if (token == null) return "Authentication required";

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/deliveries/squad/$bulkRequestId/status'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"status": status}),
      );

      if (response.statusCode == 200) {
        return null; // Success!
      } else {
        return jsonDecode(response.body)['detail'] ??
            "Failed to update status.";
      }
    } catch (e) {
      return "Connection error: $e";
    }
  }

  Future<String?> submitUnattendedDropoff(
      int squadId,
      String scalePhotoBase64,
      String cropPhotoBase64,
      ) async {
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
        return jsonDecode(response.body)['detail'] ??
            "Failed to submit drop-off.";
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

  Future<String?> updateIndividualPledgeStatus(int pledgeId, String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.put(
        Uri.parse('$baseUrl/api/pledges/$pledgeId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${prefs.getString('auth_token')}'
        },
        body: json.encode({'status': status}),
      );
      if (response.statusCode == 200) return null;
      return json.decode(response.body)['detail'] ?? "Failed to update status.";
    } catch (e) {
      return "Network error.";
    }
  }

  Future<String?> receiveLineItem(
      int pledgeId,
      double actualWeight,
      String notes,
      ) async {
    return putRequest('/api/pledges/$pledgeId/receive-line-item', {
      "actual_weight_kg": actualWeight,
      "notes": notes,
    });
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

  Future<String?> updateQAStatus(
      int pledgeId,
      String status,
      String notes,
      ) async {
    return putRequest('/api/buyer/pledges/$pledgeId/qa', {
      "status": status,
      "notes": notes,
    });
  }

  Future<String?> updateDirectOrderQA(int orderId, String status) async {
    return putRequest('/api/buyer/orders/$orderId/qa', {
      "status": status,
      "notes": "Direct Order Inspected and Approved",
    });
  }

  Future<String?> updateDirectOrderStatus(int orderId, String status) async {
    return putRequest('/api/farmer/orders/$orderId/status', {"status": status});
  }

  // 🔥 NEW: For Farmer's unified deliveries tracking
  Future<String?> updateDeliveryStatus(int deliveryId, String type, String newStatus) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final response = await http.put(
        Uri.parse('$baseUrl/api/delivery/update/$deliveryId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${prefs.getString('auth_token')}'
        },
        body: json.encode({
          'type': type,
          'status': newStatus
        }),
      );

      if (response.statusCode == 200) return null; // null means success!

      return json.decode(response.body)['detail'] ?? "Failed to update logistics.";
    } catch (e) {
      return "Network error: $e";
    }
  }

  // 🔥 Buyer: Uploads dispute photo and notes
  Future<String?> disputeDirectOrder(
      int orderId,
      String notes,
      String? imageBase64,
      ) async {
    return putRequest('/api/buyer/orders/$orderId/qa', {
      "status": "disputed",
      "notes": notes,
      "dispute_image": imageBase64,
    });
  }
}
