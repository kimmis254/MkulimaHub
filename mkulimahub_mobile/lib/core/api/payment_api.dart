import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mkulimahub_mobile/core/api/api_base.dart';

/// Payment & Wallet API methods: M-Pesa, escrow, wallet, withdrawals.
mixin PaymentApi on ApiBase {
  // Secret DEV-Mode STK Push Simulator
  Future<String?> simulateDevPayment(int orderId) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/dev/pay-now/$orderId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return null; // Success!
      return jsonDecode(response.body)['detail'] ?? "Payment failed";
    } catch (e) {
      return "Network error";
    }
  }

  // Update your triggerMpesaPayment to accept the customEndpoint
  Future<String?> triggerMpesaPayment(int id, {bool isBulk = false, String? customEndpoint}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final endpoint = customEndpoint ?? (isBulk ? '/api/market/pools/$id/pay/mpesa' : '/api/buyer/orders/$id/pay/mpesa');

      final response = await http.post(
          Uri.parse('$baseUrl$endpoint'),
          headers: headers
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // 🔥 THE FIX: Return the checkout_id hidden inside a success message!
        return "SUCCESS:${data['checkout_id']}";
      } else {
        return data['detail'] ?? "Payment failed.";
      }
    } catch (e) {
      return "Network error: Could not reach payment server.";
    }
  }

  // Update the 3 helper methods to return what triggerMpesaPayment returns
  Future<String?> triggerContractDeposit(int contractId) async {
    return await triggerMpesaPayment(contractId, customEndpoint: '/api/contracts/$contractId/pay-deposit');
  }

  Future<String?> triggerPledgePodPayment(int pledgeId) async {
    return await triggerMpesaPayment(pledgeId, customEndpoint: '/api/pledges/$pledgeId/pay-pod');
  }

  Future<String?> triggerContractBalance(int contractId) async {
    return await triggerMpesaPayment(contractId, customEndpoint: '/api/contracts/$contractId/pay-balance');
  }

  // 2. Process a Farmer's Refund (Issue 7a)
  Future<String?> refundPledge(int pledgeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.put(
        Uri.parse('$baseUrl/api/qa/pledges/$pledgeId/refund'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${prefs.getString('auth_token')}'},
      );
      if (response.statusCode == 200) return null;
      return json.decode(response.body)['detail'] ?? "Refund failed.";
    } catch (e) { return "Network error."; }
  }

  Future<String?> releaseContractEscrow(int contractId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.post(
        Uri.parse('$baseUrl/api/contracts/$contractId/release-escrow'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${prefs.getString('auth_token')}'},
      );
      if (response.statusCode == 200) return null;
      return json.decode(response.body)['detail'] ?? "Failed to release escrow.";
    } catch (e) { return "Network error."; }
  }

  Future<Map<String, dynamic>?> getFarmerWallet() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/farmer/wallet'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      print("Wallet Fetch Error: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getBuyerWallet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.get(
        Uri.parse('$baseUrl/api/buyer/wallet'),
        headers: {'Authorization': 'Bearer ${prefs.getString('auth_token')}'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { return null; }
    return null;
  }

  Future<String?> withdrawFunds(double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.post(
        Uri.parse('$baseUrl/api/wallet/withdraw'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${prefs.getString('auth_token')}'},
        body: json.encode({'amount': amount}),
      );
      if (response.statusCode == 200) return null;
      return json.decode(response.body)['detail'] ?? "Withdrawal failed.";
    } catch (e) { return "Network error."; }
  }

  Future<String> checkPaymentStatus(String checkoutId) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/payments/status/$checkoutId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['status'] ?? 'pending';
      }
      return 'pending';
    } catch (e) {
      return 'pending';
    }
  }
}
