import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'models/package.dart';
import 'models/customer_info.dart';
import 'utils/telemetry.dart';
import 'cache_manager.dart';

class SolydFlow {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  static String? _apiKey;
  static String? _userID;
  static const String _baseUrl = "https://api.solydflow.com";

  static StreamSubscription<List<PurchaseDetails>>? _iapSubscription;
  
  // 🟢 HELPER MAP: Apple/Google ID -> SolydFlow Identifier
  // Needed to tell the backend what SolydFlow package was bought via Native Stores
  static final Map<String, String> _nativeStoreToSolydMap = {};

  // --- CONFIGURATION ---
  static Future<void> configure({
    required String apiKey,
    required String userID
  }) async {
    _apiKey = apiKey;
    _userID = userID;

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

  // --- FETCH PRODUCTS ---
  static Future<List<SolydPackage>> getOfferings() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/v1/offerings',
        queryParameters: {"user_id": _userID},
        options: Options(headers: {"X-API-Key": _apiKey}),
      );
      List<dynamic> data = response.data['offerings'];
      
      final packages = data.map((json) => SolydPackage.fromJson(json)).toList();
      
      // 🟢 Build the memory map for Native Store validation
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
    String packageIdentifier
  ) async {
    if (_userID == null) throw Exception("SolydFlow not configured");

    try {
      String idempotencyKey = const Uuid().v4();
      final telemetryData = await SolydTelemetry.collect();
      
      final Map<String, dynamic> payload = {
          "user_id": _userID ?? "",
          "package_identifier": packageIdentifier,
          "email": "$_userID@solydflow.app",
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

      // 🟢 NATIVE STORE (APPLE / GOOGLE)
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
        return await _verifyTransaction(data['reference']); 
      } 
      
      // 🟢 WEB PAYMENT (Paystack / Flutterwave)
      else {
        final String authUrl = data['authorization_url'];
        final String reference = data['reference'];

        await Navigator.of(context).push(MaterialPageRoute(builder: (ctx) {
          return _PaymentWebView(url: authUrl, reference: reference);
        }));

        return await _verifyTransaction(reference);
      }

    } catch (e) {
      if (e is DioException) {
        if (e.response != null) {
          print("❌ SolydFlow Server Error: ${e.response?.data}");
        }
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
    
    // 🟢 FIND THE SOLYD PACKAGE ID
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

      if (response.data['status'] == 'success') {
        print("✅ Native Receipt Validated!");
        await _fetchFromNetwork(); // Update Cache
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
      return CustomerInfo(userID: _userID!, activeEntitlements: {}, allEntitlements: {});
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

  static Future<CustomerInfo> _verifyTransaction(String reference) async {
    int attempts = 0;
    while (attempts < 10) {
      attempts++;
      try {
        final response = await _dio.get(
          '$_baseUrl/api/v1/pay/verify', 
          queryParameters: {"reference": reference},
          options: Options(headers: {"X-API-Key": _apiKey}),
        );
        if (response.data['status'] == 'success') {
          return await _fetchFromNetwork(); 
        }
      } catch (e) {}
      await Future.delayed(const Duration(seconds: 2));
    }
    return await _fetchFromNetwork(); 
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