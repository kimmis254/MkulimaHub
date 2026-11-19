import 'package:shared_preferences/shared_preferences.dart';

import 'package:mkulimahub_mobile/core/api/api_base.dart';
import 'package:mkulimahub_mobile/core/api/auth_api.dart';
import 'package:mkulimahub_mobile/core/api/harvest_api.dart';
import 'package:mkulimahub_mobile/core/api/market_api.dart';
import 'package:mkulimahub_mobile/core/api/hub_api.dart';
import 'package:mkulimahub_mobile/core/api/contract_api.dart';
import 'package:mkulimahub_mobile/core/api/delivery_api.dart';
import 'package:mkulimahub_mobile/core/api/payment_api.dart';
import 'package:mkulimahub_mobile/core/api/ai_api.dart';

/// The main API client used throughout the app.
/// Extends ApiBase (provides baseUrl + token management) and
/// mixes in all domain-specific API classes.
/// Every screen still calls `ApiClient()` with zero changes.
class ApiClient extends ApiBase
    with
        AuthApi,
        HarvestApi,
        MarketApi,
        HubApi,
        ContractApi,
        DeliveryApi,
        PaymentApi,
        AiApi {
  /// Save a JWT token to SharedPreferences.
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
}

