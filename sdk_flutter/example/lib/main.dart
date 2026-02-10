import 'package:flutter/material.dart';
import 'package:solydflow_flutter/solydflow_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize SolydFlow
  // Replace with your actual Project API Key from the Dashboard
  try {
    await SolydFlow.configure(
      apiKey: "sf_pk_C9IWSZlyQaRSd9uiAiLzzWrLPcIZKbnM", // 🟢 REPLACE WITH YOUR KEY
      userID: "user_example_003" 
    );
  } catch(e) {
    print("Error occured during init: $e");
  }

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
  
  // 🟢 NEW: Track selected currency for preview
  String _selectedCurrency = 'NGN';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);

    // 2. Fetch User Status (Entitlements)
    final info = await SolydFlow.getCustomerInfo();

    // 3. Fetch Available Products (Pricing)
    final packages = await SolydFlow.getOfferings();

    if (mounted) {
      setState(() {
        _customerInfo = info;
        _offerings = packages;
        _isLoading = false;
        
        // Optional: Auto-switch if NGN is not found but others are
        if (!packages.any((p) => p.currency == 'NGN') && packages.isNotEmpty) {
          _selectedCurrency = packages.first.currency;
        }
      });
    }
  }

  Future<void> _buyPackage(String identifier) async {
    setState(() => _isLoading = true);

    try {
      // 4. Trigger Purchase
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
    // 🟢 EXTRACT UNIQUE CURRENCIES FOR FILTER
    final Set<String> currencies = _offerings.map((e) => e.currency).toSet();
    // Ensure default is there if list is empty or logic requires it
    if(currencies.isEmpty) currencies.add('NGN'); 

    // 🟢 FILTER LIST
    final visiblePackages = _offerings.where((p) => p.currency == _selectedCurrency).toList();

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

                  // --- SECTION 2: CURRENCY FILTER ---
                  const Text("STORE REGION", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: currencies.map((curr) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(curr),
                            selected: _selectedCurrency == curr,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedCurrency = curr);
                            },
                            selectedColor: Colors.orange,
                            labelStyle: TextStyle(
                              color: _selectedCurrency == curr ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold
                            ),
                            backgroundColor: const Color(0xFF161616),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- SECTION 3: PAYWALL ---
                  
                  if (visiblePackages.isEmpty)
                     Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Text("No packages available for $_selectedCurrency.", style: const TextStyle(color: Colors.grey)),
                    ),

                  ...visiblePackages.map((pkg) {
                    final bool isOwned = _customerInfo?.activeEntitlements[pkg.entitlementID] == true;
                    
                    final bool isUpgrade = pkg.isUpgrade;
                    final double originalPrice = pkg.amountKobo / 100;
                    final double finalPrice = pkg.calculatedAmountKobo / 100;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161616),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOwned 
                              ? Colors.green.withOpacity(0.5) 
                              : (isUpgrade ? Colors.orange.withOpacity(0.5) : Colors.grey[800]!)
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        
                        // TITLE & BADGE
                        title: Row(
                          children: [
                            Text(pkg.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            if (isUpgrade)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                                child: const Text("UPGRADE OFFER", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                              )
                          ],
                        ),

                        // PRICING LOGIC
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            
                            if (isUpgrade) ...[
                              // UPGRADE UI
                              Row(
                                children: [
                                  Text(
                                    "${pkg.currency} ${originalPrice.toStringAsFixed(2)}",
                                    style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${pkg.currency} ${finalPrice.toStringAsFixed(2)}",
                                    style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Text(
                                "Credit applied from current plan.",
                                style: const TextStyle(fontSize: 10, color: Colors.orange),
                              )
                            ] else ...[
                              // STANDARD UI
                              Text(
                                "${pkg.currency} ${originalPrice.toStringAsFixed(2)} / ${pkg.duration}",
                                style: const TextStyle(fontSize: 14, color: Colors.white70)
                              ),
                            ],

                            const SizedBox(height: 4),
                            Text(
                              "Unlocks: ${pkg.entitlementID} (Lvl ${pkg.tierLevel})", 
                              style: TextStyle(fontSize: 10, color: Colors.grey[600])
                            ),
                          ],
                        ),

                        // ACTION BUTTON
                        trailing: isOwned 
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isUpgrade ? Colors.orange : Colors.white,
                                foregroundColor: isUpgrade ? Colors.black : Colors.black,
                              ),
                              onPressed: _isLoading ? null : () => _buyPackage(pkg.identifier),
                              child: Text(isUpgrade ? "Upgrade" : "Buy"),
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