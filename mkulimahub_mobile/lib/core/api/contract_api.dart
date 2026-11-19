import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mkulimahub_mobile/core/api/api_base.dart';

/// Contract & Pledge API methods: bulk requests, pledges, squad coordination.
mixin ContractApi on ApiBase {
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
        body: jsonEncode({"pledged_weight_kg": weightKg}),
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
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"pledged_weight_kg": newWeight}),
      );

      if (response.statusCode == 200) {
        return null; // Success!
      } else {
        return jsonDecode(response.body)['detail'] ??
            "Failed to update pledge.";
      }
    } catch (e) {
      return "Connection error: $e";
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
        return jsonDecode(response.body)['detail'] ??
            "Failed to delete pledge.";
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
          'Authorization': 'Bearer $token',
          // 🔥 The valid ID badge is attached!
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

  Future<String?> createBulkContract(Map<String, dynamic> contractData) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/buyer/contracts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(contractData),
      );
      if (response.statusCode == 200) return null; // Success!
      return jsonDecode(response.body)['detail'] ??
          'Failed to create contract.';
    } catch (e) {
      return 'Network error.';
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

  // 🔥 Run for temporary Squad Coordinator
  Future<String?> runForSquadCoordinator(int squadId, String pitch) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.post(
        Uri.parse('$baseUrl/api/squads/$squadId/run'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${prefs.getString('auth_token')}'},
        body: json.encode({'pitch': pitch}),
      );
      if (response.statusCode == 200) return null;
      return json.decode(response.body)['detail'] ?? "Failed to submit candidacy.";
    } catch (e) { return "Network error."; }
  }

  // 🔥 Vote for a temporary Squad Coordinator
  Future<String?> castSquadVote(int squadId, int candidateId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.post(
        Uri.parse('$baseUrl/api/squads/$squadId/vote'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${prefs.getString('auth_token')}'},
        body: json.encode({'candidate_id': candidateId}),
      );
      if (response.statusCode == 200) return null;
      return json.decode(response.body)['detail'] ?? "Failed to cast vote.";
    } catch (e) { return "Network error."; }
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

  Future<String?> delegateCoordinator(int squadId, int newCoordinatorId) async {
    return putRequest(
      '/api/squads/$squadId/delegate?new_coordinator_id=$newCoordinatorId',
      {},
    );
  }
}
