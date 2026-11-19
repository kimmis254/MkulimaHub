import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mkulimahub_mobile/core/api/api_base.dart';

/// Hub & Co-op API methods: clusters, nearby hubs, elections, hub chat, hub pools.
mixin HubApi on ApiBase {
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
          "Authorization": "Bearer $token",
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
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/hubs/nearby'),
        headers: {'Authorization': 'Bearer $token'},
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
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/hubs/$hubId/join'),
        headers: {'Authorization': 'Bearer $token'},
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
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/coordinator/requests'),
        headers: {'Authorization': 'Bearer $token'},
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
      final token = await getToken();
      final response = await http.put(
        Uri.parse(
          '$baseUrl/api/coordinator/requests/$requestId?action=$action',
        ),
        headers: {'Authorization': 'Bearer $token'},
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
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/hubs/election/ballot'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> runForCoordinator(String pitch) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.post(
        Uri.parse('$baseUrl/api/hubs/election/run'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${prefs.getString('auth_token')}'},
        body: json.encode({'pitch': pitch}),
      );
      if (response.statusCode == 200) return null;
      return json.decode(response.body)['detail'] ?? "Failed to submit candidacy.";
    } catch (e) { return "Network error."; }
  }

  Future<String?> castVote(int candidateId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.post(
        Uri.parse('$baseUrl/api/hubs/election/vote/$candidateId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${prefs.getString('auth_token')}'},
      );
      if (response.statusCode == 200) return null;
      return json.decode(response.body)['detail'] ?? "Failed to cast vote.";
    } catch (e) { return "Network error."; }
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

  Future<String?> createHubPool(
      String hubName,
      Map<String, dynamic> data,
      ) async {
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
}
