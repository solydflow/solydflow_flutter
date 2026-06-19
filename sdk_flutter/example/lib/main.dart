import 'dart:async';
import 'package:flutter/material.dart';
import 'package:solydflow_flutter/solydflow_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize SolydFlow
  // Replace with your actual Project API Key from the Dashboard
  try {
    await SolydFlow.configure(
      apiKey: "sf_pk_test_aMrVMELgmmDsVbPWz7u83GDinatJJRfB", // REPLACE WITH YOUR KEY
      userID: "user_example_003" 
    );
  } catch(e) {
    print("SolydFlow Initialization failed: $e");
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
      home: const PlaygroundMenu(), // Launch Menu
    );
  }
}

// --- THE MULTI-INTEGRATION PLAYGROUND MENU (Zero Dependency) ---
class PlaygroundMenu extends StatelessWidget {
  const PlaygroundMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SolydFlow Playground"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.bolt, color: Colors.orange, size: 60),
            const SizedBox(height: 20),
            const Text(
              "Choose Your Integration Style",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center, // FIXED THE TYPO HERE
            ),
            const SizedBox(height: 10),
            const Text(
              "Compare our two integration flows to see which fits your business model.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // OPTION A: MANUAL NATIVE UI
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[800]!))
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomPaywallScreen()));
              },
              icon: const Icon(Icons.code, color: Colors.blue),
              label: const Text("Option A: Custom Native UI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),

            const SizedBox(height: 16),

            // OPTION B: NO-CODE REMOTE UI
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              onPressed: () {
                // 🚀 LAUNCH THE NO-CODE OVERLAY WIDGET (Built-in)
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (ctx) => SolydPaywall(
                    onPurchaseSuccess: (info) {
                      _toast(context, "Subscription Unlocked Live! 💎");
                      Navigator.pop(ctx);
                    },
                    onClose: () => Navigator.pop(ctx),
                  ),
                );
              },
              icon: const Icon(Icons.phonelink_setup, color: Colors.black),
              label: const Text("Option B: No-Code Remote UI", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }
}

// =========================================================================
// --- OPTION A: THE CUSTOM PAYWALL SCREEN (Dynamic & Data-Driven) ---
// =========================================================================
class CustomPaywallScreen extends StatefulWidget {
  const CustomPaywallScreen({super.key});

  @override
  State<CustomPaywallScreen> createState() => _CustomPaywallScreenState();
}

class _CustomPaywallScreenState extends State<CustomPaywallScreen> {
  List<SolydPackage> _packages = [];
  CustomerInfo? _customerInfo;
  bool _isLoading = true;
  
  String? _selectedPackageId; 
  int _highestOwnedTier = 0; 
  
  // NEW: Track active duration tab
  String _selectedDuration = 'month'; 

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await SolydFlow.getOfferings();
      final info = await SolydFlow.getCustomerInfo();
      
      // Sort from Lowest Tier (1) to Highest Tier (e.g., 3)
      offerings.sort((a, b) => a.tierLevel.compareTo(b.tierLevel));

      int maxTier = 0;
      for (var pkg in offerings) {
        if (info.activeEntitlements[pkg.entitlementID] == true) {
          if (pkg.tierLevel > maxTier) maxTier = pkg.tierLevel;
        }
      }

