# 🚀 Getting Started with SolydFlow

Welcome to SolydFlow. This guide will help you integrate robust revenue infrastructure into your Flutter app in under 15 minutes. By the end of this guide, your app will be able to accept payments via Paystack/Flutterwave (Apple Pay, Google Pay and M-pesa coming soon), handle offline entitlements, and recover failed transactions automatically.

## Prerequisites

1.  **A SolydFlow Account:** [Sign up here](https://solydflow.com/register).
2.  **A Payment Gateway Account:** You need a live or test account with **Paystack** or **Flutterwave**.
3.  **A Flutter Project:** Existing or new (`flutter create my_app`).

---

## Part 1: Dashboard Configuration
*Before writing code, we need to tell SolydFlow what you are selling.*

1.  **Create a Project:**
    *   Log in to the [SolydFlow Console](https://solydflow.com/console).
    *   Click **"New Project"**. Name it (e.g., "NaijaFitness").
    *   **Copy your API Key** (`sf_live_...`). You will need this later.

2.  **Connect Your Gateway:**
    *   Click **"Connect Gateway"** on your project card.
    *   Select your provider (Paystack or Flutterwave).
    *   Enter your **Secret Key** (from your Paystack/Flutterwave dashboard).
    *   *Crucial:* Copy the **Webhook URL** provided by SolydFlow and paste it into your Payment Gateway's webhook settings.

3.  **Create a Product (Pricing):**
    *   Go to the **"Pricing & Products"** tab.
    *   Click **"Add Product"**.
    *   **Display Name:** e.g., "Pro Monthly".
    *   **Identifier:** e.g., `pro_monthly` (This is the ID you use in code).
    *   **Entitlement ID:** e.g., `premium_access` (This is the access level the user gets).
    *   **Price:** e.g., ₦1,000.

---

## Part 2: Installation

Add the SolydFlow SDK to your Flutter project.

Open your `pubspec.yaml` and add:


```yaml
dependencies:
  flutter:
    sdk: flutter
  # Add SolydFlow
  solydflow_flutter:
    git:
      url: https://github.com/solydflow/solydflow_flutter.git
      path: sdk_flutter
      ref: v0.2.0
```
*(Note: Once public, you will simply run `flutter pub add solydflow_flutter`)*

Run in your terminal:
```bash
flutter pub get
```

### Android Configuration
SolydFlow uses a secure WebView for payments. You must ensure your `minSdkVersion` is **21** or higher.

1.  Open `android/app/build.gradle` (or `build.gradle.kts`).
2.  Find `defaultConfig`.
3.  Update: `minSdkVersion 21`.

---

## Part 3: Initialization

Initialize the SDK as early as possible, ideally in your `main.dart`.

```dart
import 'package:flutter/material.dart';
import 'package:solydflow_flutter/solydflow_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Configure SolydFlow
  await SolydFlow.configure(
    apiKey: "sf_live_YOUR_API_KEY_HERE", 
    userID: "user_email_or_uuid" // ⚠️ IMPORTANT: See Best Practices below
  );

  runApp(const MyApp());
}
```

> **💡 Best Practice for User IDs:**
> Do not use hardcoded strings like "test_user". Use a unique ID from your authentication system (Firebase UID, Email, or a generated UUID). This ensures purchases are linked to the specific user.

---

## Part 4: Usage (The Golden Path)

The SolydFlow integration follows a simple 3-step pattern:
1.  **Check:** Does the user have access?
2.  **Show:** If not, show the Paywall.
3.  **Buy:** Process the purchase.

### 1. Checking Entitlements (Offline-Ready)
You can check if a user has access anywhere in your app. This checks the local encrypted cache first, making it instant and offline-safe.

```dart
Future<void> checkAccess() async {
  // Check for the "Entitlement ID" you set in the Dashboard (e.g., 'premium_access')
  bool isPremium = await SolydFlow.hasEntitlement("premium_access");

  if (isPremium) {
    // Navigate to Premium Content
    print("User is Premium! 💎");
  } else {
    // Show Paywall
    print("User is Free.");
  }
}
```

### 2. Displaying the Dynamic Paywall
Don't hardcode prices in your app. Fetch them from SolydFlow so you can change prices remotely.

```dart
import 'package:solydflow_flutter/solydflow_flutter.dart';

class PaywallScreen extends StatefulWidget { ... }

class _PaywallScreenState extends State<PaywallScreen> {
  List<SolydPackage> packages = [];

  @override
  void initState() {
    super.initState();
    loadOfferings();
  }

  Future<void> loadOfferings() async {
    // Fetches the products you created in the Dashboard
    final offerings = await SolydFlow.getOfferings();
    setState(() => packages = offerings);
  }

  @override
  Widget build(BuildContext context) {
    if (packages.isEmpty) return CircularProgressIndicator();

    return ListView.builder(
      itemCount: packages.length,
      itemBuilder: (context, index) {
        final pkg = packages[index];
        return ListTile(
          title: Text(pkg.name), // "Pro Monthly"
          subtitle: Text("${pkg.currency} ${pkg.amountKobo / 100}"), // "NGN 1000"
          trailing: ElevatedButton(
            onPressed: () => buyPlan(pkg.identifier),
            child: const Text("Buy"),
          ),
        );
      },
    );
  }
}
```

### 3. Making a Purchase
When the user clicks "Buy", SolydFlow handles the payment UI complexity for you.

```dart
Future<void> buyPlan(String packageID) async {
  try {
    // 1. Trigger Purchase Flow
    // This opens the secure WebView (Paystack/Flutterwave)
    // and handles the verification automatically.
    await SolydFlow.purchasePackage(context, packageID);

    // 2. Check Status Immediately
    if (await SolydFlow.hasEntitlement("premium_access")) {
      // Success! Close Paywall / Unlock Feature
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Welcome to Premium!"))
      );
    }
  } catch (e) {
    // SolydFlow handles network retries internally.
    // This catch is mostly for User Cancellation or Critical Errors.
    print("Purchase failed or cancelled: $e");
  }
}
```

---

## Part 5: Testing

### Using Test Cards
1.  In your SolydFlow Console, connect a **Test Key** (starts with `sk_test_`).
2.  When the payment view opens in the app, use a provider test card:
    *   **Paystack Test Card:** `4084 0840 8408 4081` (CVV: 408, Any future date).
    *   **Flutterwave Test Card:** Use their test card numbers or Bank Transfer simulation.

### The "Offline" Test (Zombie Transaction)
To verify SolydFlow's reliability:
1.  Start a purchase.
2.  Complete the payment on the webview.
3.  **Immediately kill the app** (swipe it away) before it returns to the success screen.
4.  Wait 15-30 seconds (for the webhook to fire).
5.  Re-open the app.
6.  The user should automatically have Premium access.

---

## Common Questions

**Q: Do I need to verify receipts on my own backend?**
**A:** No. SolydFlow acts as your backend. However, if you *want* to be notified on your server (e.g., to unlock a website account), you can set a **Webhook URL** in the Project Settings on the SolydFlow Console.

**Q: How do I handle Logout?**
**A:** When a user logs out of your app, simply re-configure SolydFlow with the new user's ID when they log back in.

```dart
// On Login
await SolydFlow.configure(apiKey: "...", userID: "new_user_id");
```

Need help? Contact support at [support@solydflow.com](mailto:support@solydflow.com).