# SolydFlow Flutter SDK

<p align="center">
  <img src="https://www.solydflow.com/logo.png" alt="SolydFlow Logo" width="200"/>
  <br>
  <b>The Revenue Infrastructure for African Mobile Apps.</b>
  <br>
  <br>
  <a href="https://solydflow.com"><img src="https://img.shields.io/badge/Status-Public%20Alpha-orange" alt="Status"></a>
  <!-- <a href="https://pub.dev/packages/solydflow_flutter"><img src="https://img.shields.io/badge/Platform-Flutter-blue" alt="Platform"></a> -->
  <!-- <a href="https://solydflow.com"><img src="https://img.shields.io/badge/License-MIT-green" alt="License"></a> -->
</p>

---

## What is SolydFlow?

SolydFlow is the revenue infrastructure for African mobile apps. It unifies Paystack, Flutterwave, Apple IAP, and Google Play into a single API that handles **offline entitlements** and **transaction recovery**.
Our current implementation are Paystack and Flutterwave, while others are in progress...

**The Problem:**
If a user pays via USSD and their network drops before returning to your app, the transaction is usually lost ("Zombie Transaction").
**The SolydFlow Solution:**
We perform background webhook recovery, ensuring that even if the user's phone dies immediately after payment, their entitlements are unlocked when they return.

## Key Features

- 🌍 **Multi-Gateway Support:** Switch between Paystack and Flutterwave instantly from the dashboard. No code changes required.
- ⚡ **Offline-First Entitlements:** User status entitlement is cached and encrypted locally.
- 🏷️ **Dynamic Pricing:** Change prices, currency, and duration remotely without updating your app.
- 🔄 **Smart Recovery:** Automated polling and webhook reconciliation for unstable networks.
- 📊 **Analytics:** Track revenue and active subscribers out of the box.

---

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # For Alpha Access:
  solydflow_flutter:
    git:
      url: https://github.com/solydflow/solydflow_flutter.git
      path: sdk_flutter
      ref: v0.3.0
```

## Quick Start

### 1. Initialization

Initialize the SDK in your `main.dart` using the API Key from your [SolydFlow Console](https://console.solydflow.com/).

```dart
import 'package:solydflow_flutter/solydflow_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SolydFlow.configure(
    apiKey: "sf_live_YOUR_API_KEY", 
    userID: "user_12345" // Your App's User ID (Email, UUID, etc.)
  );
  
  runApp(MyApp());
}
```

### 2. Fetching Dynamic Paywalls

Stop hardcoding prices. Fetch products configured in your Dashboard. This allows you to A/B test prices or switch currencies (NGN/USD) on the fly.

```dart
Future<void> showPaywall() async {
  // Returns a list of configured packages (e.g., Monthly, Yearly)
  List<SolydPackage> offerings = await SolydFlow.getOfferings();
  
  if (offerings.isEmpty) {
    print("No products configured in dashboard");
    return;
  }

  // Display them in your UI
  for (var package in offerings) {
    print("Plan: ${package.name} - Price: ₦${package.amountKobo / 100}");
  }
}
```

### 3. Making a Purchase

Pass the `context` (for the secure payment view) and the `identifier` of the package.

```dart
Future<void> buyPlan(BuildContext context, String packageID) async {
  try {
    // 1. Trigger Purchase (Opens WebView)
    final CustomerInfo? info = await SolydFlow.purchasePackage(context, packageID);

    if (info == null) return;

    // 2. Check Status Immediately
    if (await SolydFlow.hasEntitlement("gold_access")) {
      Navigator.pop(context); // Close Paywall
      print("Welcome to the Gold Club!");
    }
  } catch (e) {
    print("Purchase failed: $e");
  }
}
```

### 4. Checking Access (The Gatekeeper/Offline Supported)
You can check if a user has access anywhere in your app. This checks the local encrypted cache first, making it **instant and offline-safe**.

```dart
Future<void> checkAccess() async {
  // Check for the "Entitlement ID" you set in Dashboard Step 3
  if (await SolydFlow.hasEntitlement("gold_access")) {
    print("User is Gold! 💎");
    // Navigate to Premium Content
  } else {
    print("User is Free.");
    // Show Paywall
  }
}
```

---

## Supported Gateways

Currently configured via the SolydFlow Console:

| Provider | Status | Regions |
| :--- | :--- | :--- |
| **Paystack** | ✅ Live | Nigeria, Ghana, Kenya, South Africa |
| **Flutterwave** | ✅ Live | Pan-African / Global |

---

## Roadmap & Future Releases

We are building the complete financial stack for African apps.

- [x] **Phase 1: African Rails** (Completed)
    - Paystack & Flutterwave Integration.
    - Webhook Recovery Engine.
    - Dynamic Pricing Dashboard.
- [ ] **Phase 2: Native Stores** (In Progress)
    - **Apple IAP (StoreKit 2):** Validate App Store receipts alongside local payments.
    - **Google Play Billing:** Unified subscription management for Android.
- [ ] **Phase 3: Global Expansion**
    - **Stripe:** For accepting USD/EUR payments globally.
    - **PayPal:** For broader international reach.
    - **Crypto (Stablecoins):** USDC acceptance for borderless payments.

---

## Security

SolydFlow is compliant with industry standards.
- **Non-Custodial:** We do not hold your funds. Money goes directly from the user to your Paystack/Flutterwave account.
- **Encryption:** All local data is encrypted using AES-256.
- **Verification:** All transactions are verified server-side via signatures.

---

<p align="center">
  Built with love for African Developers.
  <br>
  <a href="https://solydflow.com">Get Early Access</a>
</p>
