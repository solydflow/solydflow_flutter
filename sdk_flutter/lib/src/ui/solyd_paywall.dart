import 'dart:io';
import 'package:flutter/material.dart';
import '../solydflow.dart';
import '../models/package.dart';
import '../models/paywall_config.dart';
import '../models/customer_info.dart';

class SolydPaywall extends StatefulWidget {
  final Function(CustomerInfo) onPurchaseSuccess;
  final VoidCallback? onClose;

  const SolydPaywall({Key? key, required this.onPurchaseSuccess, this.onClose}) : super(key: key);

  @override
  State<SolydPaywall> createState() => _SolydPaywallState();
}

class _SolydPaywallState extends State<SolydPaywall> {
  bool _isLoading = true;
  SolydPaywallConfig? _config;
  List<SolydPackage> _packages = [];
  CustomerInfo? _customerInfo;
  String _selectedCurrency = 'NGN'; 
  String _selectedDuration = 'month'; 

  final Map<String, TextEditingController> _donationControllers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      SolydFlow.getPaywallConfig(),
      SolydFlow.getOfferings(silent: false),
      SolydFlow.getCustomerInfo(forceRefresh: false),
    ]);

    final config = results[0] as SolydPaywallConfig?;
    final packages = results[1] as List<SolydPackage>;
    final customerInfo = results[2] as CustomerInfo?;

    String detectedCurrency = 'NGN'; 
    final Set<String> availableCurrencies = packages.map((e) => e.currency).toSet();
    
    if (availableCurrencies.isNotEmpty) {
      if (availableCurrencies.contains('NGN')) {
        detectedCurrency = 'NGN';
      } else {
        detectedCurrency = availableCurrencies.first;
      }
    }

    if (mounted) {
      setState(() {
        _config = config;
        _packages = packages;
        _customerInfo = customerInfo;
        _selectedCurrency = detectedCurrency;
        _isLoading = false;
      });
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.parse("0x$hex"));
  }

  String _getSymbol(String currency) {
    switch (currency) {
      case 'NGN': return '₦';
      case 'USD': return '\$';
      case 'GHS': return '₵';
      case 'KES': return 'KSh';
      case 'ZAR': return 'R';
      case 'EUR': return '€';
      case 'GBP': return '£';
      default: return currency;
    }
  }

  String _getDurationLabel(String dur) {
    switch (dur) {
      case 'month': return 'Monthly';
      case 'year': return 'Yearly';
      case 'week': return 'Weekly';
      case 'lifetime': return 'Lifetime';
      default: return dur;
    }
  }

  // HIERARCHY ENGINE: Defines duration value to suppress downgrades
  int _getDurationValue(String dur) {
    switch (dur) {
      case 'week': return 1;
      case 'month': return 2;
      case 'year': return 3;
      case 'lifetime': return 4;
      default: return 0;
    }
  }

  // SAVINGS ENGINE: Auto-calculates "Save 20%" for annual plans
  int _calculateSavings(SolydPackage pkg, List<SolydPackage> currencyPackages) {
    if (pkg.duration != 'year') return 0;
    
    // Find the monthly equivalent of this exact tier
    final monthlyPkg = currencyPackages.where((p) => p.tierLevel == pkg.tierLevel && p.duration == 'month').firstOrNull;
    if (monthlyPkg == null) return 0;

    final int annualCostOfMonthly = monthlyPkg.amountKobo * 12;
    if (annualCostOfMonthly > pkg.amountKobo) {
      return ((annualCostOfMonthly - pkg.amountKobo) / annualCostOfMonthly * 100).round();
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black, 
        body: Center(child: CircularProgressIndicator(color: Colors.orange))
      );
    }
    if (_config == null) return const SizedBox();

    final bgColor = _hexToColor(_config!.backgroundColor);
    final accentColor = _hexToColor(_config!.primaryColor);
    final isDark = bgColor.computeLuminance() < 0.5;
    final textColor = isDark ? Colors.white : Colors.black;

    final Set<String> currencies = _packages.map((e) => e.currency).toSet();
    final currencyPackages = _packages.where((p) => p.currency == _selectedCurrency).toList();
    final Set<String> durations = currencyPackages.map((e) => e.duration).toSet();
    
    final activeDuration = durations.contains(_selectedDuration)
        ? _selectedDuration
        : (durations.isNotEmpty ? durations.first : 'month');

    final displayPackages = currencyPackages
        .where((p) => p.duration == activeDuration)
        .toList()
      ..sort((a, b) => a.amountKobo - b.amountKobo);

    // TEMPLATE PARITY ENGINE
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background Layer (For Image Hero Template)
          if (_config!.templateName == 'image_hero' && _config!.headerImageUrl.isNotEmpty)
            Positioned(
              top: 0, left: 0, right: 0, height: MediaQuery.of(context).size.height * 0.45,
              child: ShaderMask(
                shaderCallback: (rect) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black, bgColor.withOpacity(0.0)],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: Image.network(_config!.headerImageUrl, fit: BoxFit.cover),
              ),
            ),

          // Main Content Layer
          SafeArea(
            child: Column(
              crossAxisAlignment: _config!.templateName == 'dark_minimal' ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                // Header Image (For Default Template)
                if (_config!.templateName == 'default' && _config!.headerImageUrl.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 20),
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: DecorationImage(image: NetworkImage(_config!.headerImageUrl), fit: BoxFit.cover),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))]
                    ),
                  )
                else if (_config!.templateName == 'image_hero')
                  const SizedBox(height: 140) // Push content down for the hero image
                else
                  const SizedBox(height: 40), // Minimal padding

                // Content Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: _config!.templateName == 'dark_minimal' ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                      children: [
                        // Headline & Subheading
                        Text(
                          _config!.headline, 
                          textAlign: _config!.templateName == 'dark_minimal' ? TextAlign.center : TextAlign.left,
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: textColor, height: 1.1)
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _config!.subheading, 
                          textAlign: _config!.templateName == 'dark_minimal' ? TextAlign.center : TextAlign.left,
                          style: TextStyle(fontSize: 15, color: textColor.withOpacity(0.7), fontWeight: FontWeight.w500)
                        ),
                        
                        const SizedBox(height: 24),

                        // --- CURRENCY PICKER ---
                        if (currencies.length > 1) ...[
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: _config!.templateName == 'dark_minimal' ? MainAxisAlignment.center : MainAxisAlignment.start,
                              children: currencies.map((curr) {
                                final isSelected = _selectedCurrency == curr;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ChoiceChip(
                                    label: Text(curr),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      if (selected) setState(() => _selectedCurrency = curr);
                                    },
                                    selectedColor: accentColor,
                                    labelStyle: TextStyle(
                                      color: isSelected ? (accentColor.computeLuminance() > 0.5 ? Colors.black : Colors.white) : textColor.withOpacity(0.6),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12
                                    ),
                                    backgroundColor: textColor.withOpacity(0.05),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    side: BorderSide.none,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // --- DURATION SELECTOR (Tabs) ---
                        if (durations.length > 1) ...[
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: textColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: durations.map((dur) {
                                final isSelected = activeDuration == dur;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedDuration = dur),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected ? accentColor : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: isSelected ? [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                                      ),
                                      child: Center(
                                        child: Text(
                                          _getDurationLabel(dur).toUpperCase(),
                                          style: TextStyle(
                                            color: isSelected ? (accentColor.computeLuminance() > 0.5 ? Colors.black : Colors.white) : textColor.withOpacity(0.6),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                            letterSpacing: 1.0
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // --- FILTERED PRODUCTS LIST ---
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.only(bottom: 20),
                            children: [
                              if (displayPackages.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                                  child: Center(
                                    child: Text("No plans available for $_selectedCurrency", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 14))
                                  ),
                                ),

                              ...displayPackages.map((pkg) => _buildPackageCard(pkg, textColor, accentColor, isDark, currencyPackages)),
                            ],
                          ),
                        ),

                        // --- TRUST FOOTER ---
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Column(
                            children: [
                              Text(
                                _config!.footerText, 
                                style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.5), fontWeight: FontWeight.w500), 
                                textAlign: TextAlign.center
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_outline, size: 12, color: textColor.withOpacity(0.3)),
                                  const SizedBox(width: 4),
                                  Text("Secured by SolydFlow", style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.3), fontWeight: FontWeight.bold)),
                                ],
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Close Button (Top Right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10, 
            right: 16, 
            child: GestureDetector(
              onTap: widget.onClose ?? () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: textColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.close, color: textColor, size: 20),
              ),
            )
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(
    SolydPackage pkg, 
    Color textColor, 
    Color accentColor,
    bool isDark,
    List<SolydPackage> allCurrencyPackages
  ) {
    // We map tier features locally, if the API didn't send them, default to empty
    // NOTE: This assumes your PaywallConfig response includes `tiers` data which maps to feature strings.
    // If it doesn't, it will just cleanly skip rendering features.
    final List<dynamic> featuresRaw = (_config as dynamic).tierFeatures?[pkg.entitlementID] ?? [];
    final List<String> features = featuresRaw.map((e) => e.toString()).toList();
    
    // Ownership checks
    // 1. GENERAL ENTITLEMENT: Do they have access to this tier? (e.g. pro_access)
    final bool hasEntitlement = _customerInfo?.activeEntitlements[pkg.entitlementID] == true;
    
    final bool isUpgrade = pkg.isUpgrade;

    // 2. EXACT OWNERSHIP (SMART INFERENCE): 
    // If they have the entitlement, and this package is NOT an upgrade, it is their current (or lower) plan.
    final bool isOwned = (_customerInfo?.activePackages.contains(pkg.identifier) == true) || 
                         (hasEntitlement && !isUpgrade);

    SolydPackage? currentOwnedPkg;
    if (hasEntitlement && !isOwned && _customerInfo != null) {
      try {
        currentOwnedPkg = _packages.firstWhere(
          (p) => _customerInfo!.activePackages.contains(p.identifier) && p.entitlementID == pkg.entitlementID
        );
      } catch (_) {} 
    }

    // REVENUE MAXIMIZATION: Intelligent Downgrade Suppression
    bool isDowngrade = false;
    if (hasEntitlement && !isOwned && currentOwnedPkg != null) {
      if (pkg.tierLevel == currentOwnedPkg.tierLevel) {
        if (_getDurationValue(pkg.duration) < _getDurationValue(currentOwnedPkg.duration)) {
          isDowngrade = true; // They own Yearly, but are looking at Monthly
        }
      }
    }

    // REVENUE MAXIMIZATION: Auto-Calculating Savings
    final int savingsPercent = _calculateSavings(pkg, allCurrencyPackages);

    // REVENUE MAXIMIZATION: Smart Credit Amount
    double creditAmount = 0;
    if (isUpgrade && pkg.amountKobo > pkg.calculatedAmountKobo) {
      creditAmount = (pkg.amountKobo - pkg.calculatedAmountKobo) / 100;
    }

    // Badge & Color Logic
    String? badgeText;
    Color badgeBg = Colors.transparent;
    Color badgeTextCol = Colors.transparent;

    if (isOwned) {
      badgeText = "CURRENT PLAN";
      badgeBg = Colors.green.withOpacity(0.15);
      badgeTextCol = Colors.green;
    } else if (isDowngrade) {
      // Suppress UI completely
      badgeText = null;
    } else if (isUpgrade) {
      badgeText = "UPGRADE OFFER";
      badgeBg = accentColor;
      badgeTextCol = isDark ? Colors.black : Colors.white;
    } else if (savingsPercent > 0) {
      badgeText = "SAVE $savingsPercent%";
      badgeBg = Colors.redAccent;
      badgeTextCol = Colors.white;
    } else if (currentOwnedPkg != null && pkg.duration != currentOwnedPkg.duration && pkg.tierLevel == currentOwnedPkg.tierLevel) {
      badgeText = "SWITCH TO ${pkg.duration.toUpperCase()}LY";
      badgeBg = textColor.withOpacity(0.1);
      badgeTextCol = textColor.withOpacity(0.8);
    }

    final double originalPrice = pkg.amountKobo / 100;
    final double finalPrice = pkg.calculatedAmountKobo / 100;

    if (pkg.isVariablePrice && !_donationControllers.containsKey(pkg.identifier)) {
      _donationControllers[pkg.identifier] = TextEditingController(text: finalPrice.toStringAsFixed(0));
    }

    Future<void> executePurchase({int? customAmountKobo}) async {
      if (isOwned) return; 
      setState(() => _isLoading = true);
      try {
        final info = await SolydFlow.purchasePackage(context, pkg.identifier, customAmountKobo: customAmountKobo);
        if (info != null && info.activeEntitlements[pkg.entitlementID] == true) {
            widget.onPurchaseSuccess(info);
        }
      } catch(e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.orange));
      } finally {
        if(mounted) setState(() => _isLoading = false);
      }
    }

    Widget cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(
          width: (isOwned || isUpgrade) ? 2 : 1, 
          // Suppress border entirely if it's a downgrade
          color: isDowngrade 
            ? textColor.withOpacity(0.05) 
            : (isOwned ? Colors.green.withOpacity(0.6) : (isUpgrade || savingsPercent > 0 ? accentColor.withOpacity(0.6) : textColor.withOpacity(0.1)))
        ),
        borderRadius: BorderRadius.circular(20),
        color: isDowngrade 
            ? Colors.transparent // Invisible background for downgrade
            : (isOwned ? Colors.green.withOpacity(0.03) : (isUpgrade ? accentColor.withOpacity(0.04) : textColor.withOpacity(0.02))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(pkg.name, style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 18)),
                        if (badgeText != null)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                            child: Text(badgeText, style: TextStyle(color: badgeTextCol, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          )
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // SMART CREDIT NUDGE (Sunk Cost Fallacy Trigger)
                    if (isUpgrade && creditAmount > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 4, bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.withOpacity(0.3))
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.green, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              "Includes ${_getSymbol(pkg.currency)}${creditAmount.toStringAsFixed(0)} credit from current plan!", 
                              style: const TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold)
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              // PRICE BLOCK
              if (isOwned)
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.end,
                   children: [
                     const Icon(Icons.check_circle, color: Colors.green, size: 28),
                     const SizedBox(height: 4),
                     Text("ACTIVE", style: TextStyle(color: Colors.green.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0))
                   ]
                 )
              else if (!pkg.isVariablePrice)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isUpgrade) ...[
                      Text("${_getSymbol(pkg.currency)}${originalPrice.toStringAsFixed(0)}", style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 12, decoration: TextDecoration.lineThrough, fontFamily: "monospace")),
                      Text("${_getSymbol(pkg.currency)}${finalPrice.toStringAsFixed(0)}", style: TextStyle(color: isDowngrade ? textColor.withOpacity(0.5) : accentColor, fontWeight: FontWeight.w900, fontSize: 22, fontFamily: "monospace")),
                    ] else ...[
                      Text("${_getSymbol(pkg.currency)}${originalPrice.toStringAsFixed(0)}", style: TextStyle(color: isDowngrade ? textColor.withOpacity(0.5) : textColor, fontWeight: FontWeight.w900, fontSize: 22, fontFamily: "monospace")),
                    ],
                    Text(pkg.duration == 'lifetime' ? 'once' : 'per ${pkg.duration}', style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
            ],
          ),

          // FEATURES LIST
          if (features.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...features.map((feat) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                children: [
                  Icon(
                    isOwned ? Icons.check_circle : Icons.check_circle_outline, 
                    color: isOwned ? Colors.green : (isDowngrade ? textColor.withOpacity(0.2) : accentColor), 
                    size: 16
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(feat, style: TextStyle(color: textColor.withOpacity(isDowngrade ? 0.4 : 0.8), fontSize: 13, fontWeight: FontWeight.w500))),
                ],
              ),
            )),
          ],

          // VARIABLE PRICE INPUT (Pay-What-You-Want)
          if (!isOwned && pkg.isVariablePrice) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _donationControllers[pkg.identifier],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: "monospace"),
                    decoration: InputDecoration(
                      prefixText: _getSymbol(pkg.currency) + " ",
                      prefixStyle: TextStyle(color: textColor.withOpacity(0.5), fontSize: 16),
                      filled: true,
                      fillColor: textColor.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: _isLoading ? null : () {
                    final inputAmount = double.tryParse(_donationControllers[pkg.identifier]!.text) ?? 0;
                    final customKobo = (inputAmount * 100).round();
                    executePurchase(customAmountKobo: customKobo);
                  },
                  child: const Text("Support", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                ),
              ],
            )
          ]
        ],
      ),
    );

    // If they already own it, or it's a variable price, do not make the card tappable
    if (isOwned || pkg.isVariablePrice) {
      return cardContent;
    }
    
    // Otherwise, wrap in GestureDetector to buy
    return GestureDetector(
      onTap: _isLoading ? null : () => executePurchase(),
      child: cardContent,
    );
  }
}

extension _SliceExtension<T> on List<T> {
  List<T> slice(int start, int end) {
    if (isEmpty) return [];
    final actualEnd = end > length ? length : end;
    return sublist(start, actualEnd);
  }
}