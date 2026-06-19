# SolydFlow Flutter SDK

<p align="center">
  <img src="https://www.solydflow.com/logo.png" alt="SolydFlow Logo" width="200"/>
  <br>
  <b>Hybrid Revenue Infrastructure for African Mobile Apps.</b>
  <br>
  <br>
  <a href="https://solydflow.com"><img src="https://img.shields.io/badge/Status-System%20Operational-green" alt="Status"></a>
</p>

---

## What is SolydFlow?

SolydFlow is a hybrid revenue infrastructure built for African mobile apps.

It unifies app stores (Apple App Store and Google Play), local African payment gateways (Paystack and Flutterwave), and Stripe for global coverage and portability into a single API.

Beyond payment aggregation, SolydFlow includes Smart Payment Routing, offline-first entitlement management, and transaction recovery designed for unstable network environments.

### The Problem

A customer completes a payment, but their network drops before your app receives confirmation.

Traditionally, this results in a failed purchase experience even though the payment was successful.

### The SolydFlow Solution

SolydFlow continuously reconciles transactions using webhooks, entitlement synchronization, and secure local caching.

Even if a customer closes the app immediately after payment, their access can be automatically restored when they return.

---

## Key Features

- 🌍 **Unified Revenue Infrastructure**: Manage app stores, local gateways, and global payment providers through a single integration.
- 🧠 **Smart Payment Routing**: Route transactions to the payment rail most likely to succeed based on currency and region.
- ⚡ **Offline-First Entitlements**: Customer access is securely cached for instant entitlement checks.
- 🔄 **Transaction Recovery**: Automatically recover interrupted purchases using webhook reconciliation.
- 💳 **Dynamic Pricing**: Manage products, pricing, and offers remotely from the SolydFlow Console.
- 🎯 **No-Code Paywalls**: Publish and update paywalls without releasing a new version of your app.
- 📊 **Subscription Analytics**: Track revenue, conversions, and customer activity from a single dashboard.

---

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  solydflow_flutter:
    git:
      url: https://github.com/solydflow/solydflow_flutter.git
      path: sdk_flutter
      ref: v0.4.0
```

### Platform Requirements

#### Android

SolydFlow requires Android API Level 21 or higher.

```kotlin
defaultConfig {
    minSdkVersion = 21
}
```

#### iOS

Enable the **In-App Purchase** capability in Xcode:

1. Open `ios/Runner.xcworkspace`
2. Navigate to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **In-App Purchase**

---

## Quick Start

### 1. Initialize the SDK

Initialize SolydFlow as early as possible in your application lifecycle.

```dart
import 'package:flutter/material.dart';
import 'package:solydflow_flutter/solydflow_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SolydFlow.configure(
    apiKey: "sf_pk_live_YOUR_PUBLIC_KEY",
    userID: "user_12345",
    userPhone: "2348012345678",
  );

  runApp(const MyApp());
}
```

> `userPhone` is recommended for local payment rails, churn recovery campaigns, subscription re-engagement workflows, and regional payment methods that require a phone number.

---

## Integration Options

SolydFlow supports two integration approaches.

### Option A: No-Code Paywall (Recommended)

Build and manage your paywall directly from the SolydFlow Console without releasing new app versions.

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (ctx) => SolydPaywall(
    onPurchaseSuccess: (CustomerInfo info) {
      Navigator.pop(ctx);
    },
  ),
);
```

### Option B: Custom UI

Fetch products dynamically and render your own Flutter widgets.

```dart
Future<void> loadProducts() async {
  List<SolydPackage> offerings =
      await SolydFlow.getOfferings();

  for (var pkg in offerings) {
    print(
      "${pkg.name} - ${pkg.currency} ${pkg.amountKobo / 100}"
    );
  }
}
```

---

## Fetching Products

Retrieve packages configured in your SolydFlow Console.

