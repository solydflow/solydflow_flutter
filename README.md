Here is the updated **Public README.md**.

It reflects the actual state of the project (Dynamic Pricing, Multi-Gateway, Offline Support) and clearly outlines the roadmap as requested.

***

```markdown
# SolydFlow Flutter SDK

<p align="center">
  <img src="https://via.placeholder.com/150x50?text=SolydFlow" alt="SolydFlow Logo" width="200"/>
  <br>
  <b>The Revenue Infrastructure for African Mobile Apps.</b>
  <br>
  <br>
  <a href="https://solydflow.com"><img src="https://img.shields.io/badge/Status-Public%20Alpha-orange" alt="Status"></a>
  <a href="https://pub.dev/packages/solydflow_flutter"><img src="https://img.shields.io/badge/Platform-Flutter-blue" alt="Platform"></a>
  <a href="https://solydflow.com"><img src="https://img.shields.io/badge/License-MIT-green" alt="License"></a>
</p>

---

## What is SolydFlow?

SolydFlow is a hybrid revenue SDK designed to solve the fragmentation of mobile payments in Africa. It allows you to accept local payments (Mobile Money, USSD, Bank Transfer) and manage subscriptions without building your own backend.

**The Problem:**
If a user pays via USSD and their network drops before returning to your app, the transaction is usually lost ("Zombie Transaction").
**The SolydFlow Solution:**
We perform background webhook recovery, ensuring that even if the user's phone dies immediately after payment, their entitlements are unlocked when they return.

## Key Features

- 🌍 **Multi-Gateway Support:** Switch between Paystack and Flutterwave instantly from the dashboard. No code changes required.
- ⚡ **Offline-First Entitlements:** User status (`isPro`) is cached and encrypted locally.
- 🏷️ **Dynamic Pricing:** Change prices, currency, and duration remotely without updating your app.
- 🔄 **Smart Recovery:** Automated polling and webhook reconciliation for unstable networks.
- 📊 **Analytics:** Track revenue and active subscribers out of the box.

---

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  solydflow_flutter: ^0.1.0
```

## Quick Start

### 1. Initialization

Initialize the SDK in your `main.dart` using the API Key from your [SolydFlow Console](https://solydflow.com/console).

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
    // SolydFlow handles the payment UI (Paystack/Flutterwave)
    // and verifies the transaction automatically.
    await SolydFlow.purchasePackage(context, packageID);
    
    // Check status immediately after
    bool isPro = await SolydFlow.getIsPro();
    if (isPro) {
      print("Success! User is now Pro.");
    }
  } catch (e) {
    print("Purchase failed: $e");
  }
}
```

### 4. Checking Status (Offline Supported)

This check is instant and synchronous after the first load.

```dart
void checkStatus() async {
  // Checks local encrypted cache
  bool isPro = await SolydFlow.getIsPro();
  
  if (isPro) {
    // Grant access to Pro features
  } else {
    // Lock features
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
```