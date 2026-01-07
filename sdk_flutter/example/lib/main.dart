import 'package:flutter/material.dart';
import 'package:solydflow_flutter/solydflow_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize SolydFlow
  // Replace with your actual Project API Key from the Dashboard
  await SolydFlow.configure(
    apiKey: "sf_live_test123", 
    userID: "user_example_001" 
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        primaryColor: Colors.orange,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.orange).copyWith(secondary: Colors.orange),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  List<SolydPackage> _offerings = [];
  CustomerInfo? _customerInfo;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);

    // 2. Fetch User Status (Entitlements)
    // We get the full info object to see ALL active entitlements
    final info = await SolydFlow.getCustomerInfo();

    // 3. Fetch Available Products (Pricing)
    final packages = await SolydFlow.getOfferings();

    if (mounted) {
      setState(() {
        _customerInfo = info;
        _offerings = packages;
        _isLoading = false;
      });
    }
  }

  Future<void> _buyPackage(String identifier) async {
    setState(() => _isLoading = true);

    try {
      // 4. Trigger Purchase
      // This handles the native/web UI and returns the updated info if successful
      final updatedInfo = await SolydFlow.purchasePackage(context, identifier);

      if (updatedInfo != null) {
        setState(() {
          _customerInfo = updatedInfo;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Purchase Successful! Access Unlocked."), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SolydFlow Example'), 
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initData,
            tooltip: "Refresh Status",
          )
        ],
      ),
      body: _isLoading && _offerings.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // --- SECTION 1: STATUS ---
                  const Text("CURRENT ACCESS", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      border: Border.all(color: Colors.grey[800]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("User ID: ${_customerInfo?.userID ?? '...'}", style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 10),
                        
                        if (_customerInfo?.activeEntitlements.isEmpty ?? true)
                          const Row(
                            children: [
                              Icon(Icons.lock, color: Colors.red, size: 16),
                              SizedBox(width: 8),
                              Text("Free User (No Active Entitlements)", style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          )
                        else
                          Wrap(
                            spacing: 8,
                            children: _customerInfo!.activeEntitlements.keys.map((entitlement) {
                              // Only show active ones
                              if (_customerInfo!.activeEntitlements[entitlement] == true) {
                                return Chip(
                                  label: Text(entitlement.toUpperCase()),
                                  backgroundColor: Colors.green.withOpacity(0.2),
                                  labelStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  side: BorderSide.none,
                                  avatar: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                );
                              }
                              return const SizedBox();
                            }).toList(),
                          )
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- SECTION 2: PAYWALL ---
                  const Text("AVAILABLE PACKAGES", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  if (_offerings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("No packages configured in dashboard.", style: TextStyle(color: Colors.grey)),
                    ),

                  ..._offerings.map((pkg) {
                    // Check if we already own this package's entitlement
                    final bool isOwned = _customerInfo?.activeEntitlements[pkg.entitlementID] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161616),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOwned ? Colors.green.withOpacity(0.3) : Colors.grey[800]!
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        title: Text(pkg.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text("${pkg.currency} ${(pkg.amountKobo / 100).toStringAsFixed(2)} / ${pkg.duration}"),
                            Text(
                              "Unlocks: ${pkg.entitlementID}", 
                              style: TextStyle(fontSize: 10, color: Colors.orange[300])
                            ),
                          ],
                        ),
                        trailing: isOwned 
                          ? const Icon(Icons.check, color: Colors.green)
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: _isLoading ? null : () => _buyPackage(pkg.identifier),
                              child: const Text("Buy"),
                            ),
                      ),
                    );
                  }),

                ],
              ),
            ),
    );
  }
}