```dart
Future<void> loadProducts() async {
  List<SolydPackage> offerings =
      await SolydFlow.getOfferings();

  for (var pkg in offerings) {
    if (pkg.isUpgrade) {
      print(
        "Upgrade Price: ${pkg.currency} ${pkg.calculatedAmountKobo / 100}"
      );
    } else {
      print(
        "Base Price: ${pkg.currency} ${pkg.amountKobo / 100}"
      );
    }
  }
}
```

SolydFlow automatically applies:

- Purchasing Power Parity pricing
- Smart Upgrade Credits
- Regional pricing adjustments

---

## Making a Purchase

```dart
Future<void> buyPlan(
  BuildContext context,
  String packageID,
) async {
  try {
    final CustomerInfo? info =
        await SolydFlow.purchasePackage(
      context,
      packageID,
    );

    if (info == null) {
      return;
    }

    if (info.activeEntitlements["gold_access"] == true) {
      print("Purchase successful!");
    }
  } catch (e) {
    print("Purchase failed: $e");
  }
}
```

The SDK automatically handles:

- Payment initialization
- Payment verification
- Entitlement activation
- Customer synchronization
- Transaction recovery

---

## Checking Access

### Quick Access Check

Use this when you simply need to determine whether a user has access.

```dart
bool isGold =
    await SolydFlow.hasEntitlement(
      "gold_access",
    );
```

This check is offline-safe and uses encrypted local storage.

### Full Customer State

Retrieve detailed customer information including active entitlements and expiration dates.

```dart
CustomerInfo info =
    await SolydFlow.getCustomerInfo();
```

Example:

```dart
if (info.activeEntitlements["gold_access"] == true) {
  print("User is Gold");
}

DateTime? expiry =
    info.allEntitlements["gold_access"];

if (expiry != null) {
  print("Expires on: $expiry");
}
```

---

## Smart Payment Routing

SolydFlow can automatically route payments to the most appropriate payment provider based on currency, geography, and routing rules configured in the dashboard.

Examples:

| Currency | Payment Rail |
|-----------|--------------|
| NGN | Monnify |
| KES | M-Pesa |
| USD | Stripe |
| Other | Paystack / Flutterwave |

Supported routing rules can be configured from the SolydFlow Console without application updates.

---

## Payment Rails

| Provider | Status |
|-----------|---------|
| Paystack | ✅ Live |
| Flutterwave | ✅ Live |
| Apple App Store | 🧪 Testing |
| Google Play | 🧪 Testing |
| Stripe | 🧪 Testing |
| Monnify | 🚧 Planned |
| M-Pesa / Daraja | 🚧 Planned |

---

## Test Transaction Recovery

One of SolydFlow's core capabilities is transaction recovery.

### Zombie Transaction Test

1. Start a purchase on a physical device.
2. Complete the payment.
3. Force-close the app before returning to the success screen.
4. Wait a few seconds.
5. Re-open the application.
6. Check the customer's entitlement.

```dart
bool hasAccess =
    await SolydFlow.hasEntitlement(
      "gold_access",
    );
```

Expected result:

```text
true
```

This verifies:

- Webhook configuration
- Payment verification
- Entitlement synchronization
- Recovery engine functionality

---

## Platform Status

### Live

- Paystack
- Flutterwave
- Offline Entitlements
- Transaction Recovery
- No-Code Paywalls

### Testing

- Apple App Store
- Google Play
- Stripe

### Planned

- Monnify
- M-Pesa / Daraja
- Additional regional payment rails

---

## Security

### Non-Custodial

SolydFlow never holds your funds.

Payments move directly from the customer to your connected payment provider account.

### Encryption

Local customer data is encrypted before storage.

### Server-Side Verification

All transactions are verified before entitlements are activated.

---

## Documentation & Support

- Documentation: https://docs.solydflow.com/docs/intro
- Console: https://console.solydflow.com
- Website: https://solydflow.com
- Support: support@solydflow.com

---

<p align="center">
Built for African Developers.
<br>
<a href="https://solydflow.com">Get Started</a>
</p>