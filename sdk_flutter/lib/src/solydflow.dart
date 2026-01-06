import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'models/package.dart';
import 'models/customer_info.dart';

class SolydFlow {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  
  static String? _apiKey;
  static String? _userID;
  static const String _baseUrl = "https://solydflow.com"; 

  // --- CONFIGURATION ---
  static Future<void> configure({required String apiKey, required String userID}) async {
    _apiKey = apiKey;
    _userID = userID;
    // Initial handshake to create user if needed
    try {
      await _dio.get('$_baseUrl/api/v1/status', queryParameters: {"user_id": _userID});
    } catch (e) {
      print("SolydFlow Init Warning: $e");
    }
  }

  // --- FETCH PRODUCTS ---
  static Future<List<SolydPackage>> getOfferings() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/v1/offerings',
        options: Options(headers: {"X-API-Key": _apiKey}),
      );
      List<dynamic> data = response.data['offerings'];
      return data.map((json) => SolydPackage.fromJson(json)).toList();
    } catch (e) {
      print("Error fetching offerings: $e");
      return [];
    }
  }

  // --- PURCHASE LOGIC ---
  static Future<CustomerInfo?> purchasePackage(BuildContext context, String packageIdentifier) async {
    if (_userID == null) throw Exception("SolydFlow not configured");

    try {
      // 1. Initialize
      final response = await _dio.get(
        '$_baseUrl/api/v1/pay/initialize', 
        queryParameters: {
          "user_id": _userID, 
          "package_identifier": packageIdentifier
        },
        options: Options(headers: {"X-API-Key": _apiKey}), // Send Key!
      );
      
      final String authUrl = response.data['authorization_url'];
      final String reference = response.data['reference'];

      // 2. Open UI
      await Navigator.of(context).push(MaterialPageRoute(builder: (ctx) {
        return _PaymentWebView(
          url: authUrl, 
          reference: reference, 
        );
      }));

      // 3. Verify & Return New Info
      return await _verifyTransaction(reference);

    } catch (e) {
      print("Purchase failed: $e");
      rethrow;
    }
  }

  // --- ENTITLEMENT CHECKS ---
  
  // The New Standard: Check specific entitlement
  static Future<bool> hasEntitlement(String entitlementID) async {
    CustomerInfo info = await getCustomerInfo();
    return info.activeEntitlements[entitlementID] == true;
  }

  // Get full info object
  static Future<CustomerInfo> getCustomerInfo() async {
    if (_userID == null) throw Exception("User ID not set");
    try {
      final response = await _dio.get('$_baseUrl/api/v1/status', queryParameters: {"user_id": _userID});
      return CustomerInfo.fromJson(response.data);
    } catch (e) {
      // Return empty info on error (offline mode would use cache here)
      return CustomerInfo(userID: _userID!, activeEntitlements: {}, allEntitlements: {});
    }
  }

  // INTERNAL VERIFICATION LOOP
  static Future<CustomerInfo> _verifyTransaction(String reference) async {
    int attempts = 0;
    while (attempts < 5) {
      attempts++;
      try {
        final response = await _dio.get(
          '$_baseUrl/api/v1/pay/verify', 
          queryParameters: {"reference": reference}
        );
        if (response.data['status'] == 'success') {
          return await getCustomerInfo(); // Sync latest data
        }
      } catch (e) {}
      await Future.delayed(const Duration(seconds: 2));
    }
    return await getCustomerInfo(); // Return whatever we have
  }
}

// Minimal WebView Widget
class _PaymentWebView extends StatefulWidget {
  final String url;
  final String reference;
  const _PaymentWebView({required this.url, required this.reference});

  @override
  State<_PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<_PaymentWebView> {
  late final WebViewController _controller;
  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Secure Checkout"), leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      )),
      body: WebViewWidget(controller: _controller),
    );
  }
}