      if (mounted) {
        setState(() {
          _packages = offerings;
          _customerInfo = info;
          _highestOwnedTier = maxTier;
          
          // Auto-select duration based on what's available
          if (offerings.isNotEmpty) {
            _selectedDuration = offerings.first.duration;
            _autoSelectFirstValidPackage(_selectedDuration);
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // HELPER: Auto-selects a package when switching tabs
  void _autoSelectFirstValidPackage(String duration) {
    final filtered = _packages.where((p) => p.duration == duration).toList();
    if (filtered.isEmpty) return;

    try {
      // Try to select the first upgrade available
      _selectedPackageId = filtered.firstWhere((p) => p.tierLevel > _highestOwnedTier).identifier;
    } catch (_) {
      // Fallback: Just select the last one in the list
      _selectedPackageId = filtered.last.identifier;
    }
  }

  String _formatPrice(double amount, String currency) {
    final symbol = currency == 'NGN' ? '₦' : (currency == 'USD' ? '\$' : currency);
    return "$symbol${amount.toStringAsFixed(0)}";
  }

  String _getDurationLabel(String dur) {
    switch (dur) {
      case 'month': return 'Monthly';
      case 'year': return 'Yearly';
      case 'week': return 'Weekly';
      case 'lifetime': return 'One-Time';
      default: return dur;
    }
  }

  Future<void> _purchase(SolydPackage package) async {
    setState(() => _isLoading = true);
    try {
      final info = await SolydFlow.purchasePackage(context, package.identifier);
      if (info != null) {
        final bool isActive = info.activeEntitlements[package.entitlementID] == true;
        if (isActive) {
          if (mounted) {
            setState(() {
               _customerInfo = info;
               if (package.tierLevel > _highestOwnedTier) {
                 _highestOwnedTier = package.tierLevel;
               }
            });
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Purchase Successful!"), backgroundColor: Colors.green));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get unique durations and sort them logically
    final Set<String> durationsSet = _packages.map((e) => e.duration).toSet();
    final List<String> availableDurations = durationsSet.toList()..sort((a, b) {
      const order = {'week': 1, 'month': 2, 'year': 3, 'lifetime': 4};
      return (order[a] ?? 99).compareTo(order[b] ?? 99);
    });

    // 2. Ensure current duration is valid
    final activeDuration = availableDurations.contains(_selectedDuration) 
        ? _selectedDuration 
        : (availableDurations.isNotEmpty ? availableDurations.first : 'month');

    // 3. Filter packages for the active tab
    final displayPackages = _packages.where((p) => p.duration == activeDuration).toList();

    // 4. Find the currently selected package for the button
    SolydPackage? selectedPackage;
    try {
      selectedPackage = _packages.firstWhere((p) => p.identifier == _selectedPackageId);
    } catch (_) {}

    final bool isCurrentPlanSelected = selectedPackage != null && selectedPackage.tierLevel == _highestOwnedTier;

    return Scaffold(
      appBar: AppBar(title: const Text("Custom Paywall")),
      body: Column(
        children: [
          if (_isLoading && _packages.isEmpty) const LinearProgressIndicator(),
          
          // THE DURATION TOGGLE UI
          if (availableDurations.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10)
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: availableDurations.map((dur) {
                    final isSelected = activeDuration == dur;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDuration = dur;
                          _autoSelectFirstValidPackage(dur); // Switch selection safely
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.orange : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getDurationLabel(dur),
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: displayPackages.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final pkg = displayPackages[index];
                return _buildDynamicCard(pkg);
              },
            ),
          ),
          
          // Action Button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrentPlanSelected ? Colors.grey[800] : Colors.orange,
                  foregroundColor: isCurrentPlanSelected ? Colors.white54 : Colors.black,
                ),
                onPressed: (_isLoading || displayPackages.isEmpty || isCurrentPlanSelected || selectedPackage == null) 
                  ? null 
                  : () => _purchase(selectedPackage!),
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : Text(isCurrentPlanSelected ? "Active Plan" : (selectedPackage?.isUpgrade == true ? "Upgrade Now" : "Subscribe")),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDynamicCard(SolydPackage pkg) {
    final bool isSelected = _selectedPackageId == pkg.identifier;
    final bool isCurrent = _highestOwnedTier == pkg.tierLevel;
    final bool isLower = _highestOwnedTier > pkg.tierLevel;
    final bool isLocked = isCurrent || isLower;

    final String basePrice = _formatPrice(pkg.amountKobo / 100, pkg.currency);
    final String discountPrice = _formatPrice(pkg.calculatedAmountKobo / 100, pkg.currency);

    return GestureDetector(
      onTap: isLocked ? null : () => setState(() => _selectedPackageId = pkg.identifier),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isLower ? Colors.black45 : (isCurrent ? Colors.green.withOpacity(0.05) : const Color(0xFF111111)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCurrent ? Colors.green : (isSelected ? Colors.orange : Colors.grey[800]!), 
            width: isSelected ? 3 : 1
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(pkg.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isLower ? Colors.grey[700] : Colors.white)),
                if (isCurrent) const Icon(Icons.check_circle, color: Colors.green)
              ],
            ),
            
            Text("Tier ${pkg.tierLevel}", style: TextStyle(fontSize: 12, color: isLower ? Colors.grey[800] : Colors.grey)),
            
            const SizedBox(height: 20),
            
            // Proration (Smart Credit) UI Logic
            if (pkg.isUpgrade && !isCurrent && !isLower) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(basePrice, style: const TextStyle(fontSize: 16, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                  const SizedBox(width: 8),
                  Text(discountPrice, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.green)),
                ],
              ),
              const Text("Credit applied from active plan", style: TextStyle(color: Colors.orange, fontSize: 10)),
            ] else ...[
              Text(basePrice, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isLower ? Colors.grey[700] : Colors.white)),
            ]
          ],
        ),
      ),
    );
  }
}
