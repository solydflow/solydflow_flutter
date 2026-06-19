class SolydPackage {
  final String identifier;    
  final String entitlementID; 
  final String name;          
  final int amountKobo;
  final String currency;
  final String duration;
  final int tierLevel;
  final String? appleProductID;
  final String? googleProductID;
  final int calculatedAmountKobo;
  final bool isUpgrade;
  final bool isVariablePrice;

  SolydPackage({
    required this.identifier,
    required this.entitlementID,
    required this.name,
    required this.amountKobo,
    required this.currency,
    required this.duration,
    required this.tierLevel,
    this.appleProductID,
    this.googleProductID,
    required this.calculatedAmountKobo,
    required this.isUpgrade,
    required this.isVariablePrice,
  });

  factory SolydPackage.fromJson(Map<String, dynamic> json) {
    return SolydPackage(
      identifier: json['identifier'],
      entitlementID: json['entitlement_id'] ?? "pro",
      name: json['name'],
      amountKobo: json['amount_kobo'],
      currency: json['currency'],
      duration: json['duration'],
      tierLevel: json['tier_level'] ?? 1, // 🟢 Parse it (default to 1)
      appleProductID: json['apple_product_id'],
      googleProductID: json['google_product_id'],
      // If backend sends it, use it. Otherwise default to standard price.
      calculatedAmountKobo: json['calculated_amount_kobo'] ?? json['amount_kobo'],
      isUpgrade: json['is_upgrade'] ?? false,
      isVariablePrice: json['is_variable_price'] == true,
    );
  }
}
