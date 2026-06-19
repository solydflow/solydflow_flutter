import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'models/package.dart';
import 'models/customer_info.dart';
import 'models/paywall_config.dart';
import 'utils/telemetry.dart';
import 'cache_manager.dart';

class SolydFlow {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  static String? _apiKey;
  static String? _userID;
  static String? _userPhone;
  static const String _baseUrl = "https://api.solydflow.com";

  static StreamSubscription<List<PurchaseDetails>>? _iapSubscription;
  
  // HELPER MAP: Apple/Google ID -> SolydFlow Identifier
  // Needed to tell the backend what SolydFlow package was bought via Native Stores
  static final Map<String, String> _nativeStoreToSolydMap = {};

  // --- CONFIGURATION ---
  static Future<void> configure({
    required String apiKey,
    required String userID,
    String? userPhone,
  }) async {
    _apiKey = apiKey;
    _userID = userID;
    _userPhone = userPhone;

    final Stream<List<PurchaseDetails>> purchaseUpdated = InAppPurchase.instance.purchaseStream;
    _iapSubscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _iapSubscription?.cancel();
    }, onError: (error) {
      print("StoreKit Error: $error");
    });

    try {
      await _dio.get(
        '$_baseUrl/api/v1/status',
        queryParameters: {"user_id": _userID},
        options: Options(headers: {
          "X-API-Key": _apiKey,
          "Content-Type": "application/json",
        }),
      );
    } catch (e) {
      print("SolydFlow Init Warning: $e");
    }
  }

  /// NEW: Track SDK Events (Analytic Funnel)
  static Future<void> trackEvent(String eventType, {Map<String, dynamic>? metadata}) async {
    if (_userID == null || _apiKey == null) return;

    try {
      await _dio.post(
        '$_baseUrl/api/v1/event',
        data: {
          "user_id": _userID,
          "event_type": eventType,
          "metadata": metadata != null ? jsonEncode(metadata) : "{}",
        },
        options: Options(headers: {"X-API-Key": _apiKey}),
      );
    } catch (e) {
      // Silent fail for analytics
      print("SolydFlow Analytics Error: $e");
    }
  }

  // --- FETCH PRODUCTS ---
  static Future<List<SolydPackage>> getOfferings({bool silent = false}) async {
    if (_apiKey == null || _userID == null) throw Exception("SolydFlow not configured");

    // 1. Trigger Tracking automatically
    if (!silent) {
      trackEvent("paywall_viewed");
    }

    try {
      final response = await _dio.get(
        '$_baseUrl/api/v1/offerings',
        queryParameters: {"user_id": _userID},
        options: Options(headers: {"X-API-Key": _apiKey}),
      );
      List<dynamic> data = response.data['offerings'];
      
      final packages = data.map((json) => SolydPackage.fromJson(json)).toList();
      
      // Build the memory map for Native Store validation
      _nativeStoreToSolydMap.clear();
      for (var pkg in packages) {
        if (pkg.appleProductID != null && pkg.appleProductID!.isNotEmpty) {
          _nativeStoreToSolydMap[pkg.appleProductID!] = pkg.identifier;
        }
        if (pkg.googleProductID != null && pkg.googleProductID!.isNotEmpty) {
          _nativeStoreToSolydMap[pkg.googleProductID!] = pkg.identifier;
        }
      }
      
      return packages;
    } catch (e) {
      print("Error fetching offerings: $e");
      return [];
    }
  }

  // --- PURCHASE LOGIC ---
  static Future<CustomerInfo?> purchasePackage(
    BuildContext context,
    String packageIdentifier, {
    String? userPhone,
    int? customAmountKobo,
  }) async {
    if (_userID == null || _apiKey == null) throw Exception("SolydFlow not configured");

    try {
      String idempotencyKey = const Uuid().v4();
      final telemetryData = await SolydTelemetry.collect();
      // Use either the globally configured phone or the checkout-specific phone
      final String finalPhone = userPhone ?? _userPhone ?? "";
      
      final Map<String, dynamic> payload = {
          "user_id": _userID ?? "",
          "package_identifier": packageIdentifier,
          "email": "$_userID@solydflow.app",
          "phone": finalPhone,
          "custom_amount_kobo": customAmountKobo ?? 0,
          "telemetry": {
             "network_type": telemetryData['network_type'] ?? "unknown",
             "latency_ms": telemetryData['latency_ms'] ?? 0,
             "device_os": telemetryData['device_os'] ?? "unknown",
             "device_model": telemetryData['device_model'] ?? "unknown",
             "battery_level": telemetryData['battery_level'] ?? 0,
          }
      };

      final response = await _dio.post(
        '$_baseUrl/api/v1/pay/initialize',
        data: payload,
        options: Options(headers: {
          "X-API-Key": _apiKey,
          "Content-Type": "application/json",
          "Idempotency-Key": idempotencyKey,
        }),
      );
      
      final data = response.data;
      final String provider = data['provider'] ?? 'paystack'; 

      // NATIVE STORE (APPLE / GOOGLE)
      if (provider == 'apple' || provider == 'google') {
        final String nativeProductID = data['native_product_id'];
        
        final bool available = await InAppPurchase.instance.isAvailable();
        if (!available) throw Exception("Store not available");

        final ProductDetailsResponse productDetailResponse = 
            await InAppPurchase.instance.queryProductDetails({nativeProductID});
        
        if (productDetailResponse.notFoundIDs.isNotEmpty) {
             throw Exception("Product $nativeProductID not found in Store Connect");
        }

        final ProductDetails productDetails = productDetailResponse.productDetails.first;
        final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

        InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
        
        // Wait for Native Stream to finish and update DB
        return await _verifyTransaction(data['reference'], provider); 
      } 

      // 🟢 LOCAL AFRICAN RAILS (M-Pesa / Bank Transfers)
      else if (data['display_instruction'] != null && data['display_instruction'].toString().isNotEmpty) {
        final String instruction = data['display_instruction'];
        final String reference = data['reference'];

        // Show Native Dialog to the user
        showDialog(
          context: context,
          barrierDismissible: false, // Force them to wait
          builder: (ctx) => AlertDialog(
            title: const Text("Action Required", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.orange),
                const SizedBox(height: 16),
                Text(instruction, textAlign: TextAlign.center),
                // If it's Monnify, show virtual account here
                if (data['virtual_account'] != null) ...[
                  const SizedBox(height: 16),
                  Text(data['virtual_account']['bank_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(data['virtual_account']['account_number'], style: const TextStyle(fontSize: 20, letterSpacing: 2)),
                ]
              ],
            ),
          ),
        );

        // Start polling immediately while the prompt is on their phone
        final result = await _verifyTransaction(reference, provider);
        Navigator.of(context).pop(); // Close the dialog once polling breaks
        return result;
      }
      
      // STANDARD WEB CHECKOUT (Paystack / Flutterwave / Stripe)
      else if (data['authorization_url'] != null) {
        final String authUrl = data['authorization_url'];
        final String reference = data['reference'];

        await Navigator.of(context).push(MaterialPageRoute(builder: (ctx) {
          return _PaymentWebView(url: authUrl, reference: reference);
        }));

        return await _verifyTransaction(reference, provider);
      } 
      
      else {
        throw Exception("Invalid gateway response: No URL or Instruction provided.");
      }

    } catch (e) {
      if (e is DioException && e.response != null) {
        print("❌ SolydFlow Server Error: ${e.response?.data}");
      } else {
        print("❌ Purchase Error: $e");
      }
      rethrow;
    }
  }

  // --- NATIVE STORE LISTENER ---
  static Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // UI is usually locked here anyway
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          print("Native Purchase Error: ${purchaseDetails.error}");
        } else if (purchaseDetails.status == PurchaseStatus.purchased || 
                   purchaseDetails.status == PurchaseStatus.restored) {
          
          await _validateNativeReceipt(purchaseDetails);
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      }
    }
  }

  static Future<void> _validateNativeReceipt(PurchaseDetails purchase) async {
    String provider = Platform.isAndroid ? 'google' : 'apple';
    
    // FIND THE SOLYD PACKAGE ID
    String? solydPackageId = _nativeStoreToSolydMap[purchase.productID];
    if (solydPackageId == null) {
      print("❌ Validation Error: Could not map Native ID ${purchase.productID} to SolydFlow Package.");
      return;
    }

    try {
      final response = await _dio.post(
        '$_baseUrl/api/v1/pay/verify', 
        data: {
            "reference": purchase.verificationData.serverVerificationData, // Receipt or Token
            "user_id": _userID,
            "package_id": solydPackageId,
            "provider": provider 
        }, 
        options: Options(headers: {"X-API-Key": _apiKey}),
      );
      final status = response.data['status'];
      if (status == 'SETTLED_CONSENSUS') {
        print("✅ Native Receipt Validated!");
        await _fetchFromNetwork(); // Update Cache
      } else if (status == 'DISPUTED_MISMATCH') {
        print("⚠️ Native Receipt Disputed by Consensus Engine. Awaiting admin review.");
      }
    } catch (e) {
      print("Native Validation Failed: $e");
    }
  }

  // --- ENTITLEMENT CHECKS ---
  
  static Future<bool> hasEntitlement(String entitlementID) async {
    CustomerInfo info = await getCustomerInfo();
    return info.activeEntitlements[entitlementID] == true;
  }

  static Future<CustomerInfo> getCustomerInfo({bool forceRefresh = false}) async {
    if (_userID == null) throw Exception("User ID not set");
    if (_apiKey == null) throw Exception("API Key not set");

    CustomerInfo? cachedInfo;

    if (!forceRefresh) {
      cachedInfo = await SolydCache.load(_userID!);
    }

    if (cachedInfo != null) {
      _syncInBackground(); 
      return cachedInfo;
    }

    try {
      return await _fetchFromNetwork();
    } catch (e) {
      return CustomerInfo(
        userID: _userID!, 
        activeEntitlements: {}, 
        allEntitlements: {},
        activePackages: [],
      );
    }
  }

  static Future<CustomerInfo> _fetchFromNetwork() async {
    final response = await _dio.get(
      '$_baseUrl/api/v1/status', 
      queryParameters: {"user_id": _userID},
      options: Options(headers: {
        "X-API-Key": _apiKey,
        "Content-Type": "application/json",
      }),
    );
    
    final info = CustomerInfo.fromJson(response.data);
    await SolydCache.save(_userID!, info);
    return info;
  }

  static Future<void> _syncInBackground() async {
    try {
      if (await SolydCache.isStale(_userID!)) {
        await _fetchFromNetwork();
      }
    } catch (e) {}
  }

  static Future<CustomerInfo> _verifyTransaction(String reference, String provider) async {
    int attempts = 0;
    while (attempts < 10) {
      attempts++;
      try {
        final response = await _dio.post(
          '$_baseUrl/api/v1/pay/verify', 
          data: {
            "reference": reference,
            "provider": provider,
          },
          options: Options(headers: {"X-API-Key": _apiKey}),
        );
        final status = response.data['status'];

        // Use strict state machine enums
        if (status == 'SETTLED_CONSENSUS') {
          return await _fetchFromNetwork(); 
        } 
        else if (status == 'DISPUTED_MISMATCH') {
          print("⚠️ Transaction Disputed. Breaking poll loop early.");
          break; // Stop polling, it requires manual admin review
        }
        else if (status == 'PSP_FAILED' || status == 'FAILED_PERMANENT') {
          print("❌ Transaction Failed permanently. Breaking poll loop early.");
          break; // Stop polling, Churn Buster is handling it
        }
      } catch (e) {}
      await Future.delayed(const Duration(seconds: 2));
    }
    return await _fetchFromNetwork(); 
  }

  static Future<SolydPaywallConfig?> getPaywallConfig() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/v1/paywall',
        options: Options(headers: {"X-API-Key": _apiKey}),
      );
      var data = response.data;
      
      // ROBUSTNESS: If server sent a String instead of a Map, decode it manually
      if (data is String) {
        data = jsonDecode(data); // Requires import 'dart:convert';
      }
      
      return SolydPaywallConfig.fromJson(data);
    } catch (e) {
      print("Error fetching paywall config: $e");
      return null;
    }
  }
}

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