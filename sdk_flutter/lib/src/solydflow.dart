import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'models/package.dart';

class SolydFlow {
  // Inside SolydFlow class
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  static String? _apiKey;
  static String? _userID;
  
  // ⚠️ REMINDER: Change this to your Laptop IP
  static const String _baseUrl = "https://www.solydflow.com"; //"http://127.0.0.1:8080"; 

  // 1. Configure & Identify
  static Future<void> configure({required String apiKey, required String userID}) async {
    _apiKey = apiKey;
    _userID = userID;
    
    try {
      print("🔌 SolydFlow: Identifying User $_userID...");
      await _dio.get('$_baseUrl/api/v1/identify', queryParameters: {"user_id": _userID});
      print("✅ User Identified.");
    } catch (e) {
      print("❌ Connection Error: $e");
    }
  }

  static Future<List<SolydPackage>> getOfferings() async {
    try {
      // Pass the API Key in the header
      final response = await _dio.get(
        '$_baseUrl/api/v1/offerings',
        options: Options(headers: {"X-API-Key": _apiKey}),
      );

      List<dynamic> data = response.data['offerings'];
      return data.map((json) => SolydPackage.fromJson(json)).toList();
    } catch (e) {
      print("❌ Error fetching offerings: $e");
      return [];
    }
  }

  // 2. Check Status (Am I Pro?)
  static Future<bool> getIsPro() async {
    if (_userID == null) return false;
    try {
      final response = await _dio.get('$_baseUrl/api/v1/status', queryParameters: {"user_id": _userID});
      return response.data['is_pro'] == true;
    } catch (e) {
      print("❌ Status Check Failed: $e");
      return false; // Default to free on error (for now)
    }
  }

  // 3. Mock Purchase (For Testing Only)
  static Future<void> mockPurchase() async {
    if (_userID == null) return;
    try {
      print("💸 Attempting Mock Purchase...");
      await _dio.get('$_baseUrl/api/v1/pay/mock', queryParameters: {"user_id": _userID});
      print("✅ Mock Purchase Successful!");
    } catch (e) {
      print("❌ Purchase Failed: $e");
    }
  }

  // --- NEW: REAL PURCHASE FLOW ---
  // Change the signature to accept 'packageIdentifier'
  static Future<void> purchasePackage(BuildContext context, String packageIdentifier) async {
    if (_userID == null) return;

    try {
      print("🚀 Initializing Transaction for $packageIdentifier...");
      final response = await _dio.get(
        '$_baseUrl/api/v1/pay/initialize', 
        queryParameters: {
          "user_id": _userID, 
          "email": "test@user.com",
          "package_identifier": packageIdentifier // <--- SEND TO SERVER
        }
      );
      
      final String authUrl = response.data['authorization_url'];
      final String reference = response.data['reference'];

      // ... rest of the function remains the same ...
      print("🔗 Opening WebView: $authUrl");

      await Navigator.of(context).push(MaterialPageRoute(builder: (ctx) {
        return _PaymentWebView(
          url: authUrl, 
          reference: reference, 
          onSuccess: () => Navigator.pop(ctx)
        );
      }));

      await _verifyTransaction(reference);

    } catch (e) {
      print("❌ Purchase Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
  static Future<void> purchasePackage_old(BuildContext context) async {
    if (_userID == null) return;

    try {
      // 1. Initialize: Get URL from Backend
      print("🚀 Initializing Paystack Transaction...");
      final response = await _dio.get(
        '$_baseUrl/api/v1/pay/initialize', 
        queryParameters: {"user_id": _userID, "email": "test@user.com"}
      );
      
      final String authUrl = response.data['authorization_url'];
      final String reference = response.data['reference'];

      print("🔗 Opening WebView: $authUrl");

      // 2. Open WebView
      await Navigator.of(context).push(MaterialPageRoute(builder: (ctx) {
        return _PaymentWebView(
          url: authUrl, 
          reference: reference, 
          onSuccess: () => Navigator.pop(ctx)
        );
      }));

      // 3. Verify on Return (Polling mechanism)
      print("🔍 Verifying Transaction $reference...");
      await _verifyTransaction(reference);

    } catch (e) {
      print("❌ Purchase Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // Update this method inside SolydFlow class
  static Future<void> _verifyTransaction(String reference) async {
    int attempts = 0;
    const int maxAttempts = 10; // Try for 20 seconds (10 * 2s)

    while (attempts < maxAttempts) {
      try {
        attempts++;
        print("⏳ Verifying... Attempt $attempts/$maxAttempts");

        final response = await _dio.get(
          '$_baseUrl/api/v1/pay/verify', 
          queryParameters: {"reference": reference}
        );

        if (response.data['status'] == 'success') {
          print("✅ Payment Verified! User is now Pro.");
          return; // Success! Exit loop.
        }
      } catch (e) {
        print("⚠️ Network glitch during verify, retrying...");
      }

      // Wait 2 seconds before asking again
      await Future.delayed(const Duration(seconds: 2));
    }
    
    print("❌ Verification timed out. Logic will rely on Webhook later.");
  }
}


// --- INTERNAL WEBVIEW WIDGET ---
class _PaymentWebView extends StatefulWidget {
  final String url;
  final String reference;
  final VoidCallback onSuccess;

  const _PaymentWebView({required this.url, required this.reference, required this.onSuccess});

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
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // Paystack redirects to standard callback URLs on success
            // In Alpha, we can just let the user close it, 
            // OR detect a success URL if you configured one in Paystack Dashboard.
            // For now, we rely on the user clicking "I've Paid" or closing the modal.
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Secure Checkout")),
      body: WebViewWidget(controller: _controller),
    );
  }
}
